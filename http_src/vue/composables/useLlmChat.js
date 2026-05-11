/**
 * useLlmChat — composable that owns all LLM chat state and behaviour.
 *
 * Both `chatbot.vue` (compact widget) and `page-chatbot.vue` (full page) import
 * this so they share identical send/receive logic without duplicating code.
 *
 * Template refs `messageList` and `promptInput` are created here and returned
 * so each component can bind them with `ref="messageList"` / `ref="promptInput"`.
 */

import { ref, computed, nextTick } from "vue";
import { ntopng_url_manager, ntopng_utility } from "../../services/context/ntopng_globals_services.js";
import MarkdownIt from "markdown-it";
import { v4 as uuidv4 } from "uuid";
import hljs from "highlight.js";
import DOMPurify from "dompurify";
import formatterUtils from "../../utilities/formatter-utils.js";

// Markdown renderer, shared singleton, stateless
const md = new MarkdownIt({
  html: true,
  linkify: true,
  breaks: true,
  highlight(str, lang) {
    if (lang && hljs.getLanguage(lang)) {
      try {
        return `<pre class="code-block"><code class="hljs">${hljs.highlight(str, { language: lang }).value}</code></pre>`;
      } catch (_) {}
    }
    return `<pre class="code-block"><code class="hljs">${hljs.highlightAuto(str).value}</code></pre>`;
  },
});

export function renderMarkdown(content) {
  return DOMPurify.sanitize(md.render(content || ""));
}

export function highlightSql(sql) {
  return hljs.highlight(sql || "", { language: "sql" }).value;
}

export function getProviderIcon(provider) {
  if (provider === "llm_openai") return "bi bi-openai";
  if (provider === "llm_anthropic") return "bi bi-anthropic";
  return "fa-solid fa-microchip";
}

// Premade questions
export const PRESET_QUESTIONS = [
  "What are the top 5 hosts by traffic in the last hour?",
  "Which network protocols are generating the most traffic?",
  "List the top talkers by bytes sent in the last 24 hours",
  "Show me DNS query volume and top queried domains",
];

