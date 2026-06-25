.. _nAnalystFAQ:

Frequently Asked Questions
==========================

**Which LLM models work best?**

Any model with strong instruction-following and a context window of at least 32k tokens will work well. Claude Sonnet and GPT-4o class models give the best results for complex investigations and policy generation. Smaller local models work for simpler queries.

**Can I use nAnalyst without an internet connection?**

Yes, by configuring a local inference server (llama-cpp, vllm, sglang). See :ref:`nAnalystLLMSetup`.

**Who can use nAnalyst?**

nAnalyst sessions are tied to authenticated ntopng users. Access and permissions follow ntopng's existing role-based access control. Administrators can review all users' sessions in the usage statistics and audit log.

**Can the AI take destructive actions?**

nAnalyst can create policies, add monitoring scripts, and silence alerts. It cannot delete flow records, remove hosts, or modify network device configurations. All actions it takes are recorded in the :ref:`nAnalystAuditLog` and most require explicit user confirmation before execution.

**What happens to my conversation history?**

Conversations are stored on the ntopng instance in the local database. They are not transmitted externally. Administrators can purge conversation history from the nAnalyst settings panel.

**How do I keep costs under control?**

Use the usage statistics dashboard to monitor token consumption per user. You can configure per-model pricing to track dollar costs. For high-volume use cases, a local inference server eliminates per-token API costs entirely.

**Is nAnalyst available as an MCP server?**

Yes. See :ref:`nAnalystMCP` for connection instructions. Any MCP-compatible client can connect to ntopng and use the full nAnalyst tool set.

**What is the difference between nAnalyst and a generic AI assistant?**

Generic AI assistants use web search and have no access to your network data. nAnalyst has 25+ purpose-built tools that query your live and historical ntopng data directly. It understands nDPI application signatures, ntopng flow semantics, and network security terminology natively. Every answer is grounded in your actual traffic — not general internet knowledge.