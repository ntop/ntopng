<template>
  <div class="llm-widget d-flex flex-column h-100">

    <!-- header: provider selector + utility toggles -->
    <div class="chat-header d-flex align-items-center gap-2 px-3 py-2 flex-shrink-0">

      <!-- Provider selector -->
      <div v-if="loadingProviders" class="d-flex align-items-center gap-2 small chat-muted-text">
        <span class="spinner-border spinner-border-sm" role="status"></span>
        {{ _i18n('llm.loading_providers') }}
      </div>
      <div v-else-if="providers.length === 0" class="text-warning small d-flex align-items-center gap-1">
        <i class="fas fa-exclamation-triangle"></i>
        {{ _i18n('llm.no_providers') }}
      </div>
      <div v-else class="provider-selector-wrapper flex-shrink-0" ref="providerSelectorRef">
        <div class="provider-pill" :class="{ open: providerDropdownOpen, disabled: sending }"
          @click.stop="!sending && (providerDropdownOpen = !providerDropdownOpen)">
          <span class="provider-pill-icon"><i :class="getProviderIcon(selectedProvider)"></i></span>
          <span class="provider-pill-info">
            <span class="provider-pill-name">{{ _i18n('prefs.' + selectedProvider) }}</span>
            <span class="provider-pill-model">{{ selectedProviderInfo?.model }}</span>
          </span>
          <i class="fas fa-chevron-down provider-pill-chevron"></i>
        </div>
        <div v-if="providerDropdownOpen" class="provider-dropdown">
          <div v-for="p in providers" :key="p.provider" class="provider-option"
            :class="{ active: p.provider === selectedProvider }" @click.stop="selectProvider(p.provider)">
            <span class="provider-option-icon"><i :class="getProviderIcon(p.provider)"></i></span>
            <span class="provider-option-info">
              <span class="provider-option-name">{{ _i18n('prefs.' + p.provider) }}</span>
              <span class="provider-option-model">{{ p.model }}</span>
            </span>
            <i v-if="p.provider === selectedProvider" class="fas fa-check provider-option-check"></i>
          </div>
        </div>
      </div>

      <div class="ms-auto d-flex align-items-center gap-1">
        <!-- Concise mode -->
        <button class="sidebar-toggle-btn" :class="{ active: conciseMode }"
          :title="conciseMode ? 'Concise mode on' : 'Concise mode off'"
          @click="conciseMode = !conciseMode">
          <i class="bi bi-fire"></i>
        </button>
        <!-- Debug -->
        <button class="sidebar-toggle-btn" :title="debugStatus || 'Send debug dump to server'"
          :class="{ active: !!debugStatus }" :disabled="messages.length === 0" @click="sendDebug">
          <i class="fas fa-bug"></i>
        </button>
      </div>
    </div>

    <!-- Message list -->
    <div ref="messageList" class="chat-messages flex-grow-1 overflow-auto px-3 py-3 d-flex flex-column gap-2"
      style="position: relative;">

      <!-- Empty state with preset questions -->
      <div v-if="messages.length === 0" class="empty-state-block m-auto text-center">
        <div class="empty-state-icon mx-auto mb-3">
          <i class="fas fa-comments"></i>
        </div>
        <p class="fw-semibold mb-3" style="font-size:0.95rem; color:var(--chat-text);">
          {{ _i18n('llm.ask_a_question') }}
        </p>
        <div class="preset-grid-inline">
          <button v-for="q in PRESET_QUESTIONS" :key="q" class="preset-chip"
            :disabled="sending || providers.length === 0"
            @click="sendPreset(q)">
            {{ q }}
          </button>
        </div>
      </div>

      <!-- Messages -->
      <div v-for="(msg, idx) in messages" :key="idx" class="d-flex"
        :class="msg.role === 'user' ? 'justify-content-end' : 'justify-content-start'">

        <div v-if="msg.role === 'assistant'" class="flex-shrink-0 me-2 mt-1">
          <span class="chat-avatar assistant-avatar"><i class="fas fa-robot"></i></span>
        </div>

        <div class="chat-bubble" :class="msg.role === 'user' ? 'user-bubble' : msg.error ? 'error-bubble' : 'assistant-bubble'">
          <div v-if="msg.error" class="d-flex align-items-center gap-2 mb-1 small fw-semibold error-label">
            <i class="fas fa-exclamation-circle"></i>{{ _i18n('llm.error_label') }}
          </div>

          <div v-if="msg.artifact" class="chat-artifact-block">
            <PieChart v-if="msg.artifact.tool === 'chart' && msg.artifact.spec?.type === 'pie'" :chart="{
              title: msg.artifact.spec.title, unit: msg.artifact.spec.unit,
              custom_fetch: () => msg.artifact.spec.data }" :hideLoading="true" />
            <LineChart v-if="msg.artifact.tool === 'chart' && msg.artifact.spec?.type === 'line'" :chart="{
              title: msg.artifact.spec.title, unit: msg.artifact.spec.unit,
              custom_fetch: () => msg.artifact.spec.data }" :hideLoading="true" />
          </div>

          <div v-if="msg.role === 'user'" class="chat-content"
            style="white-space:pre-wrap;word-break:break-word;font-size:0.9rem;line-height:1.55;">{{ msg.content }}</div>
          <div v-else class="chat-content markdown-body"
            style="word-break:break-word;font-size:0.9rem;line-height:1.55;"
            v-html="renderMarkdown(msg.content)"></div>

          <div class="mt-1 d-flex align-items-center gap-2 flex-wrap"
            :class="msg.role === 'user' ? 'bubble-meta-user' : 'bubble-meta-assistant'"
            style="font-size:0.7rem;">
            <span>{{ msg.time }}</span>
            <template v-if="msg.role === 'assistant' && msg.stats?.completion_time_s != null">
              <span class="opacity-40">·</span><span>{{ msg.stats.completion_time_s }}s</span>
              <template v-if="msg.stats.generation_tokens_per_second != null">
                <span class="opacity-40">·</span><span>{{ msg.stats.generation_tokens_per_second }} tok/s</span>
              </template>
            </template>
          </div>

          <template v-if="msg.queries && msg.queries.length">
            <div class="mt-1">
              <button class="btn btn-link p-0 sql-toggle-btn" @click="toggleSqlPanel(idx)">
                <i :class="openSqlPanels.has(idx) ? 'fas fa-chevron-up' : 'fas fa-chevron-down'"
                  class="me-1" style="font-size:0.65rem;"></i>
                {{ openSqlPanels.has(idx) ? _i18n('llm.hide_evidence') : _i18n('llm.show_evidence') }}
              </button>
              <div v-if="openSqlPanels.has(idx)" class="sql-panel mt-1">
                <pre v-for="(q, qi) in msg.queries" :key="qi" class="sql-block hljs" v-html="highlightSql(q)"></pre>
              </div>
            </div>
          </template>
        </div>

        <div v-if="msg.role === 'user'" class="flex-shrink-0 ms-2 mt-1">
          <span class="chat-avatar user-avatar"><i class="fas fa-user"></i></span>
        </div>
      </div>

      <!-- Typing indicator -->
      <div v-if="sending" class="d-flex justify-content-start">
        <span class="chat-avatar assistant-avatar me-2 mt-1 flex-shrink-0"><i class="fas fa-robot"></i></span>
        <div class="assistant-bubble chat-bubble d-flex align-items-center gap-1" style="height:40px;padding:0 1rem;">
          <span class="typing-dot"></span><span class="typing-dot"></span><span class="typing-dot"></span>
        </div>
      </div>

      <!-- Scroll overlay buttons -->
      <div class="scroll-overlay-btns" v-if="messages.length > 0">
        <button class="scroll-overlay-btn" title="Scroll to start of last message" @click="scrollToLastMessage">
          <i class="fas fa-chevron-up"></i>
        </button>
        <button class="scroll-overlay-btn" title="Scroll to bottom" @click="scrollBottom">
          <i class="fas fa-chevron-down"></i>
        </button>
      </div>
    </div>

    <!-- Input bar -->
    <div class="chat-footer px-3 py-2 flex-shrink-0">
      <div v-if="timedOut" class="timeout-alert d-flex align-items-center gap-2 mb-2 small">
        <i class="fas fa-clock"></i>{{ _i18n('llm.timeout_warning') }}
        <button class="btn btn-sm btn-link p-0 ms-auto timeout-dismiss" @click="timedOut = false">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="d-flex gap-2 align-items-end">
        <textarea ref="promptInput" v-model="prompt" class="chat-input form-control"
          :placeholder="_i18n('llm.input_placeholder')" rows="1"
          style="resize:none;max-height:120px;overflow-y:auto;" :disabled="providers.length === 0"
          @keydown.enter.exact.prevent="send" @input="autoResize"></textarea>

        <button class="btn-send d-flex align-items-center gap-2 flex-shrink-0" style="height:38px;"
          :disabled="!canSendMsg" @click="send">
          <span v-if="sending" class="spinner-border spinner-border-sm" role="status"></span>
          <i v-else class="fas fa-paper-plane"></i>
          <span class="d-none d-sm-inline">{{ sending ? currentSendingLabel : _i18n('llm.send') }}</span>
        </button>
      </div>
      <div class="ai-disclaimer small mt-1">
        <i class="fas fa-triangle-exclamation me-1"></i>{{ _i18n('llm.ai_can_make_mistakes') }}
      </div>
    </div>

  </div>