export function useLlmChat(props) {
  const MAX_HISTORY = 40;
  const timeoutSec = 120;

  const messageList = ref(null);
  const promptInput = ref(null);

  // Core state
  const messages   = ref([]);
  const history    = ref([]);
  const sending    = ref(false);
  const timedOut   = ref(false);
  const prompt     = ref("");
  const conciseMode = ref(true);
  const chat_UUID  = ref(uuidv4());

  // Provider state
  const providers        = ref([]);
  const selectedProvider = ref(null);
  const loadingProviders = ref(true);

  // UI helpers
  const openSqlPanels   = ref(new Set());
  const openStepsPanels = ref(new Set());
  const showPresets     = ref(false);
  const liveSteps       = ref([]);  // steps streamed during the current request

  // Debug helper
  const debugStatus = ref("");
  let debugStatusTimer = null;

  // Sending animation labels
  const sendingLabelIndex = ref(0);
  const sendingLabels = [
    "llm.analyzing",
    "llm.investigating",
    "llm.inspecting",
    "llm.correlating",
  ];
  let sendingInterval = null;

  const currentSendingLabel = computed(() =>
    typeof i18n === "function" ? i18n(sendingLabels[sendingLabelIndex.value]) : sendingLabels[sendingLabelIndex.value]
  );

  const canSendMsg = computed(() =>
    !sending.value &&
    prompt.value.trim().length > 0 &&
    selectedProvider.value !== null
  );

  const selectedProviderInfo = computed(() =>
    providers.value.find((p) => p.provider === selectedProvider.value)
  );

  // Utilities
  function nowTime() {
    return new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }

  function formatTimestamp(ts) {
    try {
      return formatterUtils.getFormatter("date")(parseInt(ts));
    } catch (_) {
      return new Date(parseInt(ts) * 1000).toLocaleString();
    }
  }

  // SQL / steps panel toggle
  function toggleSqlPanel(idx) {
    const s = new Set(openSqlPanels.value);
    s.has(idx) ? s.delete(idx) : s.add(idx);
    openSqlPanels.value = s;
  }

  function toggleStepsPanel(idx) {
    const s = new Set(openStepsPanels.value);
    s.has(idx) ? s.delete(idx) : s.add(idx);
    openStepsPanels.value = s;
  }

  // Scroll helpers
  function scrollBottom() {
    if (messageList.value) {
      messageList.value.scrollTop = messageList.value.scrollHeight;
    }
  }

  function scrollToLastMessage() {
    if (!messageList.value) return;
    const bubbles = messageList.value.querySelectorAll(".chat-bubble");
    const last = bubbles[bubbles.length - 1];
    if (last) last.scrollIntoView({ block: "start", behavior: "smooth" });
  }

  // Textarea auto resize / reset
  function autoResize(e) {
    const el = e.target;
    el.style.height = "auto";
    el.style.height = Math.min(el.scrollHeight, 120) + "px";
  }

  function resetTextarea() {
    if (promptInput.value) promptInput.value.style.height = "auto";
  }

  // Sending animation
  function startSendingAnimation() {
    sendingLabelIndex.value = 0;
    sendingInterval = setInterval(() => {
      sendingLabelIndex.value = (sendingLabelIndex.value + 1) % sendingLabels.length;
    }, 1500);
  }

  function stopSendingAnimation() {
    if (sendingInterval) {
      clearInterval(sendingInterval);
      sendingInterval = null;
    }
  }

  // Push a message into the UI list
  function pushMessage(role, content, error = false, stats = null, artifact = null, queries = null, steps = null) {
    messages.value.push({ role, content, time: nowTime(), error, stats, artifact, queries, steps });
    nextTick(role === "assistant" ? scrollToLastMessage : scrollBottom);
  }

  // Preset questions: prefer context-provided ones, fall back to defaults
  const activePresetQuestions = computed(() => {
    const custom = props?.context?.presetQuestions;
    return Array.isArray(custom) && custom.length > 0 ? custom : PRESET_QUESTIONS;
  });

  // Inject context as a protected header pair (user message + assistant ack).
  // The first two messages are never trimmed — see history.lua trim() function.
  // This is the right place for any per-session context: flow details, host info, etc.
  function injectInitialMessage() {
    const msg = props?.context?.initialMessage;
    if (msg && typeof msg === "string" && msg.trim()) {
      history.value = [
        { role: "user",      content: msg },
        { role: "assistant", content: "Context loaded. Ask me anything." },
      ];
    }
  }

  // Provider loading
  async function loadProviders() {
    loadingProviders.value = true;
    try {
      const url = `${http_prefix}/lua/pro/rest/v2/get/llm/providers.lua`;
      const list = (await ntopng_utility.http_request(url)) ?? [];

      providers.value = Array.isArray(list) ? list : [];
      if (providers.value.length > 0) selectedProvider.value = providers.value[0].provider;
      injectInitialMessage();
    } catch (err) {
      console.error("llm providers fetch failed:", err);
      providers.value = [];
    } finally {
      loadingProviders.value = false;
    }
  }

  // Select provider dropdown
  function selectProvider(provider) {
    if (!sending.value) selectedProvider.value = provider;
  }

  // Clear chat
  function clearChat() {
    messages.value = [];
    history.value = [];
    openSqlPanels.value   = new Set();
    openStepsPanels.value = new Set();
    liveSteps.value = [];
    chat_UUID.value = uuidv4();
    ntopng_url_manager.set_key_to_url("chatId", null);
  }

  // Generate response
  async function send() {
    if (!canSendMsg.value) return;

    const text = prompt.value.trim();
    prompt.value = "";
    resetTextarea();
    timedOut.value = false;

    const isFirstMessage = messages.value.length === 0;
    if (isFirstMessage) ntopng_url_manager.set_key_to_url("chatId", chat_UUID.value);
    pushMessage("user", text);

    history.value.push({ role: "user", content: text });
    while (history.value.length > MAX_HISTORY) history.value.splice(0, 2);

    liveSteps.value = [];
    sending.value = true;
    startSendingAnimation();

    const controller = new AbortController();
    const timer = setTimeout(() => {
      controller.abort();
      timedOut.value = true;
    }, timeoutSec * 1000);

    try {
      const csrf = props?.context?.csrf;
      const url = `${http_prefix}/lua/pro/rest/v2/post/llm/completion.lua`;

      const body = JSON.stringify({
        provider: selectedProvider.value,
        messages: history.value,
        stream: false,
        chatId: chat_UUID.value,
        sequence: history.value.length,
        concise: conciseMode.value,
        csrf,
        ...(props?.context?.page_context && { page_context: props.context.page_context }),
      });

      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        signal: controller.signal,
      });

      if (!response.ok) {
        const fallback = await response.json().catch(() => ({}));
        throw new Error(fallback?.rsp?.error_message ?? fallback?.error_message ?? `HTTP ${response.status}`);
      }

      const reader  = response.body.getReader();
      const decoder = new TextDecoder();
      let   buf        = "";
      let   finalChunk = null;
      let   streamDone = false;
      let   streamError = null;

      const processLine = (line) => {
        const trimmed = line.trim();
        if (!trimmed) return;
        let chunk;
        try { chunk = JSON.parse(trimmed); } catch (_) { return; }

        if (chunk.type === "step") {
          liveSteps.value = [...liveSteps.value, chunk];
          nextTick(scrollBottom);
        } else if (chunk.type === "final") {
          finalChunk = chunk;
          streamDone = true;   // stop reading — don't wait for connection close
        } else if (chunk.type === "error") {
          streamError = new Error(chunk.error_message ?? "Agent error");
          streamDone = true;
        }
      };

      outer: while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });
        const lines = buf.split("\n");
        buf = lines.pop();
        for (const line of lines) {
          processLine(line);
          if (streamDone) break outer;
        }
      }
      // flush any partial line not terminated by \n
      if (!streamDone && buf.trim()) processLine(buf);

      // always release the reader so the connection is not held open
      await reader.cancel().catch(() => {});

      clearTimeout(timer);

      if (streamError) throw streamError;

      const errMsg = typeof i18n === "function" ? i18n("llm.generic_error") : "An error occurred";
      const reply = finalChunk?.reply ?? null;
      if (!reply) throw new Error(finalChunk?.error_message ?? errMsg);

      history.value.push({ role: "assistant", content: reply });
      // evidence is the authoritative audit trail; pass as queries (rich panel), no separate steps
      const evidence = Array.isArray(finalChunk?.evidence) ? finalChunk.evidence : null;
      const queries  = evidence ?? finalChunk?.queries ?? null;
      pushMessage("assistant", reply, false, finalChunk?.stats ?? null, finalChunk?.artifact ?? null, queries, queries);

      // Let the full-page component know the first message title
      if (isFirstMessage) onFirstMessage?.(text);

    } catch (err) {
      clearTimeout(timer);
      history.value.pop();
      const timeoutMsg = typeof i18n === "function" ? i18n("llm.timeout_error_message") : "Request timed out";
      const genericMsg = typeof i18n === "function" ? i18n("llm.generic_error") : "Error";
      
      if (err.name === "AbortError") {
        pushMessage("assistant", timeoutMsg, true);
      } else {
        pushMessage("assistant", err.message || genericMsg, true);
      }
    } finally {
      sending.value = false;
      stopSendingAnimation();
      nextTick(() => promptInput.value?.focus());
    }
  }

  // Callback set by the consumer to react when the first user message is sent
  // used by page-chatbot.vue to update the sidebar title
  let onFirstMessage = null;
  function setOnFirstMessage(fn) { onFirstMessage = fn; }

  // Preset question set
  function sendPreset(question) {
    showPresets.value = false;
    prompt.value = question;
    nextTick(send);
  }

  // Debug dump to rest
  async function sendDebug() {
    if (messages.value.length === 0) return;
    try {
      const url = `${http_prefix}/lua/pro/rest/v2/post/llm/debug_chat.lua`;
      const res = await ntopng_utility.http_request(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ chatId: chat_UUID.value, messages: history.value, csrf: props?.context?.csrf }),
      }, true);
      debugStatus.value = res?.filename ? `Saved: ${res.filename}` : "Saved!";
    } catch (err) {
      console.error("[llm] sendDebug failed:", err);
      debugStatus.value = "Error";
    } finally {
      clearTimeout(debugStatusTimer);
      debugStatusTimer = setTimeout(() => { debugStatus.value = ""; }, 4000);
    }
  }

  // Expose
  return {
    // DOM refs
    messageList, promptInput,
    // State
    messages, history, sending, timedOut, prompt, conciseMode, chat_UUID,
    providers, selectedProvider, loadingProviders,
    openSqlPanels, openStepsPanels, showPresets, debugStatus, liveSteps,
    sendingLabelIndex, currentSendingLabel,
    canSendMsg, selectedProviderInfo,
    // Methods
    loadProviders, selectProvider, clearChat, send, pushMessage,
    sendPreset, sendDebug, setOnFirstMessage,
    scrollBottom, scrollToLastMessage,
    autoResize, resetTextarea,
    startSendingAnimation, stopSendingAnimation,
    toggleSqlPanel, toggleStepsPanel,
    // Preset questions (default or context-provided)
    activePresetQuestions,
    // Utils (stateless, exported also as named exports above)
    renderMarkdown, highlightSql, getProviderIcon,
    nowTime, formatTimestamp,
  };
}
