<template>
  <div class="llm-chat-page d-flex" style="height: 90vh; min-height: 500px;">

    <!-- Collapsible Chat History Sidebar -->
    <div class="chat-sidebar flex-shrink-0" :class="{ open: sidebarOpen }">
      <div class="chat-sidebar-inner d-flex flex-column h-100">

        <!-- Sidebar header -->
        <div class="sidebar-header d-flex align-items-center justify-content-between px-3 py-2 flex-shrink-0">
          <span class="sidebar-title fw-semibold small text-uppercase">
            <i class="fas fa-history me-1 opacity-75"></i>
            {{ _i18n("llm.history") }}
          </span>
          <button class="btn-icon-subtle" @click="sidebarOpen = false" title="Close">
            <i class="fas fa-times"></i>
          </button>
        </div>

        <!-- New chat button -->
        <div class="px-3 pb-2 pt-1 flex-shrink-0">
          <button class="btn-new-chat w-100" @click="startNewChat">
            <i class="fas fa-plus me-2"></i>
            {{ _i18n("llm.new_chat") }}
          </button>
        </div>

        <!-- Chat list -->
        <div class="sidebar-chat-list flex-grow-1 overflow-auto px-2 pb-2" style="position: relative;">
          <div v-if="loadingHistory" class="d-flex align-items-center justify-content-center py-4 chat-muted-text small gap-2">
            <span class="spinner-border spinner-border-sm"></span>
            {{ _i18n("loading") }}
          </div>
          <div v-else-if="chatHistory.length === 0" class="text-center py-4 chat-muted-text small px-2">
            <i class="fas fa-comment-slash d-block mb-2" style="font-size:1.4rem; opacity:0.3;"></i>
            {{ _i18n("llm.no_conversations_yet") }}
          </div>
          <div
            v-for="chat in chatHistory"
            :key="chat.chat_id"
            class="chat-history-item"
            :class="{ active: activeChatId === chat.chat_id }"
            @click="chat.isNew ? null : loadChat(chat.chat_id)"
            :title="chat.title"
          >
            <span class="chat-history-icon flex-shrink-0">
              <i :class="getProviderIcon(chat.provider)"></i>
            </span>
            <span class="chat-history-title">{{ chat.title }}</span>
            <span class="chat-history-actions flex-shrink-0 ms-auto" @click.stop>
              <button
                class="chat-item-action-btn"
                title="Rename"
                @click.stop="startRenameChat(chat)"
              ><i class="fas fa-pen"></i></button>
              <button
                class="chat-item-action-btn chat-item-delete-btn"
                title="Delete"
                @click.stop="deleteChat(chat.chat_id)"
              ><i class="fas fa-trash-alt"></i></button>
            </span>
          </div>

          <!-- Inline rename form -->
          <div v-if="renamingChatId" class="rename-overlay" @click.self="cancelRename">
            <div class="rename-popup px-3 py-2">
              <div class="rename-popup-label small fw-semibold mb-1">{{ _i18n("llm.rename_chat") }}</div>
              <input
                ref="renameInputRef"
                v-model="renameValue"
                class="rename-input form-control form-control-sm"
                @keydown.enter.prevent="confirmRename"
                @keydown.esc.prevent="cancelRename"
              />
              <div class="d-flex gap-2 mt-2">
                <button class="btn-rename-confirm flex-grow-1" @click="confirmRename">{{ _i18n("save") }}</button>
                <button class="btn-rename-cancel" @click="cancelRename">{{ _i18n("cancel") }}</button>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>

    <!-- Chat Area -->
    <div class="chat-main d-flex flex-column flex-grow-1" style="min-width: 0;">

      <!-- Header bar: sidebar toggle + provider selector + actions -->
      <div class="chat-header d-flex align-items-center gap-2 px-3 py-2 flex-shrink-0">

        <!-- Sidebar toggle -->
        <button
          class="sidebar-toggle-btn flex-shrink-0"
          @click="sidebarOpen = !sidebarOpen"
          :title="sidebarOpen ? 'Close history' : 'Chat history'"
        >
          <i :class="sidebarOpen ? 'fas fa-chevron-left' : 'fas fa-history'"></i>
        </button>

        <!-- Settings link -->
        <a
          class="sidebar-toggle-btn flex-shrink-0"
          :href="settingsUrl"
          title="LLM Settings"
        >
          <i class="fas fa-gear"></i>
        </a>

        <!-- Provider / model selector -->
        <div v-if="loadingProviders" class="d-flex align-items-center gap-2 small chat-muted-text ms-1">
          <span class="spinner-border spinner-border-sm" role="status"></span>
          {{ _i18n('llm.loading_providers') }}
        </div>
        <div v-else-if="providers.length === 0" class="text-warning small d-flex align-items-center gap-1 ms-1">
          <i class="fas fa-exclamation-triangle"></i>
          {{ _i18n('llm.no_providers') }}
        </div>
        <div v-else class="provider-selector-wrapper flex-shrink-0" ref="providerSelectorRef">
          <div
            class="provider-pill"
            :class="{ open: providerDropdownOpen, disabled: sending }"
            @click.stop="!sending && (providerDropdownOpen = !providerDropdownOpen)"
          >
            <span class="provider-pill-icon">
              <i :class="getProviderIcon(selectedProvider)"></i>
            </span>
            <span class="provider-pill-info">
              <span class="provider-pill-name">{{ _i18n("prefs." + selectedProvider) }}</span>
              <span class="provider-pill-model">{{ selectedProviderInfo?.model }}</span>
            </span>
            <i class="fas fa-chevron-down provider-pill-chevron"></i>
          </div>

          <!-- Options dropdown -->
          <div v-if="providerDropdownOpen" class="provider-dropdown">
            <div
              v-for="p in providers"
              :key="p.provider"
              class="provider-option"
              :class="{ active: p.provider === selectedProvider }"
              @click.stop="selectProvider(p.provider)"
            >
              <span class="provider-option-icon">
                <i :class="getProviderIcon(p.provider)"></i>
              </span>
              <span class="provider-option-info">
                <span class="provider-option-name">{{ _i18n("prefs." + p.provider) }}</span>
                <span class="provider-option-model">{{ p.model }}</span>
              </span>
              <i v-if="p.provider === selectedProvider" class="fas fa-check provider-option-check"></i>
            </div>
          </div>
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
          <h3 class="fw-semibold chat-text-color">{{ _i18n('llm.ask_a_question') }}</h3>
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

            <!-- Artifact: rendered above the text answer -->
            <div v-if="msg.artifact" class="chat-artifact-block">
              <!-- Chart artifact -->
              <PieChart
                v-if="msg.artifact.tool === 'chart' && msg.artifact.spec?.type === 'pie'"
                :chart="{
                  title:        msg.artifact.spec.title,
                  unit:         msg.artifact.spec.unit,
                  custom_fetch: () => msg.artifact.spec.data
                }"
                :hideLoading="true"
              />
              <LineChart
                v-if="msg.artifact.tool === 'chart' && msg.artifact.spec?.type === 'line'"
                :chart="{
                  title:        msg.artifact.spec.title,
                  unit:         msg.artifact.spec.unit,
                  custom_fetch: () => msg.artifact.spec.data
                }"
                :hideLoading="true"
              />

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

            <!-- Executed SQL (analyst view) -->
            <template v-if="msg.queries && msg.queries.length">
              <div class="mt-1">
                <button
                  class="btn btn-link p-0 sql-toggle-btn"
                  @click="toggleSqlPanel(idx)"
                >
                  <i :class="openSqlPanels.has(idx) ? 'fas fa-chevron-up' : 'fas fa-chevron-down'" class="me-1" style="font-size:0.65rem;"></i>
                  {{ openSqlPanels.has(idx) ? _i18n('llm.hide_evidence') : _i18n('llm.show_evidence') }}
                </button>
                <div v-if="openSqlPanels.has(idx)" class="sql-panel mt-1">
                  <pre
                    v-for="(q, qi) in msg.queries"
                    :key="qi"
                    class="sql-block hljs"
                    v-html="highlightSql(q)"
                  ></pre>
                </div>
              </div>
            </template>
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
            :disabled="providers.length === 0"
            @keydown.enter.exact.prevent="send"
            @input="autoResize"
          ></textarea>

          <button
            class="btn-send d-flex align-items-center gap-2 flex-shrink-0"
            style="height: 38px;"
            :disabled="!canSendMsg"
            @click="send"
          >
            <span v-if="sending" class="spinner-border spinner-border-sm" role="status"></span>
            <i v-else class="fas fa-paper-plane"></i>
            <span class="d-none d-sm-inline">{{ sending ? currentSendingLabel : _i18n('llm.send') }}</span>
          </button>
        </div>

        <div class="ai-disclaimer small mt-1">
          <i class="fas fa-triangle-exclamation me-1"></i>
          {{_i18n('llm.ai_can_make_mistakes')}}
        </div>
      </div>

    </div><!-- end .chat-main -->
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, nextTick, watch } from "vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";
import MarkdownIt from "markdown-it";
import {v4 as uuidv4} from 'uuid';
import hljs from "highlight.js";
import DOMPurify from "dompurify";
import formatterUtils from "../utilities/formatter-utils.js";
import PieChart from "./charts/pie-chart.vue";
import LineChart from "./charts/line-chart.vue";