</template>

<script setup>
import { onMounted, onBeforeUnmount, ref } from "vue";
import PieChart from "./charts/pie-chart.vue";
import LineChart from "./charts/line-chart.vue";
import {
  useLlmChat, renderMarkdown, highlightSql, getProviderIcon, PRESET_QUESTIONS
} from "./composables/useLlmChat.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: { type: Object, default: () => ({}) },
});

const {
  messageList, promptInput,
  messages, sending, timedOut, prompt, conciseMode,
  providers, selectedProvider, loadingProviders,
  openSqlPanels, debugStatus,
  currentSendingLabel, canSendMsg, selectedProviderInfo,
  loadProviders, selectProvider, send, sendPreset, sendDebug,
  scrollBottom, scrollToLastMessage, autoResize, toggleSqlPanel,
} = useLlmChat(props);

// Provider dropdown state
const providerDropdownOpen = ref(false);
const providerSelectorRef  = ref(null);

function onDocumentClick(e) {
  if (providerSelectorRef.value && !providerSelectorRef.value.contains(e.target)) {
    providerDropdownOpen.value = false;
  }
}

onMounted(() => {
  loadProviders();
  document.addEventListener("click", onDocumentClick);
});

onBeforeUnmount(() => {
  document.removeEventListener("click", onDocumentClick);
});
</script>

