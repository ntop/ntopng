<template>
  <div class="llm-widget d-flex flex-column h-100">

    <!-- header: provider selector + utility toggles -->
    <div class="chat-header d-flex align-items-center gap-2 px-3 py-2 flex-shrink-0">

      <!-- Provider selector -->
      <LlmProviderSelector
        :providers="providers"
        :selected_provider="selectedProvider"
        :loading="loadingProviders"
        :disabled="sending"
        @select="selectProvider"
      />

      <div class="ms-auto d-flex align-items-center gap-1">
        <!-- Concise mode -->
        <button class="sidebar-toggle-btn" :class="{ active: conciseMode }"
          :title="conciseMode ? 'Concise mode on' : 'Concise mode off'" @click="conciseMode = !conciseMode">
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
    <LlmChatMessages
      :messages="messages"
      :sending="sending"
      :liveSteps="liveSteps"
      :openSqlPanels="openSqlPanels"
      :providers="providers"
      :aiPolicyUrl="aiPolicyUrl"
      :activeMonitoringUrl="activeMonitoringUrl"
      :activePresets="activePresetQuestions"
      @toggle-sql-panel="toggleSqlPanel"
      @fill-step="fillStep"
    />

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
          :placeholder="_i18n('llm.input_placeholder')" rows="1" style="resize:none;max-height:120px;overflow-y:auto;"
          :disabled="providers.length === 0" @keydown.enter.exact.prevent="send" @input="autoResize"></textarea>

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
import { onMounted, nextTick } from "vue";
import { default as LlmProviderSelector } from "./llm-provider-selector.vue";
import LlmChatMessages from "./llm-chat-messages.vue";
import { useLlmChat } from "./composables/useLlmChat.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: { type: Object, default: () => ({}) },
});

const {
  promptInput,
  messages, sending, timedOut, prompt, conciseMode,
  providers, selectedProvider, loadingProviders,
  openSqlPanels, debugStatus, liveSteps,
  currentSendingLabel, canSendMsg,
  activePresetQuestions,
  loadProviders, selectProvider, send, sendDebug,
  autoResize, toggleSqlPanel,
} = useLlmChat(props);

const aiPolicyUrl = `${http_prefix}/lua/pro/ai_policy.lua`;
const activeMonitoringUrl = `${http_prefix}/lua/active_monitoring.lua`;

function fillStep(text) {
  prompt.value = text;
  nextTick(() => promptInput.value?.focus());
}

onMounted(() => loadProviders());
</script>

