import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { recommendMcp } from "./router.js";

const server = new Server(
  {
    name: "mcp-router",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "recommend_mcp",
        description: "Recommends the best MCP server for a given task, based on capability, keyword match, and cost efficiency.",
        inputSchema: {
          type: "object",
          properties: {
            task_description: {
              type: "string",
              description: "A detailed description of the task you want to perform.",
            },
          },
          required: ["task_description"],
        },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name === "recommend_mcp") {
    const task = request.params.arguments.task_description;
    const recommendation = await recommendMcp(task);
    return {
      content: [
        {
          type: "text",
          text: recommendation,
        },
      ],
    };
  }
  throw new Error("Tool not found");
});

async function run() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("mcp-router started on stdio");
}

run().catch((error) => {
  console.error("Failed to start mcp-router:", error);
  process.exit(1);
});