<style>
@import "highlight.js/styles/github.css";
.hljs { background: transparent !important; }
</style>

<style scoped>
/* CSS custom properties (on root so all children inherit) */
.llm-widget {
  --chat-header-bg: var(--navbar-tab-container-bg, #f1f3f5);
  --chat-footer-bg: var(--navbar-tab-container-bg, #f1f3f5);
  --chat-border: rgba(0,0,0,0.10);
  --chat-text: var(--ntop-text-color, #111111);
  --chat-muted: var(--ntop-muted-text-color, #37474F);
  --chat-icon: var(--icon-color, #363943);
  --provider-pill-bg: rgba(255,255,255,0.75);
  --provider-pill-border: rgba(0,0,0,0.12);
  --provider-name-color: var(--ntop-text-color, #111111);
  --provider-model-color: var(--ntop-muted-text-color, #37474F);
  --provider-dropdown-bg: #ffffff;
  --provider-option-hover: rgba(255,143,0,0.07);
  --provider-option-active: rgba(255,143,0,0.12);
  --provider-check-color: var(--ntop-orange, #FF8F00);
  --user-bubble-bg: var(--ntop-orange, #FF8F00);
  --user-bubble-shadow: rgba(255,143,0,0.30);
  --assistant-bubble-bg: #ffffff;
  --assistant-bubble-border: rgba(0,0,0,0.10);
  --assistant-bubble-shadow: rgba(0,0,0,0.06);
  --error-bubble-bg: #fff3f3;
  --error-bubble-border: rgba(220,53,69,0.25);
  --error-bubble-text: #b91c1c;
  --assistant-avatar-bg: var(--ntop-orange, #FF8F00);
  --user-avatar-bg: var(--ntop-blue-light, #62717B);
  --input-bg: #ffffff;
  --input-border: rgba(0,0,0,0.15);
  --input-focus-border: var(--ntop-orange, #FF8F00);
  --input-focus-shadow: rgba(255,143,0,0.18);
  --input-text: var(--ntop-text-color, #111111);
  --input-placeholder: rgba(55,71,79,0.55);
  --code-bg: #f6f8fa;
  --code-border: rgba(0,0,0,0.10);
  --code-text: #24292e;
  --inline-code-bg: rgba(175,184,193,0.22);
  --send-btn-bg: var(--ntop-orange, #FF8F00);
  --send-btn-hover: var(--ntop-orange-dark, #C56000);
  --send-btn-shadow: rgba(255,143,0,0.35);
  --empty-icon-bg: rgba(255,143,0,0.10);
  --empty-icon-color: var(--ntop-orange, #FF8F00);
  --timeout-bg: #fffbeb;
  --timeout-border: rgba(245,158,11,0.35);
  --timeout-text: #92400e;
  --scrollbar-thumb: rgba(0,0,0,0.15);
  --hint-color: var(--ntop-muted-text-color, #37474F);
  --provider-pill-hover-border: var(--ntop-orange, #FF8F00);
  --clear-btn-bg: transparent;
  --clear-btn-color: var(--ntop-muted-text-color, #37474F);
  --clear-btn-hover-bg: rgba(255,143,0,0.08);
  --clear-btn-hover-color: var(--ntop-orange, #FF8F00);
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid var(--chat-border);
}

:root[data-theme='dark'] .llm-widget {
  --chat-border: rgba(255,255,255,0.08);
  --provider-pill-bg: rgba(255,255,255,0.06);
  --provider-pill-border: rgba(255,255,255,0.12);
  --provider-name-color: var(--ntop-text-color, #E2E2E2);
  --provider-model-color: var(--ntop-muted-text-color, #A7A6A6);
  --provider-dropdown-bg: #1a2a35;
  --provider-option-hover: rgba(255,255,255,0.06);
  --provider-option-active: rgba(255,143,0,0.14);
  --assistant-bubble-bg: #1e2d36;
  --assistant-bubble-border: rgba(255,255,255,0.08);
  --assistant-bubble-shadow: rgba(0,0,0,0.20);
  --error-bubble-bg: rgba(185,28,28,0.15);
  --error-bubble-border: rgba(239,68,68,0.30);
  --error-bubble-text: #fca5a5;
  --input-bg: #162028;
  --input-border: rgba(255,255,255,0.10);
  --input-text: var(--ntop-text-color, #E2E2E2);
  --input-placeholder: rgba(167,166,166,0.55);
  --code-bg: #0d1b22;
  --code-border: rgba(255,255,255,0.10);
  --code-text: #e2e8f0;
  --inline-code-bg: rgba(255,255,255,0.10);
  --timeout-bg: rgba(180,120,10,0.15);
  --timeout-border: rgba(251,191,36,0.25);
  --timeout-text: #fde68a;
  --scrollbar-thumb: rgba(255,255,255,0.12);
}

/* Markdown */
:deep(.markdown-body) p:last-child { margin-bottom:0; }
:deep(.markdown-body) pre.code-block {
  background:var(--code-bg); border:1px solid var(--code-border); border-radius:8px;
  padding:0.75rem 1rem; overflow-x:auto; margin:0.5rem 0;
}
:deep(.markdown-body) pre.code-block code { background:none; padding:0; font-size:0.82em; color:var(--code-text); }
:deep(.markdown-body) code:not(pre code) {
  background:var(--inline-code-bg); color:var(--chat-text); border-radius:4px; padding:0.1em 0.4em; font-size:0.83em;
}
:deep(.markdown-body) ul, :deep(.markdown-body) ol { padding-left:1.4rem; margin-bottom:0.5rem; }
:deep(.markdown-body) blockquote {
  border-left:3px solid var(--ntop-orange,#FF8F00); padding-left:0.75rem;
  color:var(--chat-muted); margin:0.5rem 0; opacity:0.85;
}
:deep(.markdown-body) table { border-collapse:collapse; width:100%; margin:0.5rem 0; font-size:0.85em; }
:deep(.markdown-body) th, :deep(.markdown-body) td { border:1px solid var(--chat-border); padding:0.35rem 0.65rem; }
:deep(.markdown-body) th { background:var(--inline-code-bg); color:var(--chat-text); font-weight:600; }
:deep(.markdown-body) td { color:var(--chat-text); }
:deep(.markdown-body) a { color:var(--ntop-orange,#FF8F00); }
:deep(.markdown-body) h1,:deep(.markdown-body) h2,:deep(.markdown-body) h3,
:deep(.markdown-body) h4,:deep(.markdown-body) h5,:deep(.markdown-body) h6 {
  color:var(--chat-text); margin-top:0.75rem; margin-bottom:0.35rem; font-weight:600;
}
:deep(.markdown-body) hr { border:none; border-top:1px solid var(--chat-border); margin:0.75rem 0; }

/* Header */
.chat-header {
  background:var(--chat-header-bg);
  border-bottom:1px solid var(--chat-border);
}

/* Toolbar buttons */
.sidebar-toggle-btn {
  width:32px; height:32px; display:flex; align-items:center; justify-content:center;
  background:transparent; border:1px solid var(--chat-border); border-radius:8px;
  color:var(--chat-muted); font-size:0.78rem; cursor:pointer; text-decoration:none;
  transition:background 0.15s,border-color 0.15s,color 0.15s;
}
.sidebar-toggle-btn:hover {
  background:var(--provider-pill-bg);
  border-color:var(--ntop-orange,#FF8F00);
  color:var(--ntop-orange,#FF8F00);
}
.sidebar-toggle-btn.active {
  background:var(--provider-pill-bg);
  border-color:var(--ntop-orange,#FF8F00);
  color:var(--ntop-orange,#FF8F00);
}
.sidebar-toggle-btn:disabled { opacity:0.35; cursor:not-allowed; }

/* Provider pill / dropdown */
.provider-selector-wrapper { position:relative; }
.provider-pill {
  display:flex; align-items:center; gap:0.45rem; background:var(--provider-pill-bg);
  border:1px solid var(--provider-pill-border); border-radius:10px;
  padding:0.28rem 0.65rem 0.28rem 0.5rem;
  cursor:pointer; transition:border-color 0.15s, box-shadow 0.15s;
}
.provider-pill:hover:not(.disabled), .provider-pill.open:not(.disabled) {
  border-color:var(--provider-pill-hover-border);
  box-shadow:0 0 0 3px var(--input-focus-shadow);
}
.provider-pill.disabled { opacity:0.6; cursor:not-allowed; }
.provider-pill-icon {
  width:22px; height:22px; border-radius:6px; display:flex; align-items:center; justify-content:center;
  background:rgba(255,143,0,0.12); color:var(--ntop-orange,#FF8F00); font-size:0.82rem; flex-shrink:0;
}
.provider-pill-info { display:flex; flex-direction:column; line-height:1.2; }
.provider-pill-name { font-size:0.72rem; font-weight:600; color:var(--provider-name-color); }
.provider-pill-model { font-size:0.65rem; color:var(--provider-model-color); }
.provider-pill-chevron { font-size:0.6rem; color:var(--chat-muted); transition:transform 0.15s; }
.provider-pill.open .provider-pill-chevron { transform:rotate(180deg); }
.provider-dropdown {
  position:absolute; top:calc(100% + 6px); left:0; min-width:220px;
  background:var(--provider-dropdown-bg); border:1px solid var(--chat-border);
  border-radius:12px; box-shadow:0 6px 20px rgba(0,0,0,0.12); z-index:1050;
  padding:4px; overflow:hidden;
  animation:dropdownFadeIn 0.12s ease-out;
}
@keyframes dropdownFadeIn {
  from { opacity:0; transform:translateY(-4px); }
  to   { opacity:1; transform:translateY(0); }
}
.provider-option { display:flex; align-items:center; gap:0.5rem; padding:0.5rem 0.75rem; border-radius:8px; cursor:pointer; transition:background 0.12s; }
.provider-option:hover { background:var(--provider-option-hover); }
.provider-option.active { background:var(--provider-option-active); }
.provider-option-icon {
  width:22px; height:22px; border-radius:6px; display:flex; align-items:center; justify-content:center;
  background:rgba(255,143,0,0.10); color:var(--ntop-orange,#FF8F00); font-size:0.82rem; flex-shrink:0;
}
.provider-option-info { display:flex; flex-direction:column; flex-grow:1; line-height:1.2; }
.provider-option-name { font-size:0.75rem; font-weight:600; color:var(--provider-name-color); }
.provider-option-model { font-size:0.65rem; color:var(--provider-model-color); }
.provider-option-check { font-size:0.7rem; color:var(--provider-check-color); }

/* Message area */
.chat-messages {
  background: var(--ntop-bg-color, #f8f9fa);
}

/* Empty state */
.empty-state-block { max-width: 560px; width: 100%; padding: 1.5rem 0.5rem; }
.empty-state-icon {
  width: 52px; height: 52px; border-radius: 50%;
  background: var(--empty-icon-bg); display: flex; align-items: center; justify-content: center;
  color: var(--empty-icon-color); font-size: 1.3rem;
}
.preset-grid-inline {
  display: flex; flex-wrap: wrap; gap: 8px; justify-content: center;
}
.preset-chip {
  background: transparent; border: 1px solid var(--chat-border); border-radius: 20px;
  color: var(--chat-text); font-size: 0.76rem; padding: 0.3rem 0.8rem; cursor: pointer;
  transition: background 0.15s, border-color 0.15s, color 0.15s; white-space: nowrap;
  text-align: left;
}
.preset-chip:hover:not(:disabled) {
  background: rgba(255,143,0,0.10); border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
}
.preset-chip:disabled { opacity: 0.4; cursor: not-allowed; }

/* Chat bubbles */
.chat-bubble {
  padding: 0.6rem 0.85rem; border-radius: 14px;
  max-width: 90%;
  animation: fadeUp 0.18s ease-out;
}
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(6px); }
  to   { opacity: 1; transform: translateY(0); }
}
.user-bubble {
  background: var(--user-bubble-bg); color: #fff;
  box-shadow: 0 2px 8px var(--user-bubble-shadow);
  border-bottom-right-radius: 4px;
}
.user-bubble .bubble-meta-user { color: rgba(255,255,255,0.7); }
.assistant-bubble {
  background: var(--assistant-bubble-bg); border: 1px solid var(--assistant-bubble-border);
  box-shadow: 0 1px 6px var(--assistant-bubble-shadow); color: var(--chat-text);
  border-bottom-left-radius: 4px;
}
.assistant-bubble .bubble-meta-assistant { color: var(--chat-muted); }
.error-bubble {
  background: var(--error-bubble-bg); border: 1px solid var(--error-bubble-border);
  color: var(--error-bubble-text); border-bottom-left-radius: 4px;
}
.error-label { color: var(--error-bubble-text); }

/* Avatars */
.chat-avatar {
  width: 28px; height: 28px; border-radius: 50%; display: flex;
  align-items: center; justify-content: center; font-size: 0.75rem; flex-shrink: 0;
}
.assistant-avatar { background: var(--assistant-avatar-bg); color: #fff; }
.user-avatar { background: var(--user-avatar-bg); color: #fff; }

/* Typing indicator */
.typing-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: var(--chat-muted); opacity: 0.5;
  animation: typingPulse 1.2s infinite ease-in-out;
}
.typing-dot:nth-child(2) { animation-delay: 0.2s; }
.typing-dot:nth-child(3) { animation-delay: 0.4s; }
@keyframes typingPulse { 0%,80%,100%{transform:scale(1);opacity:0.5;} 40%{transform:scale(1.25);opacity:1;} }

/* SQL panel */
.sql-toggle-btn { font-size: 0.72rem; color: var(--chat-muted) !important; text-decoration: none !important; }
.sql-toggle-btn:hover { color: var(--ntop-orange, #FF8F00) !important; }
.sql-panel { border-radius: 8px; overflow: hidden; border: 1px solid var(--code-border); }
.sql-block { margin: 0; padding: 0.5rem 0.75rem; background: var(--code-bg); font-size: 0.78rem; line-height: 1.5; overflow-x: auto; }

/* Artifact block */
.chat-artifact-block { margin-bottom: 0.5rem; }

/* Scroll overlay buttons */
.scroll-overlay-btns {
  position: sticky; bottom: 8px; margin-left: auto;
  display: flex; flex-direction: column; gap: 4px;
  width: fit-content; pointer-events: none; align-self: flex-end;
}
.scroll-overlay-btn {
  width: 30px; height: 30px; display: flex; align-items: center; justify-content: center;
  background: var(--provider-pill-bg); border: 1px solid var(--chat-border);
  border-radius: 50%; color: var(--chat-muted); font-size: 0.68rem; cursor: pointer;
  box-shadow: 0 2px 6px rgba(0,0,0,0.10); transition: background 0.15s, color 0.15s, border-color 0.15s;
  padding: 0; pointer-events: auto;
}
.scroll-overlay-btn:hover { background: var(--ntop-orange, #FF8F00); border-color: var(--ntop-orange, #FF8F00); color: #fff; }

/* Footer */
.chat-footer {
  background: var(--chat-footer-bg);
  border-top: 1px solid var(--chat-border);
}
.chat-input {
  background: var(--input-bg) !important; border-color: var(--input-border) !important;
  color: var(--input-text) !important; border-radius: 10px !important; font-size: 0.9rem;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.chat-input::placeholder { color: var(--input-placeholder) !important; }
.chat-input:focus { border-color: var(--input-focus-border) !important; box-shadow: 0 0 0 3px var(--input-focus-shadow) !important; }
.btn-send {
  background: var(--send-btn-bg); color: #fff; border: none; border-radius: 10px;
  padding: 0 1rem; font-size: 0.85rem; font-weight: 500; cursor: pointer;
  box-shadow: 0 2px 8px var(--send-btn-shadow); transition: background 0.15s, opacity 0.15s;
  white-space: nowrap;
}
.btn-send:hover:not(:disabled) { background: var(--send-btn-hover); }
.btn-send:disabled { opacity: 0.5; cursor: not-allowed; }
.ai-disclaimer { color: var(--chat-muted); opacity: 0.7; font-size: 0.68rem !important; }
.timeout-alert {
  background: var(--timeout-bg); border: 1px solid var(--timeout-border);
  color: var(--timeout-text); border-radius: 8px; padding: 0.4rem 0.75rem;
}
.timeout-dismiss { color: var(--timeout-text) !important; }

/* Scrollbar */
.chat-messages::-webkit-scrollbar { width: 5px; }
.chat-messages::-webkit-scrollbar-track { background: transparent; }
.chat-messages::-webkit-scrollbar-thumb { background: var(--scrollbar-thumb); border-radius: 4px; }
</style>
