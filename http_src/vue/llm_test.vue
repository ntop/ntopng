<template>
  <div class="llm-chat-page d-flex flex-column" style="height: calc(100vh - 120px); min-height: 500px;">

    <!-- Header bar: provider selector + status -->
    <div class="chat-header d-flex align-items-center gap-3 px-3 py-2 flex-shrink-0">
      <span class="chat-header-label fw-semibold small text-uppercase ls-1">
        <i class="fas fa-microchip me-1 opacity-75"></i>
        {{ _i18n('llm.provider') }}
      </span>

      <div v-if="loadingProviders" class="d-flex align-items-center gap-2 small chat-muted-text">
        <span class="spinner-border spinner-border-sm" role="status"></span>
        {{ _i18n('llm.loading_providers') }}
      </div>

      <div v-else-if="providers.length === 0" class="text-warning small d-flex align-items-center gap-1">
        <i class="fas fa-exclamation-triangle"></i>
        {{ _i18n('llm.no_providers') }}
      </div>

      <select
        v-else
        v-model="selectedProvider"
        class="chat-select form-select form-select-sm w-auto"
        :disabled="sending"
      >
        <option v-for="p in providers" :key="p.provider" :value="p.provider">
          {{ p.provider }} — {{ p.model }}
        </option>
      </select>

      <!-- Model badge -->
      <span v-if="selectedProvider && !loadingProviders && providers.length > 0" class="model-badge">
        <i class="fas fa-circle-dot me-1" style="font-size:0.55rem;vertical-align:middle;"></i>
        {{ providers.find(p => p.provider === selectedProvider)?.model ?? selectedProvider }}
      </span>

      <!-- Spacer + clear button -->
      <div class="ms-auto d-flex align-items-center gap-2">
        <!-- History depth indicator -->
        <span v-if="history.length > 0" class="history-badge">
          <i class="fas fa-layer-group me-1"></i>{{ history.length / 2 }} turns
        </span>

        <!-- Clear conversation -->
        <button
          v-if="messages.length > 0"
          class="btn-clear"
          :disabled="sending"
          @click="clearChat"
          :title="_i18n('llm.clear_chat')"
        >
          <i class="fas fa-trash-alt me-1"></i>
          <span class="d-none d-sm-inline">{{ _i18n('llm.clear_chat') }}</span>
        </button>
      </div>
    </div>

    <!-- Message list -->
    <div
      ref="messageList"
      class="chat-messages flex-grow-1 overflow-auto px-3 py-4 d-flex flex-column gap-3"
    >
      <!-- Empty state -->
      <div
        v-if="messages.length === 0"
        class="m-auto text-center py-5"
      >
        <div class="empty-state-icon mx-auto mb-4">
          <i class="fas fa-comments"></i>
        </div>
        <div class="fw-semibold chat-text-color" style="font-size:1rem;">{{ _i18n('llm.empty_state_title') }}</div>
      </div>

      <!-- Messages -->
      <div
        v-for="(msg, idx) in messages"
        :key="idx"
        class="d-flex"
        :class="msg.role === 'user' ? 'justify-content-end' : 'justify-content-start'"
      >
        <!-- Assistant avatar -->
        <div v-if="msg.role === 'assistant'" class="flex-shrink-0 me-2 mt-1">
          <span class="chat-avatar assistant-avatar">
            <i class="fas fa-robot"></i>
          </span>
        </div>

        <!-- Bubble -->
        <div
          class="chat-bubble"
          :class="msg.role === 'user'
            ? 'user-bubble'
            : msg.error
              ? 'error-bubble'
              : 'assistant-bubble'"
          style="max-width: min(72%, 640px);"
        >
          <!-- Error icon -->
          <div v-if="msg.error" class="d-flex align-items-center gap-2 mb-1 small fw-semibold error-label">
            <i class="fas fa-exclamation-circle"></i>
            {{ _i18n('llm.error_label') }}
          </div>

          <!-- Content -->
          <div
            v-if="msg.role === 'user'"
            class="chat-content"
            style="white-space: pre-wrap; word-break: break-word; font-size: 0.9rem; line-height: 1.55;"
          >{{ msg.content }}</div>
          <div
            v-else
            class="chat-content markdown-body"
            style="word-break: break-word; font-size: 0.9rem; line-height: 1.55;"
            v-html="renderMarkdown(msg.content)"
          ></div>

          <!-- Timestamp + stats -->
          <div
            class="mt-1 d-flex align-items-center gap-2 flex-wrap"
            :class="msg.role === 'user' ? 'bubble-meta-user' : 'bubble-meta-assistant'"
            style="font-size:0.7rem;"
          >
            <span>{{ msg.time }}</span>
            <template v-if="msg.role === 'assistant' && msg.stats && msg.stats.completion_time_s != null">
              <span class="opacity-40">·</span>
              <span>{{ msg.stats.completion_time_s }}s</span>
              <template v-if="msg.stats.generation_tokens_per_second != null">
                <span class="opacity-40">·</span>
                <span>{{ msg.stats.generation_tokens_per_second }} tok/s</span>
              </template>
            </template>
          </div>
        </div>

        <!-- User avatar -->
        <div v-if="msg.role === 'user'" class="flex-shrink-0 ms-2 mt-1">
          <span class="chat-avatar user-avatar">
            <i class="fas fa-user"></i>
          </span>
        </div>
      </div>

      <!-- Typing indicator -->
      <div v-if="sending" class="d-flex justify-content-start">
        <span class="chat-avatar assistant-avatar me-2 mt-1 flex-shrink-0">
          <i class="fas fa-robot"></i>
        </span>
        <div class="assistant-bubble chat-bubble d-flex align-items-center gap-1" style="height:40px; padding: 0 1rem;">
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
        </div>
      </div>
    </div>

    <!-- Input bar -->
    <div class="chat-footer px-3 py-2 flex-shrink-0">
      <!-- Timeout warning strip -->
      <div v-if="timedOut" class="timeout-alert d-flex align-items-center gap-2 mb-2 small">
        <i class="fas fa-clock"></i>
        {{ _i18n('llm.timeout_warning') }}
        <button class="btn btn-sm btn-link p-0 ms-auto timeout-dismiss" @click="timedOut = false">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="d-flex gap-2 align-items-end">
        <textarea
          ref="promptInput"
          v-model="prompt"
          class="chat-input form-control"
          :placeholder="_i18n('llm.input_placeholder')"
          rows="1"
          style="resize: none; max-height: 120px; overflow-y: auto;"
          :disabled="sending || providers.length === 0"
          @keydown.enter.exact.prevent="send"
          @input="autoResize"
        ></textarea>

        <button
          class="btn-send d-flex align-items-center gap-2 flex-shrink-0"
          style="height: 38px;"
          :disabled="!canSend"
          @click="send"
        >
          <span v-if="sending" class="spinner-border spinner-border-sm" role="status"></span>
          <i v-else class="fas fa-paper-plane"></i>
          <span class="d-none d-sm-inline">{{ sending ? _i18n('llm.sending') : _i18n('llm.send') }}</span>
        </button>
      </div>

      <div class="chat-hint small mt-1">
        <i class="fas fa-keyboard me-1 opacity-50"></i>
        <span class="opacity-50">Enter</span> {{ _i18n('llm.send') }} &nbsp;·&nbsp;
        <span class="opacity-50">Shift+Enter</span> new line
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";
import MarkdownIt from "markdown-it";
import hljs from "highlight.js";
import DOMPurify from "dompurify";

