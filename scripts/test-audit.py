#!/usr/bin/env python3
"""Isolated, resumable Swift mutation audit using Muter's AST discovery and Xcode targets."""
import argparse
import collections
import difflib
import hashlib
import json
import locale
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
MUTER_REVISION = '5c854098e61d1a093ef9c4e53a5ebc6de07b3a32'


def write_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def run(command, cwd, log, timeout=600):
    started = time.monotonic()
    with log.open('w') as output:
        process = subprocess.Popen(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            if isinstance(error, KeyboardInterrupt):
                raise
            code = 'timeout'
    return code, round(time.monotonic() - started, 3)


def source_files():
    names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT)
    return sorted({name for name in names.decode().split('\0') if name and (ROOT / name).is_file()})


def input_hashes(files):
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files
            if name.startswith(('equinox/', 'equinoxTests/', 'equinoxGraphicsTests/', 'equinoxGraphicsHost/',
                                'equinox.xcodeproj/', 'scripts/')) or name == 'muter.conf.yml'}


def tool():
    directory = ROOT / 'build/Tools/muter'
    directory.parent.mkdir(parents=True, exist_ok=True)
    if not directory.exists():
        subprocess.run(['git', 'clone', 'https://github.com/muter-mutation-testing/muter.git', str(directory)], check=True)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=directory).decode().strip()
    if revision != MUTER_REVISION:
        subprocess.run(['git', 'fetch', 'origin', MUTER_REVISION], cwd=directory, check=True)
        subprocess.run(['git', 'checkout', '--detach', MUTER_REVISION], cwd=directory, check=True)
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=directory).strip():
        raise RuntimeError('Muter checkout is modified; refusing an unpinned tool')
    binary = directory / '.build/release/muter'
    # SwiftPM validates the incremental build against the pinned source/toolchain.
    code, _ = run(['swift', 'build', '-c', 'release', '--product', 'muter', '--jobs', '4'], directory,
                  directory.parent / 'muter-build.log', timeout=1800)
    if code != 0:
        raise RuntimeError('Muter build failed; see build/Tools/muter-build.log')
    return binary


def offset_for(source, position):
    # Muter's UTF-8 offset includes its injected imports; line/column refer to the original source.
    lines = source.splitlines(keepends=True)
    if (position['line'] < 1 or position['line'] > len(lines) + 1 or position['column'] < 1
            or (position['line'] == len(lines) + 1 and position['column'] != 1)
            or (position['line'] <= len(lines) and position['column'] > len(lines[position['line'] - 1]) + 1)):
        raise ValueError('AST position is outside the source')
    return sum(len(line) for line in lines[:position['line'] - 1]) + position['column'] - 1


def replacement(source, mutation):
    before = mutation['snapshot']['before'].encode()
    if not before:
        raise ValueError('Empty mutation source')
    after = mutation['snapshot']['after'].encode()
    offset = offset_for(source, mutation['position'])
    operator = mutation['mutationOperatorId']
    if operator in ('RelationalOperatorReplacement', 'ChangeLogicalConnector', 'TargetedReplacement'):
        if source[offset:offset + len(before)] != before:
            raise ValueError('AST token does not match original source at reported position')
        return source[:offset] + after + source[offset + len(before):]
    # Statement/ternary positions point at the END of the node. Match only there,
    # never replace another identical statement elsewhere in the file.
    prefix = source[:offset].rstrip()
    pattern = re.escape(before).replace(rb'\ ', rb'\s+') + rb'\Z'
    matches = list(re.finditer(pattern, prefix))
    if len(matches) != 1:
        raise ValueError('AST statement cannot be mapped unambiguously to original source')
    match = matches[0]
    actual = b' '.join(line.strip() for line in match.group().splitlines())
    if actual != before:
        raise ValueError('Normalized statement differs from Muter snapshot')
    if operator == 'RemoveSideEffects':
        after = b''
    elif operator != 'SwapTernary':
        raise ValueError(f'Unsupported operator: {operator}')
    return source[:match.start()] + after + source[match.end():]