// Markdown renderer. Renders both html and markdown
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

function renderMarkdown(content) {
  return DOMPurify.sanitize(md.render(content || ""));
}

function highlightSql(sql) {
  return hljs.highlight(sql || "", { language: "sql" }).value;
}

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: {
    type: Object,
    default: () => ({}),
  },
});

// Tracks which message indices have their SQL panel open
const openSqlPanels = ref(new Set());
function toggleSqlPanel(idx) {
  const s = new Set(openSqlPanels.value);
  s.has(idx) ? s.delete(idx) : s.add(idx);
  openSqlPanels.value = s;
}

// Changing labels
const sending = ref(false)

const sendingLabelIndex = ref(0)

const sendingLabels = [
  "llm.analyzing",
  "llm.investigating",
  "llm.inspecting",
  "llm.correlating" 
]

let sendingInterval = null

const currentSendingLabel = computed(() => {
  return _i18n(sendingLabels[sendingLabelIndex.value])
})

function startSendingAnimation() {
  sendingLabelIndex.value = 0

  sendingInterval = setInterval(() => {
    sendingLabelIndex.value =
      (sendingLabelIndex.value + 1) % sendingLabels.length
  }, 1500)
}

function stopSendingAnimation() {
  if (sendingInterval) {
    clearInterval(sendingInterval)
    sendingInterval = null
  }
}

