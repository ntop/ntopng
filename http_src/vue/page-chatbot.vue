<template>
  <div class="llm-chat-page d-flex" style="height: 90vh; min-height: 500px;">

    <!-- Collapsible Chat History Sidebar -->
    <div class="chat-sidebar flex-shrink-0" :class="{ open: sidebarOpen }">
      <div class="chat-sidebar-inner d-flex flex-column h-100">

        <div class="sidebar-header d-flex align-items-center justify-content-between px-3 py-2 flex-shrink-0">
          <span class="sidebar-title fw-semibold small text-uppercase">
            <i class="fas fa-history me-1 opacity-75"></i>
            {{ _i18n("llm.history") }}
          </span>
          <button class="btn-icon-subtle" @click="sidebarOpen = false" title="Close">
            <i class="fas fa-times"></i>
          </button>
        </div>

        <div class="px-3 pb-2 pt-1 flex-shrink-0">
          <button class="btn-new-chat w-100" @click="startNewChat">
            <i class="fas fa-plus me-2"></i>{{ _i18n("llm.new_chat") }}
          </button>
        </div>

        <div class="px-2 pb-2 flex-shrink-0">
          <div class="history-filter-row d-flex gap-1 flex-wrap">
            <button v-for="f in HISTORY_FILTERS" :key="f.value" class="history-filter-btn"
              :class="{ active: historyFilter === f.value }" @click="setHistoryFilter(f.value)" :title="f.label">
              <i :class="f.icon + ' me-1'"></i>{{ f.label }}
            </button>
          </div>
        </div>

        <div class="sidebar-chat-list flex-grow-1 overflow-auto px-2 pb-2" style="position: relative;">
          <div v-if="loadingHistory"
            class="d-flex align-items-center justify-content-center py-4 chat-muted-text small gap-2">
            <span class="spinner-border spinner-border-sm"></span>{{ _i18n("loading") }}
          </div>
          <div v-else-if="chatHistory.length === 0" class="text-center py-4 chat-muted-text small px-2">
            <i class="fas fa-comment-slash d-block mb-2" style="font-size:1.4rem; opacity:0.3;"></i>
            {{ _i18n("llm.no_conversations_yet") }}
          </div>
          <div v-for="chat in chatHistory" :key="chat.chat_id" class="chat-history-item"
            :class="{ active: activeChatId === chat.chat_id }" @click="chat.isNew ? null : loadChat(chat.chat_id)"
            :title="chat.title">
            <span class="chat-history-icon flex-shrink-0"><i :class="getProviderIcon(chat.provider)"></i></span>
            <span class="chat-history-title">{{ chat.title }}</span>
            <span class="chat-history-actions flex-shrink-0 ms-auto" @click.stop>
              <button class="chat-item-action-btn" title="Rename" @click.stop="startRenameChat(chat)">
                <i class="fas fa-pen"></i></button>
              <button class="chat-item-action-btn chat-item-delete-btn" title="Delete"
                @click.stop="deleteChat(chat.chat_id)"><i class="fas fa-trash-alt"></i></button>
            </span>
          </div>

          <div v-if="renamingChatId" class="rename-overlay" @click.self="cancelRename">
            <div class="rename-popup px-3 py-2">
              <div class="rename-popup-label small fw-semibold mb-1">{{ _i18n("llm.rename_chat") }}</div>
              <input ref="renameInputRef" v-model="renameValue" class="rename-input form-control form-control-sm"
                @keydown.enter.prevent="confirmRename" @keydown.esc.prevent="cancelRename" />
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
    <div class="chat-main d-flex flex-column flex-grow-1" style="min-width: 0; position: relative;">

      <!-- Header bar -->
      <div class="chat-header d-flex align-items-center gap-2 px-3 py-2 flex-shrink-0">

        <button class="sidebar-toggle-btn flex-shrink-0" data-bs-toggle="tooltip" data-bs-placement="top"
          :title="sidebarOpen ? 'Close history' : 'Chat history'" @click="sidebarOpen = !sidebarOpen">
          <i :class="sidebarOpen ? 'fas fa-chevron-left' : 'fas fa-history'"></i>
        </button>

        <a class="sidebar-toggle-btn flex-shrink-0" data-bs-toggle="tooltip" data-bs-placement="top"
          title="LLM Settings" :href="settingsUrl"><i class="fas fa-gear"></i></a>

        <a class="sidebar-toggle-btn flex-shrink-0" data-bs-toggle="tooltip" data-bs-placement="top"
          title="LLM Usage Stats" :href="statsUrl"><i class="fas fa-chart-bar"></i></a>

        <button class="sidebar-toggle-btn flex-shrink-0" data-bs-toggle="tooltip" data-bs-placement="top"
          :title="conciseMode ? 'Concise mode on' : 'Concise mode off'" :class="{ active: conciseMode }"
          @click="conciseMode = !conciseMode">
          <i class="bi bi-fire"></i>
        </button>

        <button class="sidebar-toggle-btn flex-shrink-0" data-bs-toggle="tooltip" data-bs-placement="top"
          :title="debugStatus || 'Send chat debug dump to server'" :class="{ active: !!debugStatus }"
          :disabled="messages.length === 0" @click="sendDebug">
          <i class="fas fa-bug"></i>
        </button>

        <!-- Provider selector -->
        <LlmProviderSelector :providers="providers" :selected_provider="selectedProvider" :loading="loadingProviders"
          :disabled="sending" @select="selectProvider" />
        <button v-if="activeChatId" class="sidebar-toggle-btn ms-auto flex-shrink-0" title="Share"
          @click="shareConversation">
          <i class="fas fa-share-alt"></i>
        </button>
      </div>


      <!-- Message list -->
      <div ref="messageList" class="chat-messages flex-grow-1 overflow-auto d-flex flex-column">

        <!-- Empty state with preset questions -->
        <div v-if="messages.length === 0" class="m-auto text-center py-5 px-3">
          <div class="empty-state-icon mx-auto mb-4"><i class="fas fa-comments"></i></div>
          <h3 class="fw-semibold chat-text-color mb-4">{{ _i18n('llm.ask_a_question') }}</h3>
          <div class="preset-grid">
            <button v-for="q in PRESET_QUESTIONS" :key="q" class="preset-chip"
              :disabled="sending || providers.length === 0" @click="sendPreset(q)">
              {{ q }}
            </button>
          </div>
        </div>

        <!-- Messages — centred column that grows to fill available width -->
        <div v-else class="messages-inner px-3 py-4 d-flex flex-column gap-3">
          <div v-for="(msg, idx) in messages" :key="idx" class="d-flex"
            :class="msg.role === 'user' ? 'justify-content-end' : 'justify-content-start'">

            <div v-if="msg.role === 'assistant'" class="flex-shrink-0 me-2 mt-1">
              <span class="chat-avatar assistant-avatar"><i class="fas fa-robot"></i></span>
            </div>

            <div class="chat-bubble"
              :class="msg.role === 'user' ? 'user-bubble' : msg.error ? 'error-bubble' : 'assistant-bubble'">
              <div v-if="msg.error" class="d-flex align-items-center gap-2 mb-1 small fw-semibold error-label">
                <i class="fas fa-exclamation-circle"></i>{{ _i18n('llm.error_label') }}
              </div>

              <div v-if="msg.artifact" class="chat-artifact-block">
                <PieChart v-if="msg.artifact.tool === 'chart' && msg.artifact.spec?.type === 'pie'" :chart="{
                  title: msg.artifact.spec.title, unit: msg.artifact.spec.unit,
                  custom_fetch: () => msg.artifact.spec.data
                }" :hideLoading="true" />
                <LineChart v-if="msg.artifact.tool === 'chart' && msg.artifact.spec?.type === 'line'" :chart="{
                  title: msg.artifact.spec.title, unit: msg.artifact.spec.unit,
                  custom_fetch: () => msg.artifact.spec.data
                }" :hideLoading="true" />
              </div>

              <div v-if="msg.role === 'user'" class="chat-content"
                style="white-space:pre-wrap;word-break:break-word;font-size:0.9rem;line-height:1.55;">{{ msg.content }}
              </div>
              <div v-else class="chat-content markdown-body"
                style="word-break:break-word;font-size:0.9rem;line-height:1.55;"
                v-html="renderMarkdown(stripNextSteps(msg.content))"></div>

              <template v-if="msg.role === 'assistant' && parseNextSteps(msg.content).length">
                <div class="next-steps-row mt-2">
                  <span class="next-steps-label">{{ _i18n('llm.next_steps') }}</span>
                  <button v-for="(step, si) in parseNextSteps(msg.content)" :key="si" class="next-step-chip"
                    :disabled="sending" :title="step.full" @click="fillNextStep(step.full)">
                    <i class="fas fa-arrow-right me-1 flex-shrink-0"></i>
                    <span class="next-step-title">{{ step.label }}</span>
                    <span v-if="step.desc" class="next-step-desc">{{ step.desc }}</span>
                  </button>
                </div>
              </template>

              <div class="mt-1 d-flex align-items-center gap-2 flex-wrap"
                :class="msg.role === 'user' ? 'bubble-meta-user' : 'bubble-meta-assistant'" style="font-size:0.7rem;">
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
                    <i :class="openSqlPanels.has(idx) ? 'fas fa-chevron-up' : 'fas fa-chevron-down'" class="me-1"
                      style="font-size:0.65rem;"></i>
                    {{ openSqlPanels.has(idx) ? _i18n('llm.hide_evidence') : _i18n('llm.show_evidence') }}
                  </button>
                  <div v-if="openSqlPanels.has(idx)" class="sql-panel mt-1">
                    <template v-for="(q, qi) in msg.queries" :key="qi">
                      <div v-if="typeof q === 'object'" class="evidence-entry">
                        <div class="evidence-tool-badge">
                          <i class="fas fa-search me-1"></i>
                          {{ _i18n('llm.tool_' + q.tool) }}
                        </div>
                        <div v-if="q.thinking" class="evidence-thinking">{{ q.thinking }}</div>
                        <pre v-if="q.sql" class="sql-block hljs" v-html="highlightSql(q.sql)"></pre>
                      </div>
                      <pre v-else class="sql-block hljs" v-html="highlightSql(q)"></pre>
                    </template>
                  </div>
                </div>
              </template>
            </div>

            <div v-if="msg.role === 'user'" class="flex-shrink-0 ms-2 mt-1">
              <span class="chat-avatar user-avatar"><i class="fas fa-user"></i></span>
            </div>
          </div>

          <!-- Typing indicator / live steps -->
          <div v-if="sending" class="d-flex justify-content-start">
            <span class="chat-avatar assistant-avatar me-2 mt-1 flex-shrink-0"><i class="fas fa-robot"></i></span>
            <div class="assistant-bubble chat-bubble" style="padding:0.4rem 0.75rem;min-width:160px;">

              <!-- Toggle row: triangle + "Thinking" label + dots when collapsed -->
              <div class="d-flex align-items-center gap-2">
                <button class="btn btn-link p-0 sql-toggle-btn" style="font-size:0.75rem;"
                  @click.stop="stepsExpanded = !stepsExpanded">
                  <i :class="stepsExpanded ? 'fas fa-chevron-down' : 'fas fa-chevron-right'" class="me-1"
                    style="font-size:0.6rem;"></i>{{ _i18n('llm.thinking') }}
                </button>
                <!-- Dots shown inline only when collapsed -->
                <span v-if="!stepsExpanded" class="d-flex align-items-center gap-1">
                  <span class="typing-dot"></span><span class="typing-dot"></span><span class="typing-dot"></span>
                </span>
              </div>

              <!-- Expanded: live steps list -->
              <div v-if="stepsExpanded" class="mt-1">
                <div v-for="(step, si) in liveSteps" :key="si" class="py-1"
                  :class="si < liveSteps.length - 1 ? 'opacity-40' : ''"
                  style="display:grid;grid-template-columns:1.4rem 0.9rem 1fr;gap:0 0.4rem;align-items:baseline;">
                  <span class="fw-bold" style="font-size:0.7rem;text-align:right;color:#FF7500;">{{ si + 1 }}.</span>
                  <span style="display:flex;align-items:center;justify-content:center;">
                    <span v-if="si === liveSteps.length - 1" class="spinner-border"
                      style="width:0.65rem;height:0.65rem;border-width:2px;color:#FF7500;flex-shrink:0;"></span>
                    <i v-else class="fas fa-check text-success" style="font-size:0.6rem;"></i>
                  </span>
                  <span style="font-size:0.8rem;line-height:1.4;word-break:break-word;">
                    <span class="fw-semibold">{{ _i18n('llm.tool_' + step.tool) }}</span>
                    <span v-if="typedThinking[si]" class="text-muted ms-1">— {{ typedThinking[si] }}</span>
                  </span>
                </div>
              </div>

            </div>
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
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from "vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";
import formatterUtils from "../utilities/formatter-utils.js";
import PieChart from "./charts/pie-chart.vue";
import LineChart from "./charts/line-chart.vue";
import { default as LlmProviderSelector } from "./llm-provider-selector.vue";
import {
  useLlmChat, renderMarkdown, highlightSql, getProviderIcon, PRESET_QUESTIONS
} from "./composables/useLlmChat.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: { type: Object, default: () => ({}) },
});

