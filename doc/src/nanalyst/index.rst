.. _nAnalyst:

nAnalyst - Agentic AI Network Intelligence
########################################

nAnalyst is an autonomous network intelligence AI Agent layer embedded in ntopng that transforms raw traffic data into grounded, explainable answers. Instead of presenting dashboards that require manual interpretation, nAnalyst reasons over live and historical network data, executes SQL queries, visualizes evidence, and takes actions — all through a natural language chat interface.

Key capabilities at a glance:

- **Natural language queries** — ask questions in plain English, get grounded answers
- **No black box** — every reasoning step, tool call, and SQL query is visible
- **Agentic actions** — create policies, add monitoring scripts, silence alerts automatically
- **Full audit trail** — SOC2-style evidence for every action taken
- **Cost tracking** — per-user, per-model, per-tool-call token and dollar accounting
- **Privacy first** — fully on-premises; no data leaves your ntopng instance
- **Multi-LLM** — works with Anthropic Claude, OpenAI, AWS Bedrock, and local inference servers

.. toctree::
   :maxdepth: 2
   :caption: nAnalyst

   what_is_nanalyst
   architecture
   chat_interface
   features/index
   llm_setup
   mcp_server
   observability
   faq