// State
const providers        = ref([]);
const selectedProvider = ref(null);
const loadingProviders = ref(true);
const chat_UUID        = ref(uuidv4());

// UI messages. Display metadata (timestamps, error flags, stats)
const messages = ref([]);

// API history — pure { role, content } pairs sent to the LLM each turn
const history  = ref([]);

const prompt   = ref("");
const timedOut = ref(false);

const messageList = ref(null);
const promptInput = ref(null);

// Sidebar & history
const chatHistory          = ref([]);
const loadingHistory       = ref(false);
const sidebarOpen          = ref(false);
const activeChatId         = ref(null);

// Rename state
const renamingChatId  = ref(null);
const renameValue     = ref("");
const renameInputRef  = ref(null);

// Provider dropdown
const providerDropdownOpen = ref(false);
const providerSelectorRef  = ref(null);

const settingsUrl = ref(`${http_prefix}/lua/admin/prefs.lua?tab=llm_providers`);

const MAX_HISTORY = 40;
const timeoutSec  = 120;

const canSendMsg = computed(() =>
  !sending.value &&
  prompt.value.trim().length > 0 &&
  selectedProvider.value !== null
);

const selectedProviderInfo = computed(() =>
  providers.value.find(p => p.provider === selectedProvider.value)
);

// Timestamp utils
function nowTime() {
  return new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function formatTimestamp(ts) {
  try {
    return formatterUtils.getFormatter('date')(parseInt(ts));
  } catch (_) {
    return new Date(parseInt(ts) * 1000).toLocaleString();
  }
}

// Return an icon for each LLM provider
function getProviderIcon(provider) {
  if (provider === 'llm_openai') return 'bi bi-openai';
  if (provider === 'llm_anthropic') return 'bi bi-anthropic';
  //return 'fas fa-server';
  return 'fa-solid fa-microchip';
}

// Add messagem when it arrives or user writes a new message
function pushMessage(role, content, error = false, stats = null, artifact = null, queries = null) {
  messages.value.push({ role, content, time: nowTime(), error, stats, artifact, queries });
  nextTick(scrollBottom);
}

// scroll view to bottom
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

// select provider in the dropdown
function selectProvider(provider) {
  if (!sending.value) {
    selectedProvider.value = provider;
    providerDropdownOpen.value = false;
  }
}

function onDocumentClick(e) {
  if (providerSelectorRef.value && !providerSelectorRef.value.contains(e.target)) {
    providerDropdownOpen.value = false;
  }
}

function clearChat() {
  messages.value = [];
  history.value  = [];
  activeChatId.value = null;
  chat_UUID.value = uuidv4();
  ntopng_url_manager.set_key_to_url("chatId", null);
}

function startNewChat() {
  const newId = uuidv4();
  chat_UUID.value    = newId;
  activeChatId.value = newId;
  messages.value = [];
  history.value  = [];

  // Add chat in sidebar, then rename to current title after first user message
  chatHistory.value.unshift({
    chat_id:  newId,
    title:    "New Chat",
    provider: selectedProvider.value ?? "",
    isNew:    true,
  });
}

// Rename sidebar chat element
function startRenameChat(chat) {
  renamingChatId.value = chat.chat_id;
  renameValue.value    = chat.title;
  nextTick(() => renameInputRef.value?.focus());
}

function cancelRename() {
  renamingChatId.value = null;
  renameValue.value    = "";
}

async function confirmRename() {
  const id    = renamingChatId.value;
  const title = renameValue.value.trim();
  if (!id || !title) { cancelRename(); return; }

  // Optimistic update
  const entry = chatHistory.value.find(c => c.chat_id === id);
  if (entry) entry.title = title;

  cancelRename();
  await renameChatApi(id, title);
}

// Rename or delete chat from sidebar
async function renameChatApi(chatId, newTitle) {
  try {
    const url  = `${http_prefix}/lua/pro/rest/v2/post/llm/rename_chat.lua`;
    await ntopng_utility.http_request(url, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ chatId, title: newTitle, csrf: props.context.csrf }),
    }, true);
  } catch (err) {
    console.error("[llm] renameChatApi failed:", err);
  }
}

