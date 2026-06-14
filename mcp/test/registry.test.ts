import { describe, expect, it } from "vitest"
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { MCP_TOOL_NAMES } from "../src/tools/registry.js"
import { registerTools } from "../src/tools/index.js"

describe("MCP tool registry", () => {
  it("has no duplicate names", () => {
    expect(new Set(MCP_TOOL_NAMES).size).toBe(MCP_TOOL_NAMES.length)
  })

  it("matches the tools registered on the server", () => {
    const registered: string[] = []
    const fakeServer = {
      registerTool: (name: string) => {
        registered.push(name)
        return undefined
      },
    } as unknown as McpServer

    registerTools(fakeServer)

    expect(registered.sort()).toEqual([...MCP_TOOL_NAMES].sort())
  })
})