const {
  messageList, promptInput,
  messages, history, sending, timedOut, prompt, conciseMode, chat_UUID,
  providers, selectedProvider, loadingProviders,
  openSqlPanels, openStepsPanels, debugStatus, liveSteps,
  currentSendingLabel, canSendMsg,
  loadProviders, selectProvider, clearChat, send, sendPreset, sendDebug,
  scrollBottom, scrollToLastMessage, autoResize, toggleSqlPanel, toggleStepsPanel,
  setOnFirstMessage,
} = useLlmChat(props);

// Typewriter effect for live step thinking text.
// typedThinking[i] holds the currently-revealed portion of liveSteps[i].thinking.
const typedThinking = ref([]);
let typewriterTimer = null;

watch(liveSteps, (steps) => {
  const idx = steps.length - 1;
  if (idx < 0) { typedThinking.value = []; return; }

  // Ensure the array is long enough
  while (typedThinking.value.length <= idx) typedThinking.value.push("");

  // Mark all previous steps as fully revealed
  for (let i = 0; i < idx; i++) {
    typedThinking.value[i] = steps[i].thinking || "";
  }

  // Animate the new (last) step
  clearInterval(typewriterTimer);
  const full = steps[idx].thinking || "";
  typedThinking.value[idx] = "";
  let pos = 0;
  typewriterTimer = setInterval(() => {
    pos += 3; // chars per tick — fast enough to feel live
    typedThinking.value = [
      ...typedThinking.value.slice(0, idx),
      full.slice(0, pos),
    ];
    if (pos >= full.length) clearInterval(typewriterTimer);
  }, 16);
}, { deep: false });