async function deleteChat(chatId) {
  // Optimistic removal from sidebar so the UI feels instant
  chatHistory.value = chatHistory.value.filter(c => c.chat_id !== chatId);
  clearChat();

  try {
    const url  = `${http_prefix}/lua/pro/rest/v2/post/llm/delete_chat.lua`;
    await ntopng_utility.http_request(url, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ chatId, csrf: props.context.csrf }),
    }, true);
  } catch (err) {
    console.error("[llm] deleteChat failed:", err);
  }
}

// Update sidebar title after first user message 
function updateSidebarTitle(text) {
  const entry = chatHistory.value.find(c => c.chat_id === activeChatId.value);

  if (entry) {
    entry.title = text.length > 48 ? text.slice(0, 45) + "…" : text;
    entry.isNew = false;
  }
}

// Load providers added to prefs
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

// Get all Chats in History
async function loadChatHistory() {
  loadingHistory.value = true;

  try {
    const url  = `${http_prefix}/lua/pro/rest/v2/get/llm/chats_list.lua`;
  
    const list = await ntopng_utility.http_request(url) ?? [];
    chatHistory.value = Array.isArray(list) ? list : [];
  } catch (err) {
    console.error("llm chat history fetch failed:", err);
    chatHistory.value = [];
  } finally {
    loadingHistory.value = false;
  }
}