def discover(snapshot, binary, folder):
    code, _ = run([str(binary), 'mutate-without-running', '--skip-coverage', '--skip-update-check'],
                  snapshot, folder / 'discovery.log')
    if code != 0:
        raise RuntimeError(f'Muter discovery failed: {folder / "discovery.log"}')
    mapping = json.loads((snapshot / 'muter-mappings.json').read_text())
    mutated_root = Path(mapping['mutatedProjectPath'])
    mutations = []
    for group in mapping['mappings']:
        for item in group['mappings']:
            relative = str(Path(item['filePath']).relative_to(mutated_root))
            if not relative.startswith('equinox/'):
                raise RuntimeError(f'Unexpected mutation outside application: {relative}')
            item['filePath'] = relative
            item['id'] = hashlib.sha256(json.dumps(item, sort_keys=True).encode()).hexdigest()[:16]
            mutations.append(item)
    # Concurrency invariants involve assignments/guards that Muter's four operators omit.
    directed = [
        ('equinox/App/EventFetchCoordinator.swift', 'guard !Task.isCancelled else { return }'),
        ('equinox/App/AgendaScrollCoordinator.swift', 'guard !Task.isCancelled else { return }'),
        ('equinox/App/EventsCoordinator.swift', 'snapshotGeneration &+= 1'),
        ('equinox/Services/EventKit/EventFetchCache.swift', 'generation = UUID()'),
    ]
    for relative, before in directed:
        source = (snapshot / relative).read_text()
        # Anchor the cache assignment as a statement, not its property initializer.
        lines = source.splitlines(keepends=True)
        candidates = [(i, line) for i, line in enumerate(lines) if line.strip() == before]
        if len(candidates) != 1:
            raise RuntimeError(f'Directed mutation no longer maps uniquely: {relative}: {before}')
        index, line = candidates[0]
        column = len(line[:line.index(before)].encode()) + 1
        item = {'filePath': relative, 'mutationOperatorId': 'TargetedReplacement',
                'position': {'line': index + 1, 'column': column},
                'snapshot': {'before': before, 'after': '', 'description': 'Remove concurrency protection'}}
        item['id'] = hashlib.sha256(json.dumps(item, sort_keys=True).encode()).hexdigest()[:16]
        mutations.append(item)
    mutations.sort(key=lambda m: (m['mutationOperatorId'] != 'TargetedReplacement',
                                 not m['filePath'].startswith('equinox/Core/'),
                                 m['filePath'], m['position']['line'], m['id']))
    write_json(folder / 'mutations.json', mutations)
    return mutations


def evaluate(work, folder, configuration, suite, timeout):
    result = folder / f'{configuration}-{suite}-{time.time_ns()}'
    result.mkdir(parents=True, exist_ok=True)
    log = result / 'run.log'
    env = dict(os.environ)
    env['EQUINOX_TEST_DERIVED_DATA'] = str(work.parent / 'DerivedData')
    env['EQUINOX_PACKAGE_CACHE'] = str(ROOT / 'build/DerivedData/SourcePackages')
    # Environment is passed through `env`, with no shell interpolation.
    command = ['/usr/bin/env', *[f'{key}={env[key]}' for key in ('EQUINOX_TEST_DERIVED_DATA', 'EQUINOX_PACKAGE_CACHE')],
               '/bin/bash', 'scripts/test.sh', '--mode', 'regression', '--configuration', configuration,
               '--suite', suite, '--result-dir', str(result / 'results')]
    code, elapsed = run(command, work, log, timeout)
    summaries = list((result / 'results').glob('*-summary.json'))
    text = log.read_text(errors='replace')
    # The shell runner prints only the tail after failures. Earlier runtime
    # diagnostics or test-host restarts must still disqualify an assertion kill.
    for native_log in (result / 'results').glob('*.log'):
        if not native_log.name.endswith('-build.log'):
            text += '\n' + native_log.read_text(errors='replace')
    summary = json.loads(summaries[0].read_text()) if summaries else None
    return {'status': classify(code, summary, text), 'seconds': elapsed, 'log': str(log)}