// ── Markdown renderer ────────────────────────────────────────────────────────
const md = new MarkdownIt({
  html: false,
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

function renderMarkdown(content) {
  return DOMPurify.sanitize(md.render(content || ""));
}

// ── i18n ─────────────────────────────────────────────────────────────────────
const _i18n = (t) => i18n(t);

// ── Props ─────────────────────────────────────────────────────────────────────
const props = defineProps({
  context: {
    type: Object,
    default: () => ({}),
  },
});

// ── State ─────────────────────────────────────────────────────────────────────
const providers        = ref([]);
const selectedProvider = ref(null);
const loadingProviders = ref(true);

// UI messages — carry display metadata (timestamps, error flags, stats)
const messages = ref([]);

// API history — pure { role, content } pairs sent to the LLM each turn
const history  = ref([]);

const prompt   = ref("");
const sending  = ref(false);
const timedOut = ref(false);

const messageList = ref(null);
const promptInput = ref(null);

const MAX_HISTORY = 40; // max individual messages kept (20 user + 20 assistant)
const timeoutSec  = 120;

// ── Computed ──────────────────────────────────────────────────────────────────
const canSend = computed(() =>
  !sending.value &&
  prompt.value.trim().length > 0 &&
  selectedProvider.value !== null
);

// ── Helpers ───────────────────────────────────────────────────────────────────
function nowTime() {
  return new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function pushMessage(role, content, error = false, stats = null) {
  messages.value.push({ role, content, time: nowTime(), error, stats });
  nextTick(scrollBottom);
}

function scrollBottom() {
  if (messageList.value) {
    messageList.value.scrollTop = messageList.value.scrollHeight;
  }
}

function autoResize(e) {
  const el = e.target;
  el.style.height = "auto";
  el.style.height = Math.min(el.scrollHeight, 120) + "px";
}

function resetTextarea() {
  if (promptInput.value) {
    promptInput.value.style.height = "auto";
  }
}

function clearChat() {
  messages.value = [];
  history.value  = [];
}

// ── Providers ─────────────────────────────────────────────────────────────────
async function loadProviders() {
  loadingProviders.value = true;
  try {
    const url  = `${http_prefix}/lua/pro/rest/v2/get/llm/providers.lua`;
    const list = await ntopng_utility.http_request(url) ?? [];
    providers.value = Array.isArray(list) ? list : [];
    if (providers.value.length > 0) selectedProvider.value = providers.value[0].provider;
  } catch (err) {
    console.error("llm providers fetch failed:", err);
    providers.value = [];
  } finally {
    loadingProviders.value = false;
  }
}

// ── Send ──────────────────────────────────────────────────────────────────────
async function send() {
  if (!canSend.value) return;

  const text = prompt.value.trim();
  prompt.value = "";
  resetTextarea();
  timedOut.value = false;

  // 1. Show user bubble immediately
  pushMessage("user", text);

  // 2. Append user turn to history
  history.value.push({ role: "user", content: text });

  // 3. Trim history if it exceeds the cap (always drop oldest user+assistant pair)
  while (history.value.length > MAX_HISTORY) {
    history.value.splice(0, 2);
  }

  sending.value = true;

  const controller = new AbortController();
  const timer = setTimeout(() => {
    controller.abort();
    timedOut.value = true;
  }, timeoutSec * 1000);

  try {
    const csrf = props.context.csrf;
    const url  = `${http_prefix}/lua/pro/rest/v2/post/llm/completion.lua`;

    // Send the full conversation history so the backend can forward it
    // to the provider's /v1/chat/completions endpoint as-is.
    const body = JSON.stringify({
      provider: selectedProvider.value,
      messages: history.value,   // ← full history instead of single prompt
      stream:   false,
      csrf,
    });

    const rsp = await ntopng_utility.http_request(url, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body,
      signal:  controller.signal,
    }, /* throw_exception */ true);

    clearTimeout(timer);

    const reply = rsp?.reply ?? null;
    if (!reply) throw new Error(_i18n("llm.empty_response_error"));

    // 4. Append assistant turn to history so next request includes it
    history.value.push({ role: "assistant", content: reply });

    pushMessage("assistant", reply, false, rsp?.stats ?? null);

  } catch (err) {
    clearTimeout(timer);

    // 5. Roll back the user turn from history on failure
    //    so a retry won't duplicate it
    history.value.pop();

    if (err.name === "AbortError") {
      pushMessage("assistant", _i18n("llm.timeout_error_message"), true);
    } else {
      pushMessage("assistant", `${_i18n("llm.request_error")}: ${err.message}`, true);
    }
  } finally {
    sending.value = false;
    nextTick(() => promptInput.value?.focus());
  }
}

// ── Lifecycle ─────────────────────────────────────────────────────────────────
onMounted(() => {
  loadProviders();
});
</script>

<style>
@import "highlight.js/styles/github.css";

/* strip hljs bg — we control backgrounds ourselves */
.hljs { background: transparent !important; }

/* ── Component-level theme tokens ─────────────────────────────────────── */
.llm-chat-page {
  --chat-header-bg:          var(--navbar-tab-container-bg, #f1f3f5);
  --chat-footer-bg:          var(--navbar-tab-container-bg, #f1f3f5);
  --chat-border:             rgba(0, 0, 0, 0.10);
  --chat-text:               var(--ntop-text-color, #111111);
  --chat-muted:              var(--ntop-muted-text-color, #37474F);
  --chat-icon:               var(--icon-color, #363943);

  /* user bubble: ntop orange */
  --user-bubble-bg:          var(--ntop-orange, #FF8F00);
  --user-bubble-shadow:      rgba(255, 143, 0, 0.30);

  /* assistant bubble */
  --assistant-bubble-bg:     #ffffff;
  --assistant-bubble-border: rgba(0, 0, 0, 0.10);
  --assistant-bubble-shadow: rgba(0, 0, 0, 0.06);

  /* error bubble */
  --error-bubble-bg:         #fff3f3;
  --error-bubble-border:     rgba(220, 53, 69, 0.25);
  --error-bubble-text:       #b91c1c;

  /* avatars */
  --assistant-avatar-bg:     var(--ntop-orange, #FF8F00);
  --user-avatar-bg:          var(--ntop-blue-light, #62717B);

  /* inputs */
  --input-bg:                #ffffff;
  --input-border:            rgba(0, 0, 0, 0.15);
  --input-focus-border:      var(--ntop-orange, #FF8F00);
  --input-focus-shadow:      rgba(255, 143, 0, 0.18);
  --input-text:              var(--ntop-text-color, #111111);
  --input-placeholder:       rgba(55, 71, 79, 0.55);

  /* code blocks */
  --code-bg:                 #f6f8fa;
  --code-border:             rgba(0, 0, 0, 0.10);
  --code-text:               #24292e;

  /* inline code */
  --inline-code-bg:          rgba(175, 184, 193, 0.22);

  /* misc */
  --send-btn-bg:             var(--ntop-orange, #FF8F00);
  --send-btn-hover:          var(--ntop-orange-dark, #C56000);
  --send-btn-shadow:         rgba(255, 143, 0, 0.35);
  --model-badge-bg:          rgba(255, 143, 0, 0.12);
  --model-badge-text:        var(--ntop-orange-dark, #C56000);
  --empty-icon-bg:           rgba(255, 143, 0, 0.10);
  --empty-icon-color:        var(--ntop-orange, #FF8F00);
  --hint-color:              var(--ntop-muted-text-color, #37474F);
  --timeout-bg:              #fffbeb;
  --timeout-border:          rgba(245, 158, 11, 0.35);
  --timeout-text:            #92400e;
  --scrollbar-thumb:         rgba(0, 0, 0, 0.15);

  /* clear button */
  --clear-btn-bg:            transparent;
  --clear-btn-border:        rgba(0, 0, 0, 0.15);
  --clear-btn-text:          var(--ntop-muted-text-color, #37474F);
  --clear-btn-hover-bg:      rgba(220, 53, 69, 0.08);
  --clear-btn-hover-border:  rgba(220, 53, 69, 0.35);
  --clear-btn-hover-text:    #b91c1c;

  /* history badge */
  --history-badge-bg:        rgba(0, 0, 0, 0.06);
  --history-badge-text:      var(--ntop-muted-text-color, #37474F);
}

/* ── Dark-mode overrides ──────────────────────────────────────────────── */
:root[data-theme='dark'] .llm-chat-page {
  --chat-border:             rgba(255, 255, 255, 0.08);

  --assistant-bubble-bg:     #1e2d36;
  --assistant-bubble-border: rgba(255, 255, 255, 0.08);
  --assistant-bubble-shadow: rgba(0, 0, 0, 0.20);

  --error-bubble-bg:         rgba(185, 28, 28, 0.15);
  --error-bubble-border:     rgba(239, 68, 68, 0.30);
  --error-bubble-text:       #fca5a5;

  --input-bg:                #162028;
  --input-border:            rgba(255, 255, 255, 0.10);
  --input-text:              var(--ntop-text-color, #E2E2E2);
  --input-placeholder:       rgba(167, 166, 166, 0.55);

  --code-bg:                 #0d1b22;
  --code-border:             rgba(255, 255, 255, 0.10);
  --code-text:               #e2e8f0;

  --inline-code-bg:          rgba(255, 255, 255, 0.10);

  --model-badge-bg:          rgba(255, 143, 0, 0.15);
  --model-badge-text:        var(--ntop-orange-light, #FFC046);
  --empty-icon-bg:           rgba(255, 143, 0, 0.12);
  --hint-color:              var(--ntop-muted-text-color, #A7A6A6);
  --timeout-bg:              rgba(180, 120, 10, 0.15);
  --timeout-border:          rgba(251, 191, 36, 0.25);
  --timeout-text:            #fde68a;
  --scrollbar-thumb:         rgba(255, 255, 255, 0.12);

  --clear-btn-border:        rgba(255, 255, 255, 0.12);
  --clear-btn-text:          var(--ntop-muted-text-color, #A7A6A6);
  --clear-btn-hover-bg:      rgba(239, 68, 68, 0.12);
  --clear-btn-hover-border:  rgba(239, 68, 68, 0.35);
  --clear-btn-hover-text:    #fca5a5;

  --history-badge-bg:        rgba(255, 255, 255, 0.07);
  --history-badge-text:      var(--ntop-muted-text-color, #A7A6A6);
}

/* ── Dark-mode hljs overrides ─────────────────────────────────────────── */
:root[data-theme='dark'] .hljs            { color: #e2e8f0; }
:root[data-theme='dark'] .hljs-comment,
:root[data-theme='dark'] .hljs-quote      { color: #8b949e; font-style: italic; }
:root[data-theme='dark'] .hljs-keyword,
:root[data-theme='dark'] .hljs-selector-tag,
:root[data-theme='dark'] .hljs-deletion   { color: #ff7b72; }
:root[data-theme='dark'] .hljs-string,
:root[data-theme='dark'] .hljs-addition   { color: #a5d6ff; }
:root[data-theme='dark'] .hljs-title,
:root[data-theme='dark'] .hljs-section    { color: #d2a8ff; }
:root[data-theme='dark'] .hljs-number,
:root[data-theme='dark'] .hljs-literal    { color: #f2cc60; }
:root[data-theme='dark'] .hljs-built_in,
:root[data-theme='dark'] .hljs-type       { color: #ffa657; }
:root[data-theme='dark'] .hljs-attr,
:root[data-theme='dark'] .hljs-attribute  { color: #7ee787; }
:root[data-theme='dark'] .hljs-variable,
:root[data-theme='dark'] .hljs-template-variable { color: #e3b341; }
:root[data-theme='dark'] .hljs-punctuation { color: #c9d1d9; }

/* ── Markdown body ────────────────────────────────────────────────────── */
.markdown-body p:last-child { margin-bottom: 0; }

.markdown-body pre.code-block {
  background: var(--code-bg);
  border: 1px solid var(--code-border);
  border-radius: 8px;
  padding: 0.75rem 1rem;
  overflow-x: auto;
  margin: 0.5rem 0;
}
.markdown-body pre.code-block code {
  background: none;
  padding: 0;
  font-size: 0.82em;
  color: var(--code-text);
}
.markdown-body code:not(pre code) {
  background: var(--inline-code-bg);
  color: var(--chat-text);
  border-radius: 4px;
  padding: 0.1em 0.4em;
  font-size: 0.83em;
}
.markdown-body ul,
.markdown-body ol     { padding-left: 1.4rem; margin-bottom: 0.5rem; }
.markdown-body blockquote {
  border-left: 3px solid var(--ntop-orange, #FF8F00);
  padding-left: 0.75rem;
  color: var(--chat-muted);
  margin: 0.5rem 0;
  opacity: 0.85;
}
.markdown-body table  { border-collapse: collapse; width: 100%; margin: 0.5rem 0; font-size: 0.85em; }
.markdown-body th,
.markdown-body td     { border: 1px solid var(--chat-border); padding: 0.35rem 0.65rem; }
.markdown-body th     { background: var(--inline-code-bg); color: var(--chat-text); font-weight: 600; }
.markdown-body td     { color: var(--chat-text); }
.markdown-body a      { color: var(--ntop-orange, #FF8F00); }
.markdown-body h1, .markdown-body h2, .markdown-body h3,
.markdown-body h4, .markdown-body h5, .markdown-body h6 {
  color: var(--chat-text);
  margin-top: 0.75rem;
  margin-bottom: 0.35rem;
  font-weight: 600;
}
.markdown-body hr {
  border: none;
  border-top: 1px solid var(--chat-border);
  margin: 0.75rem 0;
}
</style>

<style scoped>
.ls-1 { letter-spacing: 0.05em; }

/* ── Layout ─────────────────────────────────────────────────────────── */
.llm-chat-page {
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid var(--chat-border);
}

/* ── Header ─────────────────────────────────────────────────────────── */
.chat-header {
  background: var(--chat-header-bg);
  border-bottom: 1px solid var(--chat-border);
}
.chat-header-label {
  color: var(--chat-muted);
  font-size: 0.7rem;
}
.model-badge {
  font-size: 0.7rem;
  color: var(--model-badge-text);
  background: var(--model-badge-bg);
  padding: 0.2rem 0.55rem;
  border-radius: 20px;
  font-weight: 500;
  letter-spacing: 0.02em;
}

/* ── History badge ───────────────────────────────────────────────────── */
.history-badge {
  font-size: 0.68rem;
  color: var(--history-badge-text);
  background: var(--history-badge-bg);
  padding: 0.18rem 0.5rem;
  border-radius: 20px;
  font-weight: 500;
  white-space: nowrap;
}

/* ── Clear button ────────────────────────────────────────────────────── */
.btn-clear {
  font-size: 0.75rem;
  color: var(--clear-btn-text);
  background: var(--clear-btn-bg);
  border: 1px solid var(--clear-btn-border);
  border-radius: 8px;
  padding: 0.2rem 0.6rem;
  cursor: pointer;
  transition: background .15s, border-color .15s, color .15s;
  white-space: nowrap;
  line-height: 1.6;
}
.btn-clear:hover:not(:disabled) {
  background: var(--clear-btn-hover-bg);
  border-color: var(--clear-btn-hover-border);
  color: var(--clear-btn-hover-text);
}
.btn-clear:disabled { opacity: 0.4; cursor: not-allowed; }

/* ── Chat select ─────────────────────────────────────────────────────── */
.chat-select {
  background-color: var(--input-bg) !important;
  border-color: var(--input-border) !important;
  color: var(--input-text) !important;
  font-size: 0.8rem;
}
.chat-select:focus {
  border-color: var(--input-focus-border) !important;
  box-shadow: 0 0 0 3px var(--input-focus-shadow) !important;
}

/* ── Message area ────────────────────────────────────────────────────── */
.chat-messages { background: transparent; }

/* ── Empty state ─────────────────────────────────────────────────────── */
.empty-state-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  background: var(--empty-icon-bg);
  color: var(--empty-icon-color);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.4rem;
}

/* ── Avatars ─────────────────────────────────────────────────────────── */
.chat-avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  font-size: 13px;
  color: #fff;
  flex-shrink: 0;
}
.assistant-avatar { background: var(--assistant-avatar-bg); box-shadow: 0 2px 6px var(--user-bubble-shadow); }
.user-avatar      { background: var(--user-avatar-bg); }

/* ── Chat bubbles ────────────────────────────────────────────────────── */
.chat-bubble {
  padding: 0.55rem 0.85rem;
  border-radius: 16px;
  animation: fadeUp .18s ease-out;
}

.user-bubble {
  background: var(--user-bubble-bg);
  color: #fff;
  border-radius: 16px 16px 4px 16px;
  box-shadow: 0 2px 8px var(--user-bubble-shadow);
}
.bubble-meta-user { color: rgba(255,255,255,0.65); }

.assistant-bubble {
  background: var(--assistant-bubble-bg);
  border: 1px solid var(--assistant-bubble-border);
  color: var(--chat-text);
  border-radius: 16px 16px 16px 4px;
  box-shadow: 0 2px 8px var(--assistant-bubble-shadow);
}
.bubble-meta-assistant { color: var(--chat-muted); }

.error-bubble {
  background: var(--error-bubble-bg);
  border: 1px solid var(--error-bubble-border);
  color: var(--error-bubble-text);
  border-radius: 16px 16px 16px 4px;
}
.error-label { color: var(--error-bubble-text); }

/* ── Text helpers ────────────────────────────────────────────────────── */
.chat-text-color { color: var(--chat-text); }
.chat-muted-text { color: var(--chat-muted); }

/* ── Footer / input ──────────────────────────────────────────────────── */
.chat-footer {
  background: var(--chat-footer-bg);
  border-top: 1px solid var(--chat-border);
}

.chat-input {
  background-color: var(--input-bg) !important;
  border-color: var(--input-border) !important;
  color: var(--input-text) !important;
  border-radius: 10px !important;
  font-size: 0.9rem;
  transition: border-color .15s, box-shadow .15s;
  line-height: 1.5;
  padding: 0.45rem 0.75rem;
}
.chat-input::placeholder { color: var(--input-placeholder) !important; }
.chat-input:focus {
  border-color: var(--input-focus-border) !important;
  box-shadow: 0 0 0 3px var(--input-focus-shadow) !important;
  outline: none;
}
.chat-input:disabled { opacity: 0.5; }

/* ── Send button ─────────────────────────────────────────────────────── */
.btn-send {
  background: var(--send-btn-bg);
  color: #fff;
  border: none;
  border-radius: 10px;
  padding: 0 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: background .15s, box-shadow .15s, transform .1s;
  white-space: nowrap;
}
.btn-send:hover:not(:disabled) {
  background: var(--send-btn-hover);
  box-shadow: 0 4px 12px var(--send-btn-shadow);
  transform: translateY(-1px);
}
.btn-send:active:not(:disabled) { transform: translateY(0); }
.btn-send:disabled { opacity: 0.45; cursor: not-allowed; }

/* ── Hint line ───────────────────────────────────────────────────────── */
.chat-hint { color: var(--hint-color); font-size: 0.7rem; }

/* ── Timeout alert ───────────────────────────────────────────────────── */
.timeout-alert {
  background: var(--timeout-bg);
  border: 1px solid var(--timeout-border);
  color: var(--timeout-text);
  border-radius: 8px;
  padding: 0.35rem 0.75rem;
}
.timeout-dismiss {
  color: var(--timeout-text) !important;
  opacity: 0.7;
  text-decoration: none;
}
.timeout-dismiss:hover { opacity: 1; }

/* ── Typing dots ─────────────────────────────────────────────────────── */
.typing-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--ntop-orange, #FF8F00);
  animation: blink 1.2s infinite;
  opacity: 0.6;
}
.typing-dot:nth-child(2) { animation-delay: 0.2s; }
.typing-dot:nth-child(3) { animation-delay: 0.4s; }

@keyframes blink {
  0%, 80%, 100% { opacity: 0.2; transform: scale(0.85); }
  40%           { opacity: 0.8; transform: scale(1); }
}

/* ── Animations ──────────────────────────────────────────────────────── */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(6px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* ── Scrollbar ───────────────────────────────────────────────────────── */
.overflow-auto::-webkit-scrollbar       { width: 5px; }
.overflow-auto::-webkit-scrollbar-track { background: transparent; }
.overflow-auto::-webkit-scrollbar-thumb {
  background: var(--scrollbar-thumb);
  border-radius: 4px;
}
</style>