const stepsExpanded = ref(false);

// Collapse the thinking panel at the start of every new request
watch(sending, (val) => {
  if (val) {
    stepsExpanded.value = false;
    typedThinking.value = [];
  }
});

// Page state (sidebar, history, rename)
const settingsUrl = ref(`${http_prefix}/lua/admin/prefs.lua?tab=llm_providers`);
const statsUrl = ref(`${http_prefix}/lua/pro/ai_stats.lua`);

const HISTORY_FILTERS = [
  { value: "all", label: _i18n("all"), icon: "fas fa-list" },
  { value: "live_flows", label: _i18n("llm.live_flows"), icon: "fas fa-bolt" },
  { value: "hist_flow_details", label: _i18n("llm.historical"), icon: "fas fa-database" },
  { value: "nanalyst", label: _i18n("llm.nAnalyst"), icon: "fas fa-robot" },
];

const chatHistory = ref([]);
const loadingHistory = ref(false);
const sidebarOpen = ref(false);
const historyFilter = ref("all");
const activeChatId = ref(null);


const renamingChatId = ref(null);
const renameValue = ref("");
const renameInputRef = ref(null);

function formatTimestamp(ts) {
  try {
    return formatterUtils.getFormatter("date")(parseInt(ts));
  } catch (_) {
    return new Date(parseInt(ts) * 1000).toLocaleString();
  }
}