<style scoped>
.llm-widget {
  --chat-header-bg: var(--navbar-tab-container-bg, #f1f3f5);
  --chat-footer-bg: var(--navbar-tab-container-bg, #f1f3f5);
  --chat-border: rgba(0, 0, 0, 0.10);
  --chat-text: var(--ntop-text-color, #111111);
  --chat-muted: var(--ntop-muted-text-color, #37474F);
  --provider-pill-bg: rgba(255, 255, 255, 0.75);
  --provider-pill-border: rgba(0, 0, 0, 0.12);
  --provider-name-color: var(--ntop-text-color, #111111);
  --provider-model-color: var(--ntop-muted-text-color, #37474F);
  --provider-dropdown-bg: #ffffff;
  --provider-option-hover: rgba(255, 143, 0, 0.07);
  --provider-option-active: rgba(255, 143, 0, 0.12);
  --provider-check-color: var(--ntop-orange, #FF8F00);
  --user-bubble-bg: var(--ntop-orange, #FF8F00);
  --user-bubble-shadow: rgba(255, 143, 0, 0.30);
  --assistant-bubble-bg: #ffffff;
  --assistant-bubble-border: rgba(0, 0, 0, 0.10);
  --assistant-bubble-shadow: rgba(0, 0, 0, 0.06);
  --error-bubble-bg: #fff3f3;
  --error-bubble-border: rgba(220, 53, 69, 0.25);
  --error-bubble-text: #b91c1c;
  --assistant-avatar-bg: var(--ntop-orange, #FF8F00);
  --user-avatar-bg: var(--ntop-blue-light, #62717B);
  --input-bg: #ffffff;
  --input-border: rgba(0, 0, 0, 0.15);
  --input-focus-border: var(--ntop-orange, #FF8F00);
  --input-focus-shadow: rgba(255, 143, 0, 0.18);
  --input-text: var(--ntop-text-color, #111111);
  --input-placeholder: rgba(55, 71, 79, 0.55);
  --code-bg: #f6f8fa;
  --code-border: rgba(0, 0, 0, 0.10);
  --code-text: #24292e;
  --inline-code-bg: rgba(175, 184, 193, 0.22);
  --send-btn-bg: var(--ntop-orange, #FF8F00);
  --send-btn-hover: var(--ntop-orange-dark, #C56000);
  --send-btn-shadow: rgba(255, 143, 0, 0.35);
  --empty-icon-bg: rgba(255, 143, 0, 0.10);
  --empty-icon-color: var(--ntop-orange, #FF8F00);
  --timeout-bg: #fffbeb;
  --timeout-border: rgba(245, 158, 11, 0.35);
  --timeout-text: #92400e;
  --scrollbar-thumb: rgba(0, 0, 0, 0.15);
  --provider-pill-hover-border: var(--ntop-orange, #FF8F00);
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid var(--chat-border);
}

:root[data-theme='dark'] .llm-widget {
  --chat-border: rgba(255, 255, 255, 0.08);
  --provider-pill-bg: rgba(255, 255, 255, 0.06);
  --provider-pill-border: rgba(255, 255, 255, 0.12);
  --provider-name-color: var(--ntop-text-color, #E2E2E2);
  --provider-model-color: var(--ntop-muted-text-color, #A7A6A6);
  --provider-dropdown-bg: #1a2a35;
  --provider-option-hover: rgba(255, 255, 255, 0.06);
  --provider-option-active: rgba(255, 143, 0, 0.14);
  --assistant-bubble-bg: #1e2d36;
  --assistant-bubble-border: rgba(255, 255, 255, 0.08);
  --assistant-bubble-shadow: rgba(0, 0, 0, 0.20);
  --error-bubble-bg: rgba(185, 28, 28, 0.15);
  --error-bubble-border: rgba(239, 68, 68, 0.30);
  --error-bubble-text: #fca5a5;
  --input-bg: #162028;
  --input-border: rgba(255, 255, 255, 0.10);
  --input-text: var(--ntop-text-color, #E2E2E2);
  --input-placeholder: rgba(167, 166, 166, 0.55);
  --code-bg: #0d1b22;
  --code-border: rgba(255, 255, 255, 0.10);
  --code-text: #e2e8f0;
  --inline-code-bg: rgba(255, 255, 255, 0.10);
  --timeout-bg: rgba(180, 120, 10, 0.15);
  --timeout-border: rgba(251, 191, 36, 0.25);
  --timeout-text: #fde68a;
  --scrollbar-thumb: rgba(255, 255, 255, 0.12);
}

/* Header */
.chat-header {
  background: var(--chat-header-bg);
  border-bottom: 1px solid var(--chat-border);
}

/* Toolbar buttons */
.sidebar-toggle-btn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: 1px solid var(--chat-border);
  border-radius: 8px;
  color: var(--chat-muted);
  font-size: 0.78rem;
  cursor: pointer;
  text-decoration: none;
  transition: background 0.15s, border-color 0.15s, color 0.15s;
}

.sidebar-toggle-btn:hover {
  background: var(--provider-pill-bg);
  border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
}

.sidebar-toggle-btn.active {
  background: var(--provider-pill-bg);
  border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
}

.sidebar-toggle-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

/* Footer */
.chat-footer {
  background: var(--chat-footer-bg);
  border-top: 1px solid var(--chat-border);
}

.chat-input {
  background: var(--input-bg) !important;
  border-color: var(--input-border) !important;
  color: var(--input-text) !important;
  border-radius: 10px !important;
  font-size: 0.9rem;
  transition: border-color 0.15s, box-shadow 0.15s;
}

.chat-input::placeholder {
  color: var(--input-placeholder) !important;
}

.chat-input:focus {
  border-color: var(--input-focus-border) !important;
  box-shadow: 0 0 0 3px var(--input-focus-shadow) !important;
}

.btn-send {
  background: var(--send-btn-bg);
  color: #fff;
  border: none;
  border-radius: 10px;
  padding: 0 1rem;
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  box-shadow: 0 2px 8px var(--send-btn-shadow);
  transition: background 0.15s, opacity 0.15s;
  white-space: nowrap;
}

.btn-send:hover:not(:disabled) {
  background: var(--send-btn-hover);
}

.btn-send:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.ai-disclaimer {
  color: var(--chat-muted);
  opacity: 0.7;
  font-size: 0.68rem !important;
}

.timeout-alert {
  background: var(--timeout-bg);
  border: 1px solid var(--timeout-border);
  color: var(--timeout-text);
  border-radius: 8px;
  padding: 0.4rem 0.75rem;
}

.timeout-dismiss {
  color: var(--timeout-text) !important;
}
</style>
