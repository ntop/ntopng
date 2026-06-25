.. _nAnalystArchitecture:

Architecture
============

nAnalyst is structured as an agentic loop that sits between the user's natural language input and ntopng's data layer. The diagram below shows the high-level flow.

.. code-block:: text

   User question (chat or MCP client)
            │
            ▼
   ┌─────────────────────┐
   │   nAnalyst Agent    │
   │  (reasoning loop)   │
   └────────┬────────────┘
            │ selects tools
            ▼
   ┌──────────────────────────────────────────────────┐
   │              Domain-Specific Tools               │
   │  SQL queries · flow lookup · host/asset info     │
   │  SNMP · alert management · policy engine         │
   │  active monitoring · chart generation            │
   └──────────────────┬───────────────────────────────┘
                      │ results
                      ▼
   ┌──────────────────────────────────────────────────┐
   │         ntopng Data Layer                        │
   │  ClickHouse (flows) · Redis (live state)         │
   │  nDPI signatures · SNMP · alert subsystem        │
   └──────────────────────────────────────────────────┘

How a request is processed
---------------------------

1. **User asks a question** — through the built-in chat UI or any MCP-compatible client.

2. **Agent starts** — nAnalyst initialises a reasoning session tied to the authenticated ntopng user.

3. **Tool selection** — the agent determines which of its 25+ network-specific tools are relevant. Tools are not called blindly; the agent reasons about what evidence is needed.

4. **Data collection** — tools query ClickHouse for historical flows, the asset inventory for host metadata, SNMP for device information, and the alert subsystem for active incidents.

5. **Evidence assembly** — collected data is structured into an evidence log. Charts are generated and embedded in the chat response. The full SQL and tool-call trace is stored.

6. **Answer and next steps** — the agent synthesises the evidence into a plain-language answer with citations and, where appropriate, suggests or performs follow-up actions (creating policies, adding monitors, silencing noise).

7. **Persistence** — evidence and reasoning steps are persisted across sessions so context is not lost between conversations.

LLM integration
---------------

nAnalyst communicates with an LLM only for reasoning and natural language generation. All data retrieval is performed by tool calls against your ntopng instance. 

Supported LLM backends:

- `Anthropic <https://www.anthropic.com/api>`_ (Claude) — native API format
- `OpenAI <https://platform.openai.com/docs/overview>`_ — native API format
- `AWS Bedrock <https://aws.amazon.com/bedrock/>`_ — OpenAI-compatible endpoint
- `Qwen (Alibaba Cloud) <https://www.alibabacloud.com/en/solutions/generative-ai/qwen>`_ — OpenAI-compatible; tested with Qwen3 235B-A22B
- Local inference servers — `llama-cpp <https://github.com/ggml-org/llama.cpp>`_, `vllm <https://docs.vllm.ai/>`_, `sglang <https://docs.sglang.ai/>`_, or any OpenAI-compatible server

See :ref:`nAnalystLLMSetup` for configuration details.

Data flow and privacy
---------------------

.. code-block:: text

   ntopng instance (your premises)
   ┌──────────────────────────────────────┐
   │  nAnalyst agent                      │
   │  ├─ tool call → ClickHouse query     │
   │  ├─ tool call → Redis lookup         │
   │  ├─ structured summary ──────────────┼──► LLM API (reasoning only)
   │  └─ LLM response ◄───────────────────┼────────────────────────────
   └──────────────────────────────────────┘