function shareConversation() {
  const url = window.location.href;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(url);
    ToastUtils.showToast({ id: 'chat-link-copied-' + Date.now(), level: 'success', title: _i18n('success'), body: _i18n('llm.chatid_copied_to_clipboard'), delay: 60 });
  } else {
    // Fallback for non-HTTPS contexts
    const el = document.createElement("textarea");
    el.value = url;
    el.style.position = "fixed";
    el.style.opacity = "0";
    document.body.appendChild(el);
    el.select();
    document.execCommand("copy");
    document.body.removeChild(el);
    ToastUtils.showToast({ id: 'chat-link-copied-' + Date.now(), level: 'success', title: _i18n('success'), body: _i18n('llm.chatid_copied_to_clipboard'), delay: 60 });
  }
}

// Returns content with the ### Next Steps block removed for markdown rendering
function stripNextSteps(content) {
  if (!content) return content;
  return content.replace(/\n?###\s*Next Steps\s*\n[\s\S]*?(?=\n###|\n##|$)/i, '').trimEnd();
}

// Returns [{label, desc, full}] — label is the bold title, desc the rest, full goes into the input
function parseNextSteps(content) {
  if (!content) return [];
  const match = content.match(/###\s*Next Steps\s*\n([\s\S]*?)(?=\n###|\n##|$)/i);
  if (!match) return [];
  const steps = [];
  for (const line of match[1].split('\n')) {
    const m = line.match(/^\s*\d+\.\s+(.+)/);
    if (m) {
      const raw = m[1].trim();
      const boldMatch = raw.match(/^\*\*([^*]+)\*\*\s*[—–-]?\s*(.*)/);
      if (boldMatch) {
        const label = boldMatch[1].trim();
        const desc = boldMatch[2].replace(/\*\*([^*]+)\*\*/g, '$1').trim();
        const full = raw.replace(/\*\*([^*]+)\*\*/g, '$1').trim();
        steps.push({ label, desc, full });
      } else {
        const full = raw.replace(/\*\*([^*]+)\*\*/g, '$1').trim();
        const parts = full.split(/[—–-]/);
        steps.push({ label: parts[0].trim(), desc: parts.slice(1).join('—').trim(), full });
      }
    }
  }
  return steps;
}

function fillNextStep(text) {
  prompt.value = text;
  nextTick(() => promptInput.value?.focus());
}

setOnFirstMessage((text) => {
  const title = text.length > 48 ? text.slice(0, 45) + "…" : text;
  const entry = chatHistory.value.find(c => c.chat_id === chat_UUID.value);
  if (entry) {
    entry.title = title;
    entry.isNew = false;
  } else {
    // User started chatting without clicking "New Chat" — insert the entry now
    chatHistory.value.unshift({
      chat_id: chat_UUID.value,
      title,
      provider: selectedProvider.value ?? "",
      isNew: false,
    });
    activeChatId.value = chat_UUID.value;
  }
});

function setHistoryFilter(value) {
  historyFilter.value = value;
  loadChatHistory();
}

// Load chat history
async function loadChatHistory() {
  loadingHistory.value = true;
  try {
    const filter = historyFilter.value !== "all" ? `?page_filter=${encodeURIComponent(historyFilter.value)}` : "";
    const url = `${http_prefix}/lua/pro/rest/v2/get/llm/chats_list.lua${filter}`;
    const list = (await ntopng_utility.http_request(url)) ?? [];
    chatHistory.value = Array.isArray(list) ? list : [];
  } catch (err) {
    console.error("llm chat history fetch failed:", err);
    chatHistory.value = [];
  } finally {
    loadingHistory.value = false;
  }
}

async function loadChat(chatId) {
  try {
    const url = `${http_prefix}/lua/pro/rest/v2/get/llm/chat.lua?chatId=${encodeURIComponent(chatId)}`;
    const msgs = (await ntopng_utility.http_request(url)) ?? [];
    if (!Array.isArray(msgs) || msgs.length === 0) return;

    const provider = msgs[0]?.provider;
    if (provider && providers.value.find(p => p.provider === provider)) {
      selectedProvider.value = provider;
    }

    chat_UUID.value = chatId;
    activeChatId.value = chatId;
    messages.value = [];
    history.value = [];

    for (const msg of msgs) {
      const role = parseInt(msg.message_role) === 1 ? "user" : "assistant";
      const content = msg.message_content;
      const time = formatTimestamp(msg.created_at);
      const stats = role === "assistant" ? {
        completion_time_s: msg.completion_time_sec !== "0" ? msg.completion_time_sec : null,
        generation_tokens_per_second: msg.tokens_per_second !== "0" ? msg.tokens_per_second : null,
      } : null;
      let artifact = (role === "assistant" && msg.artifact_json && typeof msg.artifact_json === "object")
        ? msg.artifact_json : null;
      let queries = null;
      let steps = null;
      if (role === "assistant" && msg.evidence_json) {
        let ev = msg.evidence_json;
        if (typeof ev === "string") { try { ev = JSON.parse(ev); } catch (_) { } }
        if (typeof ev === "object" && ev) {
          const tools = (ev.tools || []).filter(t => t.tool || t.thinking || t.sql);
          if (tools.length) { queries = tools; steps = tools; }
        }
      }
      messages.value.push({ role, content, time, error: false, stats, artifact, queries, steps });
      history.value.push({ role, content });
    }

    ntopng_url_manager.set_key_to_url("chatId", chatId);
    nextTick(scrollBottom);
  } catch (err) {
    console.error("llm load chat failed:", err);
  }
}

function startNewChat() {
  clearChat();
  const newId = chat_UUID.value;
  activeChatId.value = newId;
  ntopng_url_manager.set_key_to_url("chatId", newId);
  chatHistory.value.unshift({
    chat_id: newId, title: "New Chat",
    provider: selectedProvider.value ?? "", isNew: true,
  });
}

// Rename
function startRenameChat(chat) {
  renamingChatId.value = chat.chat_id;
  renameValue.value = chat.title;
  nextTick(() => renameInputRef.value?.focus());
}
function cancelRename() { renamingChatId.value = null; renameValue.value = ""; }

async function confirmRename() {
  const id = renamingChatId.value;
  const title = renameValue.value.trim();
  if (!id || !title) { cancelRename(); return; }
  const entry = chatHistory.value.find(c => c.chat_id === id);
  if (entry) entry.title = title;
  cancelRename();
  try {
    await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/post/llm/rename_chat.lua`,
      {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ chatId: id, title, csrf: props.context.csrf })
      }, true);
  } catch (err) { console.error("[llm] renameChatApi failed:", err); }
}

// Delete
async function deleteChat(chatId) {
  chatHistory.value = chatHistory.value.filter(c => c.chat_id !== chatId);
  clearChat();
  try {
    await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/post/llm/delete_chat.lua`,
      {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ chatId, csrf: props.context.csrf })
      }, true);
  } catch (err) { console.error("[llm] deleteChat failed:", err); }
}