// Load a specific chat
async function loadChat(chatId) {
  try {
    const url  = `${http_prefix}/lua/pro/rest/v2/get/llm/chat.lua?chatId=${encodeURIComponent(chatId)}`;
    const msgs = await ntopng_utility.http_request(url) ?? [];

    if (!Array.isArray(msgs) || msgs.length === 0) return;

    // Set provider from first message returned, so that the provider icon can be shown
    const provider = msgs[0]?.provider;
    if (provider && providers.value.find(p => p.provider === provider)) {
      selectedProvider.value = provider;
    }

    chat_UUID.value    = chatId;
    activeChatId.value = chatId;

    // Clear and repopulate
    messages.value = [];
    history.value  = [];

    // parse content from each message
    for (const msg of msgs) {
      const role    = parseInt(msg.message_role) === 1 ? 'user' : 'assistant';
      const content = msg.message_content;
      const time = formatTimestamp(msg.created_at);
      
      const stats   = role === 'assistant' ? {
        completion_time_s:            msg.completion_time_sec !== '0' ? msg.completion_time_sec : null,
        generation_tokens_per_second: msg.tokens_per_second   !== '0' ? msg.tokens_per_second   : null,
      } : null;

      // artifact_json and evidence_json are decoded to objects by the backend
      let artifact = (role === 'assistant' && msg.artifact_json && typeof msg.artifact_json === 'object')
        ? msg.artifact_json : null;

      let queries = null;
      if (role === 'assistant' && msg.evidence_json && typeof msg.evidence_json === 'object') {
        const sqls = (msg.evidence_json.tools || []).map(t => t.sql).filter(Boolean);
        if (sqls.length) queries = sqls;
      }

      messages.value.push({ role, content, time, error: false, stats, artifact, queries });
      history.value.push({ role, content });
    }

    ntopng_url_manager.set_key_to_url("chatId", chatId);
    nextTick(scrollBottom);
  } catch (err) {
    console.error("llm load chat failed:", err);
  }
}

