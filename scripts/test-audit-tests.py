#!/usr/bin/env python3
"""Regression tests for mutation mapping and honest result classification."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('audit', Path(__file__).with_name('test-audit.py'))
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class MutationMappingTests(unittest.TestCase):
    def mutation(self, before, after, line, column, operator='RelationalOperatorReplacement'):
        return {'snapshot': {'before': before, 'after': after}, 'position': {'line': line, 'column': column},
                'mutationOperatorId': operator}

    def test_operator_position_uses_utf8_columns_and_preserves_identical_neighbor(self):
        source = 'let title = "Привет"\nif a == b && c == d {}\n'.encode()
        m = self.mutation('==', '!=', 2, 6)
        self.assertEqual(audit.replacement(source, m), 'let title = "Привет"\nif a != b && c == d {}\n'.encode())

    def test_mismatched_ast_position_is_rejected_instead_of_searching_elsewhere(self):
        with self.assertRaises(ValueError):
            audit.replacement(b'if a == b {}', self.mutation('==', '!=', 1, 2))

    def test_invalid_coordinates_and_empty_tokens_are_rejected(self):
        for before, line, column in [('==', 0, 1), ('==', 1, 0), ('==', 3, 1),
                                     ('==', 1, 100), ('', 1, 1)]:
            with self.subTest(before=before, line=line, column=column), self.assertRaises(ValueError):
                audit.replacement(b'if a == b {}', self.mutation(before, '!=', line, column))

    def test_removal_is_anchored_at_end_of_selected_statement(self):
        source = b'    save()\n    save()\n'
        m = self.mutation('save()', 'removed line', 2, 11, 'RemoveSideEffects')
        self.assertEqual(audit.replacement(source, m), b'    save()\n    \n')

    def test_multiline_statement_removal_preserves_following_statement(self):
        source = b'    save(\n        value\n    )\n    next()\n'
        m = self.mutation('save( value )', 'removed line', 3, 6, 'RemoveSideEffects')
        self.assertEqual(audit.replacement(source, m), b'    \n    next()\n')

    def test_ternary_replaces_only_selected_expression(self):
        source = b'let a = yes ? first : second\n'
        m = self.mutation('yes ? first : second', 'yes ? second : first', 2, 1, 'SwapTernary')
        self.assertEqual(audit.replacement(source, m), b'let a = yes ? second : first\n')


class ClassificationTests(unittest.TestCase):
    def summary(self, failed=0, text=''):
        return {'totalTestCount': 2, 'passedTests': 2 - failed, 'failedTests': failed, 'skippedTests': 0,
                'testFailures': [{'failureText': text}] if text else [], 'runtimeWarnings': []}

    def test_assertion_failure_kills_mutant(self):
        for failure in ['XCTAssertEqual failed',
                        'Asynchronous wait failed: Exceeded timeout of 2 seconds, with unfulfilled expectations: "Navigation delays suspended".']:
            self.assertEqual(audit.classify(1, self.summary(1, failure), ''), 'killed')

    def test_success_survives(self):
        self.assertEqual(audit.classify(0, self.summary(), ''), 'survived')

    def test_timeout_and_compile_error_are_not_kills(self):
        self.assertEqual(audit.classify('timeout', None, ''), 'timeout')
        self.assertEqual(audit.classify('timeout', self.summary(1, 'XCTAssertEqual failed'), ''), 'timeout')
        self.assertEqual(audit.classify(1, None, '** TEST BUILD FAILED **'), 'compile-error')

    def test_crash_or_runner_failure_is_not_a_kill(self):
        self.assertEqual(audit.classify(1, self.summary(1, 'Test runner crashed'), ''), 'infrastructure-error')
        self.assertEqual(audit.classify(1, self.summary(), ''), 'infrastructure-error')
        self.assertEqual(audit.classify(1, None, ''), 'infrastructure-error')

    def test_empty_skipped_or_warning_run_is_not_a_survivor(self):
        for key, value in [('totalTestCount', 0), ('skippedTests', 1), ('runtimeWarnings', ['layout warning']),
                           ('expectedFailures', 1), ('passedTests', 1)]:
            summary = self.summary()
            summary[key] = value
            self.assertEqual(audit.classify(0, summary, ''), 'infrastructure-error')

    def test_assertion_mixed_with_warning_or_expected_failure_is_not_a_kill(self):
        for key, value in [('runtimeWarnings', ['layout warning']), ('expectedFailures', 1)]:
            summary = self.summary(1, 'XCTAssertEqual failed')
            summary[key] = value
            self.assertEqual(audit.classify(1, summary, ''), 'infrastructure-error')

    def test_console_only_runtime_diagnostics_disqualify_successes_and_assertions(self):
        for warning in [
            'Bound preference AgendaSectionFramesKey tried to update multiple times per frame.',
            'onChange(of: Optional<Date>) action tried to update multiple times per frame.',
            'Picker: the selection "missing" is invalid and does not have an associated tag.',
            'Modifying state during view update, this will cause undefined behavior.',
            'Publishing changes from within view updates is not allowed.',
            'Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.',
            'SWIFT TASK CONTINUATION MISUSE: fetch() leaked its continuation without resuming it.',
            'Conflicting constraints detected: (',
            'Unable to simultaneously satisfy constraints.',
            'WARNING: ThreadSanitizer: data race (pid=33183)',
            'WARNING: ThreadSanitizer: Swift access race (pid=33351)',
            'FATAL: ThreadSanitizer: unexpected memory mapping',
            'ThreadSanitizer: reported 2 warnings'
        ]:
            # The warning may precede the final output tail printed by test.sh.
            log = warning + '\n' + 'normal test output\n' * 120
            with self.subTest(warning=warning):
                self.assertEqual(audit.runtime_diagnostics(log), [warning])
                self.assertEqual(audit.classify(0, self.summary(), log), 'infrastructure-error')
                self.assertEqual(audit.classify(1, self.summary(1, 'XCTAssertEqual failed'), log),
                                 'infrastructure-error')

    def test_crash_takes_precedence_over_other_test_assertions(self):
        summary = self.summary(2, 'XCTAssertEqual failed')
        summary['testFailures'].append({'failureText': 'Crash: xctest'})
        self.assertEqual(audit.classify(1, summary, ''), 'infrastructure-error')

    def test_evaluate_reads_native_log_before_classifying_shell_tail(self):
        def run(command, cwd, log, timeout):
            log.write_text('XCTAssertEqual failed (shell output tail)\n')
            results = log.parent / 'results'
            results.mkdir()
            (results / 'equinoxGraphicsTests-Debug-summary.json').write_text(
                json.dumps(self.summary(1, 'XCTAssertEqual failed')))
            (results / 'equinoxGraphicsTests-Debug.log').write_text(
                'Modifying state during view update\n' + 'normal test output\n' * 120)
            return 1, 0.1

        with tempfile.TemporaryDirectory() as directory, patch.object(audit, 'run', run):
            root = Path(directory)
            result = audit.evaluate(root / 'work', root / 'evidence', 'Debug', 'graphics', 180)
            self.assertEqual(result['status'], 'infrastructure-error')


class MutationSelectionTests(unittest.TestCase):
    def test_default_covers_every_discovered_mutation(self):
        mutations = [{'id': 'a'}, {'id': 'b'}, {'id': 'c'}]
        self.assertEqual(audit.select_mutations(mutations), mutations)
        self.assertEqual(audit.select_mutations(mutations, limit=2), mutations[:2])

    def test_followup_selects_exact_ids_once_in_discovery_order(self):
        mutations = [{'id': 'a'}, {'id': 'b'}, {'id': 'c'}]
        self.assertEqual(audit.select_mutations(mutations, mutation_ids=['c', 'a', 'c']),
                         [mutations[0], mutations[2]])

    def test_unknown_or_empty_followup_cannot_silently_run_nothing(self):
        for ids in [[], ['missing'], ['a', 'missing']]:
            with self.subTest(ids=ids), self.assertRaises(ValueError):
                audit.select_mutations([{'id': 'a'}], mutation_ids=ids)


if __name__ == '__main__':
    unittest.main()