// Lifecycle
onMounted(() => {
  const selected_chatId = ntopng_url_manager.get_url_entry("chatId");
  if (selected_chatId) {
    chat_UUID.value = selected_chatId;
    loadChat(chat_UUID.value);
  } else {
    sidebarOpen.value = true;
  }
  loadProviders();
  loadChatHistory();
});

onBeforeUnmount(() => { });
</script>

<style>
@import "highlight.js/styles/github.css";

.hljs {
  background: transparent !important;
}

.llm-chat-page {
  --chat-header-bg: var(--navbar-tab-container-bg, #f1f3f5);
  --chat-footer-bg: var(--navbar-tab-container-bg, #f1f3f5);
  --chat-border: rgba(0, 0, 0, 0.10);
  --chat-text: var(--ntop-text-color, #111111);
  --chat-muted: var(--ntop-muted-text-color, #37474F);
  --sidebar-bg: #e8eaed;
  --sidebar-header-border: rgba(0, 0, 0, 0.08);
  --sidebar-item-hover: rgba(0, 0, 0, 0.06);
  --sidebar-item-active: rgba(255, 143, 0, 0.12);
  --sidebar-item-active-text: var(--ntop-orange-dark, #C56000);
  --sidebar-item-active-border: var(--ntop-orange, #FF8F00);
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
  --hint-color: var(--ntop-muted-text-color, #37474F);
  --provider-pill-hover-border: var(--ntop-orange, #FF8F00);
  --clear-btn-bg: transparent;
  --clear-btn-color: var(--ntop-muted-text-color, #37474F);
  --clear-btn-hover-bg: rgba(255, 143, 0, 0.08);
  --clear-btn-hover-color: var(--ntop-orange, #FF8F00);
}

:root[data-theme='dark'] .llm-chat-page {
  --chat-border: rgba(255, 255, 255, 0.08);
  --sidebar-bg: #111c24;
  --sidebar-header-border: rgba(255, 255, 255, 0.07);
  --sidebar-item-hover: rgba(255, 255, 255, 0.06);
  --sidebar-item-active: rgba(255, 143, 0, 0.15);
  --sidebar-item-active-text: var(--ntop-orange-light, #FFC046);
  --sidebar-item-active-border: var(--ntop-orange, #FF8F00);
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

/* dark-mode hljs overrides */
:root[data-theme='dark'] .hljs {
  color: #e2e8f0;
}

:root[data-theme='dark'] .hljs-comment,
:root[data-theme='dark'] .hljs-quote {
  color: #8b949e;
  font-style: italic;
}

:root[data-theme='dark'] .hljs-keyword,
:root[data-theme='dark'] .hljs-selector-tag,
:root[data-theme='dark'] .hljs-deletion {
  color: #ff7b72;
}

:root[data-theme='dark'] .hljs-string,
:root[data-theme='dark'] .hljs-addition {
  color: #a5d6ff;
}

:root[data-theme='dark'] .hljs-title,
:root[data-theme='dark'] .hljs-section {
  color: #d2a8ff;
}

:root[data-theme='dark'] .hljs-number,
:root[data-theme='dark'] .hljs-literal {
  color: #f2cc60;
}

:root[data-theme='dark'] .hljs-built_in,
:root[data-theme='dark'] .hljs-type {
  color: #ffa657;
}

:root[data-theme='dark'] .hljs-attr,
:root[data-theme='dark'] .hljs-attribute {
  color: #7ee787;
}

:root[data-theme='dark'] .hljs-variable,
:root[data-theme='dark'] .hljs-template-variable {
  color: #e3b341;
}

:root[data-theme='dark'] .hljs-punctuation {
  color: #c9d1d9;
}

/* Shared markdown */
.llm-chat-page .markdown-body p:last-child {
  margin-bottom: 0;
}

.llm-chat-page .markdown-body pre.code-block {
  background: var(--code-bg);
  border: 1px solid var(--code-border);
  border-radius: 8px;
  padding: 0.75rem 1rem;
  overflow-x: auto;
  margin: 0.5rem 0;
}

.llm-chat-page .markdown-body pre.code-block code {
  background: none;
  padding: 0;
  font-size: 0.82em;
  color: var(--code-text);
}

.llm-chat-page .markdown-body code:not(pre code) {
  background: var(--inline-code-bg);
  color: var(--chat-text);
  border-radius: 4px;
  padding: 0.1em 0.4em;
  font-size: 0.83em;
}

.llm-chat-page .markdown-body ul,
.llm-chat-page .markdown-body ol {
  padding-left: 1.4rem;
  margin-bottom: 0.5rem;
}

.llm-chat-page .markdown-body blockquote {
  border-left: 3px solid var(--ntop-orange, #FF8F00);
  padding-left: 0.75rem;
  color: var(--chat-muted);
  margin: 0.5rem 0;
  opacity: 0.85;
}

.llm-chat-page .markdown-body table {
  border-collapse: collapse;
  width: 100%;
  margin: 0.5rem 0;
  font-size: 0.85em;
}

.llm-chat-page .markdown-body th,
.llm-chat-page .markdown-body td {
  border: 1px solid var(--chat-border);
  padding: 0.35rem 0.65rem;
}

.llm-chat-page .markdown-body th {
  background: var(--inline-code-bg);
  color: var(--chat-text);
  font-weight: 600;
}

.llm-chat-page .markdown-body td {
  color: var(--chat-text);
}

.llm-chat-page .markdown-body a {
  color: var(--ntop-orange, #FF8F00);
}

.llm-chat-page .markdown-body h1,
.llm-chat-page .markdown-body h2,
.llm-chat-page .markdown-body h3,
.llm-chat-page .markdown-body h4,
.llm-chat-page .markdown-body h5,
.llm-chat-page .markdown-body h6 {
  color: var(--chat-text);
  margin-top: 0.75rem;
  margin-bottom: 0.35rem;
  font-weight: 600;
}

.llm-chat-page .markdown-body hr {
  border: none;
  border-top: 1px solid var(--chat-border);
  margin: 0.75rem 0;
}
</style>

<style scoped>
/* Page shell */
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

.history-filter-row {
  gap: 4px;
}

.history-filter-btn {
  flex: 1 1 auto;
  min-width: 0;
  padding: 3px 6px;
  font-size: 0.7rem;
  border-radius: 6px;
  border: 1px solid var(--chat-border);
  background: transparent;
  color: var(--chat-muted);
  cursor: pointer;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  transition: background 0.15s, border-color 0.15s, color 0.15s;
}

.history-filter-btn:hover {
  background: var(--sidebar-item-hover);
  color: var(--chat-text);
}

.history-filter-btn.active {
  background: var(--sidebar-item-active);
  border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
  font-weight: 600;
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
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
  width: 200px;
}

.rename-input {
  background: var(--input-bg) !important;
  color: var(--input-text) !important;
  border-color: var(--input-border) !important;
}

.btn-rename-confirm {
  background: var(--send-btn-bg);
  color: #fff;
  border: none;
  border-radius: 7px;
  font-size: 0.78rem;
  padding: 0.3rem 0;
  cursor: pointer;
  transition: background 0.15s;
}

.btn-rename-confirm:hover {
  background: var(--send-btn-hover);
}

.btn-rename-cancel {
  background: transparent;
  border: 1px solid var(--chat-border);
  border-radius: 7px;
  font-size: 0.78rem;
  padding: 0.3rem 0.6rem;
  color: var(--chat-muted);
  cursor: pointer;
}

/* Header */
.chat-header {
  background: var(--chat-header-bg);
  border-bottom: 1px solid var(--chat-border);
}

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

/* Message area */
.chat-messages {
  position: relative;
}

/* Messages inner column — full width */
.messages-inner {
  width: 100%;
}

/* Empty state */
.empty-state-icon {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: var(--empty-icon-bg);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--empty-icon-color);
  font-size: 1.5rem;
}

.preset-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
  max-width: 640px;
  margin: 0 auto;
}

.preset-chip {
  background: transparent;
  border: 1px solid var(--chat-border);
  border-radius: 20px;
  color: var(--chat-text);
  font-size: 0.78rem;
  padding: 0.35rem 0.9rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s, color 0.15s;
  white-space: normal;
  text-align: left;
}

.preset-chip:hover:not(:disabled) {
  background: rgba(255, 143, 0, 0.10);
  border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
}

.preset-chip:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

/* Chat bubbles — wider on the full page */
.chat-bubble {
  padding: 0.65rem 0.9rem;
  border-radius: 14px;
  max-width: 90%;
  animation: fadeUp 0.18s ease-out;
}

@keyframes fadeUp {
  from {
    opacity: 0;
    transform: translateY(6px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.user-bubble {
  background: var(--user-bubble-bg);
  color: #fff;
  box-shadow: 0 2px 8px var(--user-bubble-shadow);
  border-bottom-right-radius: 4px;
}

.user-bubble .bubble-meta-user {
  color: rgba(255, 255, 255, 0.7);
}

.assistant-bubble {
  background: var(--assistant-bubble-bg);
  border: 1px solid var(--assistant-bubble-border);
  box-shadow: 0 1px 6px var(--assistant-bubble-shadow);
  color: var(--chat-text);
  border-bottom-left-radius: 4px;
}

.assistant-bubble .bubble-meta-assistant {
  color: var(--chat-muted);
}

.error-bubble {
  background: var(--error-bubble-bg);
  border: 1px solid var(--error-bubble-border);
  color: var(--error-bubble-text);
  border-bottom-left-radius: 4px;
}

.error-label {
  color: var(--error-bubble-text);
}

.chat-avatar {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.8rem;
  flex-shrink: 0;
}

.assistant-avatar {
  background: var(--assistant-avatar-bg);
  color: #fff;
}

.user-avatar {
  background: var(--user-avatar-bg);
  color: #fff;
}

.chat-text-color {
  color: var(--chat-text);
}

.chat-muted-text {
  color: var(--chat-muted);
}

/* Typing indicator */
.typing-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--chat-muted);
  opacity: 0.5;
  animation: typingPulse 1.2s infinite ease-in-out;
}

.typing-dot:nth-child(2) {
  animation-delay: 0.2s;
}

.typing-dot:nth-child(3) {
  animation-delay: 0.4s;
}

@keyframes typingPulse {

  0%,
  80%,
  100% {
    transform: scale(1);
    opacity: 0.5;
  }

  40% {
    transform: scale(1.25);
    opacity: 1;
  }
}

/* Thinking steps */
.steps-bubble {
  padding: 0.5rem 0.85rem;
}

.steps-toggle-btn {
  background: none;
  border: none;
  padding: 0 0.3rem;
  cursor: pointer;
  font-size: 0.68rem;
  color: var(--chat-muted);
  transition: color 0.15s;
}

.steps-toggle-btn:hover {
  color: var(--ntop-orange, #FF8F00);
}

.steps-toggle-btn .fas {
  font-size: 0.6rem;
}

.steps-panel {
  border-top: 1px solid var(--chat-border);
  padding-top: 0.4rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.step-entry {
  display: flex;
  align-items: flex-start;
  gap: 0.4rem;
  font-size: 0.72rem;
  color: var(--chat-muted);
}

.step-icon {
  font-size: 0.65rem;
  margin-top: 0.15rem;
  flex-shrink: 0;
}

.tool-icon {
  color: var(--ntop-orange, #FF8F00);
}

.thinking-icon {
  color: var(--chat-muted);
}

.step-label {
  line-height: 1.4;
  word-break: break-word;
}

.thinking-text {
  font-style: italic;
  opacity: 0.8;
}

/* Evidence entries (tool + thinking + sql) */
.evidence-entry {
  border-bottom: 1px solid var(--code-border);
  padding: 0.4rem 0.75rem;
}

.evidence-entry:last-child {
  border-bottom: none;
}

.evidence-tool-badge {
  display: inline-flex;
  align-items: center;
  font-size: 0.68rem;
  font-weight: 600;
  color: var(--ntop-orange, #FF8F00);
  margin-bottom: 0.2rem;
}

.evidence-thinking {
  font-size: 0.72rem;
  color: var(--chat-muted);
  font-style: italic;
  opacity: 0.85;
  margin-bottom: 0.3rem;
  line-height: 1.4;
}

/* Next step chips */
.next-steps-row {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  padding-top: 0.5rem;
  border-top: 1px solid var(--chat-border);
}

.next-steps-label {
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--chat-text);
  opacity: 0.85;
}

.next-step-chip {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
  background: var(--inline-code-bg, rgba(175, 184, 193, 0.20));
  border: 1px solid var(--chat-border);
  border-radius: 0.5rem;
  padding: 0.35rem 0.75rem;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s, border-color 0.15s;
}

.next-step-chip:hover:not(:disabled) {
  background: rgba(255, 143, 0, 0.10);
  border-color: var(--ntop-orange, #FF8F00);
}

.next-step-chip:hover:not(:disabled) .next-step-title {
  color: var(--ntop-orange-dark, #C56000);
}

.next-step-chip:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.next-step-chip .fas {
  font-size: 0.65rem;
  color: var(--ntop-orange, #FF8F00);
  margin-top: 0.15rem;
  flex-shrink: 0;
}

.next-step-title {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--chat-text);
  line-height: 1.4;
}

.next-step-desc {
  font-size: 0.75rem;
  color: var(--chat-muted);
  line-height: 1.4;
}

/* SQL panel */
.sql-toggle-btn {
  font-size: 0.72rem;
  color: var(--chat-muted) !important;
  text-decoration: none !important;
}

.sql-toggle-btn:hover {
  color: var(--ntop-orange, #FF8F00) !important;
}

.sql-panel {
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid var(--code-border);
}

.sql-block {
  margin: 0;
  padding: 0.5rem 0.75rem;
  background: var(--code-bg);
  font-size: 0.78rem;
  line-height: 1.5;
  overflow-x: auto;
}

.chat-artifact-block {
  margin-bottom: 0.5rem;
}

/* Scroll overlay buttons */
.scroll-overlay-btns {
  position: sticky;
  bottom: 8px;
  right: 8px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  width: fit-content;
  align-self: flex-end;
  pointer-events: none;
  margin-right: 8px;
}

.scroll-overlay-btn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--provider-pill-bg);
  border: 1px solid var(--chat-border);
  border-radius: 50%;
  color: var(--chat-muted);
  font-size: 0.72rem;
  cursor: pointer;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.10);
  transition: background 0.15s, color 0.15s, border-color 0.15s;
  padding: 0;
  pointer-events: auto;
}

.scroll-overlay-btn:hover {
  background: var(--ntop-orange, #FF8F00);
  border-color: var(--ntop-orange, #FF8F00);
  color: #fff;
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

/* Scrollbar */
.chat-messages::-webkit-scrollbar {
  width: 5px;
}

.chat-messages::-webkit-scrollbar-track {
  background: transparent;
}

.chat-messages::-webkit-scrollbar-thumb {
  background: var(--scrollbar-thumb);
  border-radius: 4px;
}

.sidebar-chat-list::-webkit-scrollbar {
  width: 4px;
}

.sidebar-chat-list::-webkit-scrollbar-track {
  background: transparent;
}

.sidebar-chat-list::-webkit-scrollbar-thumb {
  background: var(--scrollbar-thumb);
  border-radius: 4px;
}
</style>
