---
title: "nAnalyst - Agentic AI Network Intelligence"
description: "nAnalyst is an autonomous network intelligence AI Agent layer embedded in ntopng that transforms raw traffic data into grounded, explainable answers...."
outline: [2, 3]
lastUpdated: 2026-11-16T12:03:36+01:00
---

<a id="nanalyst"></a>

# nAnalyst - Agentic AI Network Intelligence {#nanalyst-agentic-ai-network-intelligence}

nAnalyst is an autonomous network intelligence AI Agent layer embedded in ntopng that transforms raw traffic data into grounded, explainable answers. Instead of presenting dashboards that require manual interpretation, nAnalyst reasons over live and historical network data, executes SQL queries, visualizes evidence, and takes actions — all through a natural language chat interface.

Key capabilities at a glance:

- **Natural language queries** — ask questions in plain English, get grounded answers
- **No black box** — every reasoning step, tool call, and SQL query is visible
- **Agentic actions** — create policies, add monitoring scripts, silence alerts automatically
- **Full audit trail** — SOC2-style evidence for every action taken
- **Cost tracking** — per-user, per-model, per-tool-call token and dollar accounting
- **Privacy first** — fully on-premises; no data leaves your ntopng instance
- **Multi-LLM** — works with Anthropic Claude, OpenAI, AWS Bedrock, and local inference servers

**nAnalyst**

- [What is nAnalyst?](/nanalyst/what_is_nanalyst.md)
  - [What makes nAnalyst different](/nanalyst/what_is_nanalyst.md#what-makes-nanalyst-different)
  - [Further reading](/nanalyst/what_is_nanalyst.md#further-reading)
- [Architecture](/nanalyst/architecture.md)
  - [How a request is processed](/nanalyst/architecture.md#how-a-request-is-processed)
  - [LLM integration](/nanalyst/architecture.md#llm-integration)
  - [Data flow and privacy](/nanalyst/architecture.md#data-flow-and-privacy)
- [Chat Interface](/nanalyst/chat_interface.md)
  - [Accessing the chat](/nanalyst/chat_interface.md#accessing-the-chat)
  - [Asking questions](/nanalyst/chat_interface.md#asking-questions)
  - [Reading the response](/nanalyst/chat_interface.md#reading-the-response)
  - [Inline charts](/nanalyst/chat_interface.md#inline-charts)
  - [Seeing what the agent can do](/nanalyst/chat_interface.md#seeing-what-the-agent-can-do)
  - [Multi-turn conversations](/nanalyst/chat_interface.md#multi-turn-conversations)
- [AI Dashboards](/nanalyst/ai_dashboards.md)
  - [Opening the page](/nanalyst/ai_dashboards.md#opening-the-page)
  - [My Dashboards](/nanalyst/ai_dashboards.md#my-dashboards)
  - [Moving and resizing widgets](/nanalyst/ai_dashboards.md#moving-and-resizing-widgets)
  - [Creating a dashboard](/nanalyst/ai_dashboards.md#creating-a-dashboard)
  - [Widget types](/nanalyst/ai_dashboards.md#widget-types)
  - [Related pages](/nanalyst/ai_dashboards.md#related-pages)
- [Features](/nanalyst/features/index.md)
  - [Explainability — No Black Box](/nanalyst/features/no_black_box.md)
  - [AI-Generated Network Policies](/nanalyst/features/policies.md)
  - [Active Monitoring Automation](/nanalyst/features/active_monitoring.md)
  - [Alert Management](/nanalyst/features/alert_management.md)
  - [Usage Statistics](/nanalyst/features/usage_stats.md)
  - [Action Audit Log](/nanalyst/features/audit_log.md)
- [Tools and Licensing](/nanalyst/tools_and_licensing.md)
  - [License model](/nanalyst/tools_and_licensing.md#license-model)
  - [Annotations](/nanalyst/tools_and_licensing.md#annotations)
  - [Tool reference](/nanalyst/tools_and_licensing.md#tool-reference)
  - [The Tools Catalog](/nanalyst/tools_and_licensing.md#the-tools-catalog)
- [LLM Setup](/nanalyst/llm_setup.md)
  - [Supported backends](/nanalyst/llm_setup.md#supported-backends)
  - [Tool calling requirement](/nanalyst/llm_setup.md#tool-calling-requirement)
  - [Configuration](/nanalyst/llm_setup.md#configuration)
  - [Choosing a model](/nanalyst/llm_setup.md#choosing-a-model)
  - [Switching models](/nanalyst/llm_setup.md#switching-models)
  - [Per-provider settings and request timeout](/nanalyst/llm_setup.md#per-provider-settings-and-request-timeout)
  - [Default provider](/nanalyst/llm_setup.md#default-provider)
  - [Custom providers](/nanalyst/llm_setup.md#custom-providers)
- [MCP Server](/nanalyst/mcp_server.md)
  - [What is MCP?](/nanalyst/mcp_server.md#what-is-mcp)
  - [Connecting an MCP client](/nanalyst/mcp_server.md#connecting-an-mcp-client)
  - [Authentication](/nanalyst/mcp_server.md#authentication)
  - [Available tools via MCP](/nanalyst/mcp_server.md#available-tools-via-mcp)
  - [Use cases](/nanalyst/mcp_server.md#use-cases)
  - [Further reading](/nanalyst/mcp_server.md#further-reading)
- [External MCP Servers](/nanalyst/mcp_client.md)
  - [How it works](/nanalyst/mcp_client.md#how-it-works)
  - [Requirements](/nanalyst/mcp_client.md#requirements)
  - [Adding a server](/nanalyst/mcp_client.md#adding-a-server)
  - [Choosing which tools nAnalyst can use](/nanalyst/mcp_client.md#choosing-which-tools-nanalyst-can-use)
  - [Seeing all the available tools](/nanalyst/mcp_client.md#seeing-all-the-available-tools)
  - [Using external tools in the chat](/nanalyst/mcp_client.md#using-external-tools-in-the-chat)
  - [Safety rules](/nanalyst/mcp_client.md#safety-rules)
  - [Troubleshooting](/nanalyst/mcp_client.md#troubleshooting)
- [Observability](/nanalyst/observability.md)
  - [Summary](/nanalyst/observability.md#summary)
  - [Usage Statistics](/nanalyst/features/usage_stats.md)
  - [Action Audit Log](/nanalyst/features/audit_log.md)
- [Frequently Asked Questions](/nanalyst/faq.md)