def runtime_diagnostics(log):
    return re.findall(
        r'^.*(?:Bound preference .* tried to update multiple times per frame|'
        r'onChange\(of: .*\) action tried to update multiple times per frame|'
        r'Picker: the selection .* is invalid and does not have an associated tag|'
        r'Modifying state during view update|Publishing changes from within view updates|'
        r'Conflicting constraints detected:|Unable to simultaneously satisfy constraints|'
        r'(?:WARNING|FATAL): ThreadSanitizer:|ThreadSanitizer: reported \d+ warnings|'
        r'Restarting after unexpected exit, crash, or test timeout|'
        r'SWIFT TASK CONTINUATION MISUSE).*$',
        log, re.MULTILINE)


def classify(code, summary, log):
    if code == 'timeout':
        return 'timeout'
    if '** TEST BUILD FAILED **' in log or '** BUILD FAILED **' in log:
        return 'compile-error'
    if (runtime_diagnostics(log) or not summary or not summary.get('totalTestCount') or summary.get('skippedTests')
            or summary.get('expectedFailures') or summary.get('runtimeWarnings')):
        return 'infrastructure-error'
    if summary.get('passedTests', 0) + summary.get('failedTests', 0) != summary['totalTestCount']:
        return 'infrastructure-error'
    if code == 0 and not summary.get('failedTests') and not summary.get('runtimeWarnings'):
        return 'survived'
    failures = summary.get('testFailures', [])
    assertion = any(re.search(r'XCTAssert|XCTUnwrap|failed -|Timed out:|Asynchronous wait failed:',
                              f.get('failureText', '')) for f in failures)
    crash = any(re.search(r'crash|exited|signal|execution time allowance', f.get('failureText', ''), re.I) for f in failures)
    return 'killed' if summary.get('failedTests', 0) and assertion and not crash else 'infrastructure-error'