// Generate response
async function send() {
  if (!canSendMsg.value) return;

  const text = prompt.value.trim();
  prompt.value = "";
  resetTextarea();
  timedOut.value = false;

  // If this is the first message in the chat, rename the sidebar entry
  const isFirstMessage = messages.value.length === 0;

  // Show user icon immediately
  pushMessage("user", text);

  if (isFirstMessage) updateSidebarTitle(text);

  // Append user turn to history
  history.value.push({ role: "user", content: text });

  // Trim history if it exceeds the max cap, always drop oldest user+assistant pair
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
    // completion endpoint to start the response process
    const csrf = props.context.csrf;
    const url  = `${http_prefix}/lua/pro/rest/v2/post/llm/completion.lua`;

    const body = JSON.stringify({
      provider: selectedProvider.value,
      messages: history.value,
      stream: false,
      chatId: chat_UUID.value,
      sequence: history.value.length,
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

    // Append assistant message to history so next request includes it
    history.value.push({ role: "assistant", content: reply });

    pushMessage("assistant", reply, false, rsp?.stats ?? null, rsp?.artifact ?? null, rsp?.queries ?? null);

  } catch (err) {
    clearTimeout(timer);

    // Roll back the user message from history on failure
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

// On component mount load providers and chat history
onMounted(() => {
  loadProviders();
  loadChatHistory();
  document.addEventListener('click', onDocumentClick);
});

onBeforeUnmount(() => {
  document.removeEventListener('click', onDocumentClick);
});

watch(sending, (val) => {
  if (val) startSendingAnimation()
  else stopSendingAnimation()
})
</script>

<style>
@import "highlight.js/styles/github.css";

.hljs { background: transparent !important; }

.llm-chat-page {
  --chat-header-bg:          var(--navbar-tab-container-bg, #f1f3f5);
  --chat-footer-bg:          var(--navbar-tab-container-bg, #f1f3f5);
  --chat-border:             rgba(0, 0, 0, 0.10);
  --chat-text:               var(--ntop-text-color, #111111);
  --chat-muted:              var(--ntop-muted-text-color, #37474F);
  --chat-icon:               var(--icon-color, #363943);

  /* sidebar */
  --sidebar-bg:              #e8eaed;
  --sidebar-header-border:   rgba(0, 0, 0, 0.08);
  --sidebar-item-hover:      rgba(0, 0, 0, 0.06);
  --sidebar-item-active:     rgba(255, 143, 0, 0.12);
  --sidebar-item-active-text: var(--ntop-orange-dark, #C56000);
  --sidebar-item-active-border: var(--ntop-orange, #FF8F00);

  /* provider pill */
  --provider-pill-bg:        rgba(255, 255, 255, 0.75);
  --provider-pill-border:    rgba(0, 0, 0, 0.12);
  --provider-pill-hover-border: var(--ntop-orange, #FF8F00);
  --provider-name-color:     var(--ntop-text-color, #111111);
  --provider-model-color:    var(--ntop-muted-text-color, #37474F);
  --provider-dropdown-bg:    #ffffff;
  --provider-option-hover:   rgba(255, 143, 0, 0.07);
  --provider-option-active:  rgba(255, 143, 0, 0.12);
  --provider-check-color:    var(--ntop-orange, #FF8F00);

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

:root[data-theme='dark'] .llm-chat-page {
  --chat-border:             rgba(255, 255, 255, 0.08);

  --sidebar-bg:              #111c24;
  --sidebar-header-border:   rgba(255, 255, 255, 0.07);
  --sidebar-item-hover:      rgba(255, 255, 255, 0.06);
  --sidebar-item-active:     rgba(255, 143, 0, 0.15);
  --sidebar-item-active-text: var(--ntop-orange-light, #FFC046);
  --sidebar-item-active-border: var(--ntop-orange, #FF8F00);

  --provider-pill-bg:        rgba(255, 255, 255, 0.06);
  --provider-pill-border:    rgba(255, 255, 255, 0.12);
  --provider-name-color:     var(--ntop-text-color, #E2E2E2);
  --provider-model-color:    var(--ntop-muted-text-color, #A7A6A6);
  --provider-dropdown-bg:    #1a2a35;
  --provider-option-hover:   rgba(255, 255, 255, 0.06);
  --provider-option-active:  rgba(255, 143, 0, 0.14);

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

/* Dark-mode hljs overrides */
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

/* Markdown body */
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
/* Layout */
.llm-chat-page {
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid var(--chat-border);
}

/* Sidebar */
.chat-sidebar {
  width: 0;
  overflow: hidden;
  background: var(--sidebar-bg);
  border-right: 1px solid var(--chat-border);
  transition: width 0.22s cubic-bezier(0.4, 0, 0.2, 1);
}
.chat-sidebar.open {
  width: 240px;
}
.chat-sidebar-inner {
  width: 240px;
}

.sidebar-header {
  border-bottom: 1px solid var(--sidebar-header-border);
}
.sidebar-title {
  font-size: 0.68rem;
  letter-spacing: 0.06em;
  color: var(--chat-muted);
}

.btn-icon-subtle {
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  border-radius: 6px;
  color: var(--chat-muted);
  font-size: 0.75rem;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
  padding: 0;
}
.btn-icon-subtle:hover {
  background: var(--sidebar-item-hover);
  color: var(--chat-text);
}

.btn-new-chat {
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: 1px dashed var(--chat-border);
  border-radius: 8px;
  color: var(--chat-muted);
  font-size: 0.78rem;
  padding: 0.35rem 0.5rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s, color 0.15s;
  white-space: nowrap;
}
.btn-new-chat:hover {
  background: var(--sidebar-item-hover);
  border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
}


.chat-history-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.45rem 0.6rem;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.12s;
  margin-bottom: 2px;
  border-left: 2px solid transparent;
}
.chat-history-item:hover {
  background: var(--sidebar-item-hover);
}
.chat-history-item.active {
  background: var(--sidebar-item-active);
  border-left-color: var(--sidebar-item-active-border);
}
.chat-history-item.active .chat-history-title,
.chat-history-item.active .chat-history-icon {
  color: var(--sidebar-item-active-text);
}

.chat-history-icon {
  font-size: 0.8rem;
  color: var(--chat-muted);
  width: 16px;
  text-align: center;
  flex-shrink: 0;
}
.chat-history-title {
  font-size: 0.78rem;
  color: var(--chat-text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  line-height: 1.35;
  flex-grow: 1;
  min-width: 0;
}

/* Action buttons, hidden until hover / active */
.chat-history-actions {
  display: flex;
  gap: 2px;
  opacity: 0;
  transition: opacity 0.12s;
  pointer-events: none;
}
.chat-history-item:hover .chat-history-actions,
.chat-history-item.active .chat-history-actions {
  opacity: 1;
  pointer-events: auto;
}

.chat-item-action-btn {
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  border-radius: 4px;
  font-size: 0.62rem;
  color: var(--chat-muted);
  cursor: pointer;
  padding: 0;
  transition: background 0.12s, color 0.12s;
}
.chat-item-action-btn:hover {
  background: var(--sidebar-item-hover);
  color: var(--chat-text);
}
.chat-item-delete-btn:hover {
  background: rgba(220, 53, 69, 0.10);
  color: #dc3545;
}

/* Rename popup */
.rename-overlay {
  position: absolute;
  inset: 0;
  z-index: 200;
  background: rgba(0, 0, 0, 0.18);
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: inherit;
}
.rename-popup {
  background: var(--provider-dropdown-bg);
  border: 1px solid var(--chat-border);
  border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.15);
  width: 200px;
  animation: dropdownFadeIn 0.12s ease-out;
}
.rename-popup-label {
  color: var(--chat-muted);
  font-size: 0.68rem;
}
.rename-input {
  background-color: var(--input-bg) !important;
  border-color: var(--input-border) !important;
  color: var(--input-text) !important;
  font-size: 0.8rem;
}
.rename-input:focus {
  border-color: var(--input-focus-border) !important;
  box-shadow: 0 0 0 2px var(--input-focus-shadow) !important;
}
.btn-rename-confirm {
  font-size: 0.75rem;
  background: var(--ntop-orange, #FF8F00);
  color: #fff;
  border: none;
  border-radius: 6px;
  padding: 0.25rem 0.5rem;
  cursor: pointer;
  transition: background 0.15s;
}
.btn-rename-confirm:hover { background: var(--ntop-orange-dark, #C56000); }
.btn-rename-cancel {
  font-size: 0.75rem;
  background: transparent;
  color: var(--chat-muted);
  border: 1px solid var(--chat-border);
  border-radius: 6px;
  padding: 0.25rem 0.5rem;
  cursor: pointer;
}
.btn-rename-cancel:hover { background: var(--sidebar-item-hover); }

/* Chat main  */
.chat-header {
  background: var(--chat-header-bg);
  border-bottom: 1px solid var(--chat-border);
}

/* Sidebar toggle button in header */
a.sidebar-toggle-btn { text-decoration: none; }
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
  transition: background 0.15s, border-color 0.15s, color 0.15s;
  padding: 0;
  flex-shrink: 0;
}
.sidebar-toggle-btn:hover {
  background: var(--provider-pill-bg);
  border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
}

/* Provider selector */
.provider-selector-wrapper {
  position: relative;
}

.provider-pill {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.28rem 0.65rem 0.28rem 0.5rem;
  border-radius: 10px;
  background: var(--provider-pill-bg);
  border: 1px solid var(--provider-pill-border);
  cursor: pointer;
  user-select: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  min-width: 0;
}
.provider-pill:hover,
.provider-pill.open {
  border-color: var(--provider-pill-hover-border);
  box-shadow: 0 0 0 3px var(--input-focus-shadow);
}
.provider-pill.disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.provider-pill-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 6px;
  background: rgba(255, 143, 0, 0.12);
  color: var(--ntop-orange, #FF8F00);
  font-size: 0.72rem;
  flex-shrink: 0;
}

.provider-pill-info {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
  min-width: 0;
}
.provider-pill-name {
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--provider-name-color);
  white-space: nowrap;
}
.provider-pill-model {
  font-size: 0.65rem;
  color: var(--provider-model-color);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 160px;
}

.provider-pill-chevron {
  font-size: 0.6rem;
  color: var(--chat-muted);
  margin-left: 0.1rem;
  transition: transform 0.15s;
  flex-shrink: 0;
}
.provider-pill.open .provider-pill-chevron {
  transform: rotate(180deg);
}

/* Dropdown */
.provider-dropdown {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  min-width: 220px;
  background: var(--provider-dropdown-bg);
  border: 1px solid var(--chat-border);
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.14);
  z-index: 1050;
  overflow: hidden;
  padding: 4px;
  animation: dropdownFadeIn 0.12s ease-out;
}

@keyframes dropdownFadeIn {
  from { opacity: 0; transform: translateY(-4px); }
  to   { opacity: 1; transform: translateY(0); }
}

.provider-option {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  padding: 0.45rem 0.6rem;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.1s;
}
.provider-option:hover {
  background: var(--provider-option-hover);
}
.provider-option.active {
  background: var(--provider-option-active);
}

.provider-option-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: 7px;
  background: rgba(255, 143, 0, 0.10);
  color: var(--ntop-orange, #FF8F00);
  font-size: 0.75rem;
  flex-shrink: 0;
}

.provider-option-info {
  display: flex;
  flex-direction: column;
  line-height: 1.25;
  flex-grow: 1;
  min-width: 0;
}
.provider-option-name {
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--provider-name-color);
}
.provider-option-model {
  font-size: 0.68rem;
  color: var(--provider-model-color);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.provider-option-check {
  font-size: 0.7rem;
  color: var(--provider-check-color);
  flex-shrink: 0;
}

/* History badge */
.history-badge {
  font-size: 0.68rem;
  color: var(--history-badge-text);
  background: var(--history-badge-bg);
  padding: 0.18rem 0.5rem;
  border-radius: 20px;
  font-weight: 500;
  white-space: nowrap;
}

/* Clear button */
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

/* Message area */
.chat-messages { background: transparent; }

/* Empty state */
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

/* Avatars */
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

/* Chat bubbles */
.chat-bubble {
  padding: 0.55rem 0.85rem;
  border-radius: 16px;
  animation: fadeUp .18s ease-out;
}

/* Executed SQL analyst panel */
.sql-toggle-btn {
  font-size: 0.7rem;
  color: color-mix(in srgb, currentColor 55%, transparent);
  text-decoration: none;
}
.sql-toggle-btn:hover { color: currentColor; }

.sql-panel {
  border-top: 1px solid var(--chat-border);
  padding-top: 0.4rem;
}

.sql-block {
  margin: 0 0 0.4rem;
  padding: 0.45rem 0.65rem;
  border-radius: 6px;
  background: color-mix(in srgb, currentColor 6%, transparent);
  font-size: 0.72rem;
  line-height: 1.45;
  white-space: pre-wrap;
  word-break: break-all;
  color: inherit;
}
.sql-block:last-child { margin-bottom: 0; }

/* Artifact block (chart, ping, etc.) inside assistant bubble */
.chat-artifact-block {
  margin-top: 0.6rem;
  border-top: 1px solid var(--chat-border);
  padding-top: 0.6rem;
  /* fixed height so PieChart's SVG has a measurable container */
  height: 220px;
  width: 100%;
  min-width: 0;
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

/* Text helpers */
.chat-text-color { color: var(--chat-text); }
.chat-muted-text { color: var(--chat-muted); }

/* Footer / input */
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

/* Send button */
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

/* AI disclaimer */
.ai-disclaimer {
  color: var(--hint-color);
  font-size: 0.68rem;
  opacity: 0.65;
}

/* Timeout alert */
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

/* Typing dots */
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

/* Animations */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(6px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* Scrollbar */
.overflow-auto::-webkit-scrollbar       { width: 5px; }
.overflow-auto::-webkit-scrollbar-track { background: transparent; }
.overflow-auto::-webkit-scrollbar-thumb {
  background: var(--scrollbar-thumb);
  border-radius: 4px;
}
</style>