def select_mutations(mutations, limit=None, mutation_ids=None):
    if mutation_ids is None:
        return mutations[:limit]
    requested = set(mutation_ids)
    unknown = requested - {mutation['id'] for mutation in mutations}
    if not requested or unknown:
        raise ValueError(f'Unknown or empty mutation selection: {sorted(unknown)}')
    return [mutation for mutation in mutations if mutation['id'] in requested]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--configuration', choices=['All', 'Debug', 'Release'], default='All')
    parser.add_argument('--discover-only', action='store_true')
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--limit', type=int, help='Diagnostic subset; never reports a complete audit')
    selection.add_argument('--mutation-id', action='append', help='Recheck an ID from mutations.json; repeat for multiple IDs')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.limit is not None and args.limit < 1:
        parser.error('--limit must be positive')
    binary = tool()
    files = source_files()
    hashes = input_hashes(files)
    environment = {'muter': MUTER_REVISION, 'binary': hashlib.sha256(binary.read_bytes()).hexdigest(),
                   'xcode': subprocess.check_output(['xcodebuild', '-version']).decode(),
                   'configuration': args.configuration, 'timeout': args.timeout,
                   'system': list(os.uname()), 'locale': locale.getlocale(), 'timezone': list(time.tzname),
                   'testEnvironment': {k: os.environ.get(k) for k in ['TZ', 'EQUINOX_TEST_ORDER', 'EQUINOX_TEST_LANGUAGE', 'EQUINOX_TEST_TIMEZONE']}}
    identity = hashlib.sha256(json.dumps([hashes, environment], sort_keys=True).encode()).hexdigest()
    folder = ROOT / 'build/MutationAudit' / identity[:16]
    folder.mkdir(parents=True, exist_ok=True)
    snapshot = folder / 'source'
    if not snapshot.exists():
        for name in files:
            destination = snapshot / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, destination)
        write_json(folder / 'manifest.json', {'identity': identity, 'files': hashes, 'environment': environment})
    mutations = (json.loads((folder / 'mutations.json').read_text()) if (folder / 'mutations.json').exists()
                 else discover(snapshot, binary, folder))
    print(f'{len(mutations)} mutations. Evidence: {folder}', flush=True)
    try:
        selected = {mutation['id'] for mutation in select_mutations(mutations, args.limit, args.mutation_id)}
    except ValueError as error:
        parser.error(str(error))
    if args.discover_only:
        return
    work = folder / 'work'
    # Restore the snapshot even after an interrupted mutation; never restore into ROOT.
    if work.exists():
        shutil.rmtree(work)
    shutil.copytree(snapshot, work, ignore=shutil.ignore_patterns('muter-mappings.json'))
    configurations = ['Debug', 'Release'] if args.configuration == 'All' else [args.configuration]
    results = json.loads((folder / 'results.json').read_text()) if (folder / 'results.json').exists() else {}
    baseline = folder / f'baseline-{time.time_ns()}'
    for configuration in configurations:
        for suite in ['unit', 'graphics']:
            check = evaluate(work, baseline, configuration, suite, args.timeout)
            if check['status'] != 'survived':
                raise RuntimeError(f'Unmutated baseline failed: {check}')
    for index, mutation in enumerate(mutations, 1):
        if mutation['id'] not in selected:
            continue
        key = mutation['id']
        if key in results:
            continue
        evidence = folder / key
        evidence.mkdir(exist_ok=True)
        if shutil.disk_usage(folder).free < 5 * 1024 ** 3:
            raise RuntimeError('Less than 5 GiB free; audit stopped with results preserved')
        path = work / mutation['filePath']
        original = path.read_bytes()
        try:
            changed = replacement(original, mutation)
        except ValueError as error:
            results[key] = {'status': 'mapping-error', 'reason': str(error)}
            write_json(folder / 'results.json', results)
            continue
        (evidence / 'mutation.diff').write_text(''.join(difflib.unified_diff(
            original.decode().splitlines(keepends=True), changed.decode().splitlines(keepends=True),
            fromfile=mutation['filePath'], tofile=mutation['filePath'])))
        outcome = {}
        try:
            path.write_bytes(changed)
            for configuration in configurations:
                unit = evaluate(work, evidence, configuration, 'unit', args.timeout)
                checks = {'unit': unit}
                if unit['status'] == 'survived':
                    checks['graphics'] = evaluate(work, evidence, configuration, 'graphics', args.timeout)
                outcome[configuration] = checks
        finally:
            path.write_bytes(original)
        statuses = [check['status'] for checks in outcome.values() for check in checks.values()]
        if any(s in statuses for s in ['timeout', 'compile-error', 'infrastructure-error']):
            status = next(s for s in ['timeout', 'compile-error', 'infrastructure-error'] if s in statuses)
        else:
            status = 'killed' if all(any(c['status'] == 'killed' for c in checks.values()) for checks in outcome.values()) else 'survived'
        results[key] = {'status': status, 'configurations': outcome}
        write_json(folder / 'results.json', results)
        print(f'{index}/{len(mutations)} {status}: {mutation["filePath"]}:{mutation["position"]["line"]}', flush=True)
    complete = args.limit is None and args.mutation_id is None and len(results) == len(mutations)
    if complete:
        final = folder / f'final-{time.time_ns()}'
        for configuration in configurations:
            for suite in ['unit', 'graphics']:
                check = evaluate(work, final, configuration, suite, args.timeout)
                if check['status'] != 'survived':
                    raise RuntimeError(f'Final unmutated verification failed: {check}')
    current_hashes = input_hashes(source_files())
    changed_files = sorted(name for name in hashes.keys() | current_hashes.keys()
                           if hashes.get(name) != current_hashes.get(name))
    counts = dict(collections.Counter(result['status'] for result in results.values()))
    report = {'total': len(mutations), 'requested': len(selected), 'processed': len(results), 'counts': counts,
              'complete': complete, 'sourceChangedDuringRun': changed_files}
    write_json(folder / 'summary.json', report)
    print(json.dumps(report, indent=2), flush=True)
    if changed_files or not report['complete'] or any(k != 'killed' for k in counts):
        sys.exit(1)


if __name__ == '__main__':
    main()
