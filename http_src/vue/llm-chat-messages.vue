<template>
  <div ref="messageList" class="chat-messages flex-grow-1 overflow-auto d-flex flex-column"
    style="position: relative;">

    <!-- Empty state with preset questions -->
    <div v-if="messages.length === 0" class="m-auto text-center py-5 px-3">
      <div class="empty-state-icon mx-auto mb-4"><i class="fas fa-comments"></i></div>
      <h3 class="fw-semibold chat-text-color mb-4">{{ _i18n('llm.ask_a_question') }}</h3>
      <div class="preset-grid">
        <button v-for="q in activePresets" :key="q" class="preset-chip"
          :disabled="sending || providers.length === 0" @click="$emit('fill-step', q)">
          {{ q }}
        </button>
      </div>
    </div>

    <!-- Messages -->
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
            v-html="renderMarkdown(stripNextSteps(stripActionableSteps(msg.content)))"></div>

          <template v-if="msg.role === 'assistant' && parseActionableSteps(msg.content).length">
            <div class="actionable-steps-row mt-2">
              <span class="actionable-steps-label">
                <i class="fas fa-bolt me-1"></i>{{ _i18n('llm.actionable_steps') }}
              </span>
              <button v-for="(step, si) in parseActionableSteps(msg.content)" :key="si" class="actionable-step-chip"
                :disabled="sending" :title="step.full" @click="$emit('fill-step', step.full)">
                <i class="fas fa-chevron-right me-1 flex-shrink-0"></i>
                <span class="actionable-step-title">{{ step.label }}</span>
                <span v-if="step.desc" class="actionable-step-desc">{{ step.desc }}</span>
              </button>
            </div>
          </template>

          <!-- Render href button to go to the called tool page, for now: active monitoring and policies -->
          <template v-if="msg.role === 'assistant'">
            <template v-for="(link, toolName) in toolActionLinks" :key="toolName">
              <div v-if="msg.steps?.some(s => s.tool === toolName)" class="mt-2">
                <a :href="link.href" target="_blank" rel="noopener" class="ai-policy-link-btn">
                  <i :class="link.icon + ' me-1'"></i>{{ _i18n(link.i18nKey) }}
                  <i class="fas fa-external-link-alt ms-1" style="font-size:0.6rem;opacity:0.7;"></i>
                </a>
              </div>
            </template>
          </template>

          <template v-if="msg.role === 'assistant' && parseNextSteps(msg.content).length">
            <div class="next-steps-row mt-2">
              <span class="next-steps-label">{{ _i18n('llm.next_steps') }}</span>
              <button v-for="(step, si) in parseNextSteps(msg.content)" :key="si" class="next-step-chip"
                :disabled="sending" :title="step.full" @click="$emit('fill-step', step.full)">
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
              <button class="btn btn-link p-0 sql-toggle-btn" @click="$emit('toggle-sql-panel', idx)">
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

          <!-- Toggle row: triangle + "Thinking" label + dots always visible -->
          <div class="d-flex align-items-center gap-2">
            <button class="btn btn-link p-0 sql-toggle-btn" style="font-size:0.75rem;"
              @click.stop="stepsExpanded = !stepsExpanded">
              <i :class="stepsExpanded ? 'fas fa-chevron-down' : 'fas fa-chevron-right'" class="me-1"
                style="font-size:0.6rem;"></i>{{ _i18n('llm.thinking') }}
            </button>
            <!-- Dots always visible while sending -->
            <span class="d-flex align-items-center gap-1">
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
      <button class="scroll-overlay-btn" title="Scroll to bottom" @click="scrollBottom">
        <i class="fas fa-chevron-down"></i>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, nextTick, computed } from "vue";
import PieChart from "./charts/pie-chart.vue";
import LineChart from "./charts/line-chart.vue";
import { renderMarkdown, highlightSql } from "./composables/useLlmChat.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  messages:     { type: Array,   default: () => [] },
  sending:      { type: Boolean, default: false },
  liveSteps:    { type: Array,   default: () => [] },
  openSqlPanels:{ type: Object,  default: () => new Set() },
  providers:    { type: Array,   default: () => [] },
  aiPolicyUrl:  { type: String,  default: "" },
  activeMonitoringUrl: { type: String, default: "" },
  activePresets:{ type: Array,   default: () => [] },
});

const emit = defineEmits(["toggle-sql-panel", "fill-step"]);

// used to map tool name to page href and i18n key, this is used to render a button for ai policy or active monitoring script created
const toolActionLinks = computed(() => ({
  create_ai_policy:              { i18nKey: "llm.open_ai_policies",        href: props.aiPolicyUrl,          icon: "fas fa-shield-alt" },
  add_active_monitoring_script:  { i18nKey: "llm.open_active_monitoring",   href: props.activeMonitoringUrl,  icon: "fas fa-heartbeat"  },
}));

const messageList = ref(null);

// Thinking panel state
const stepsExpanded  = ref(false);
const typedThinking  = ref([]);
let typewriterTimer  = null;

watch(() => props.liveSteps, (steps) => {
  const idx = steps.length - 1;
  if (idx < 0) { typedThinking.value = []; return; }

  while (typedThinking.value.length <= idx) typedThinking.value.push("");

  for (let i = 0; i < idx; i++) {
    typedThinking.value[i] = steps[i].thinking || "";
  }

  clearInterval(typewriterTimer);
  const full = steps[idx].thinking || "";
  typedThinking.value[idx] = "";
  let pos = 0;
  typewriterTimer = setInterval(() => {
    pos += 3;
    typedThinking.value = [
      ...typedThinking.value.slice(0, idx),
      full.slice(0, pos),
    ];
    if (pos >= full.length) clearInterval(typewriterTimer);
  }, 16);
}, { deep: false });

watch(() => props.sending, (val) => {
  if (val) {
    stepsExpanded.value = false;
    typedThinking.value = [];
  }
});

// Auto-scroll when a new message is added
watch(() => props.messages.length, (newLen, oldLen) => {
  if (newLen <= oldLen) return;
  const lastMsg = props.messages[newLen - 1];
  nextTick(lastMsg?.role === "user" ? scrollBottom : scrollToLastMessage);
});

function scrollBottom() {
  if (messageList.value) messageList.value.scrollTop = messageList.value.scrollHeight;
}

function scrollToLastMessage() {
  if (!messageList.value) return;
  const bubbles = messageList.value.querySelectorAll(".chat-bubble");
  const last = bubbles[bubbles.length - 1];
  if (last) last.scrollIntoView({ block: "start", behavior: "smooth" });
}

defineExpose({ scrollBottom, scrollToLastMessage });

// ── Content helpers ─────────────────────────────────────────────────────────

function stripActionableSteps(content) {
  if (!content) return content;
  return content.replace(/\n?###\s*Actionable Steps\s*\n[\s\S]*?(?=\n###|\n##|$)/i, "").trimEnd();
}

function parseActionableSteps(content) {
  if (!content) return [];
  const match = content.match(/###\s*Actionable Steps\s*\n([\s\S]*?)(?=\n###|\n##|$)/i);
  if (!match) return [];
  const steps = [];
  for (const line of match[1].split("\n")) {
    const m = line.match(/^\s*[-*]\s+(.+)/);
    if (m) {
      const raw = m[1].trim();
      const boldMatch = raw.match(/^\*\*([^*]+)\*\*\s*[—–-]?\s*(.*)/);
      if (boldMatch) {
        const label = boldMatch[1].trim();
        const desc  = boldMatch[2].replace(/\*\*([^*]+)\*\*/g, "$1").trim();
        steps.push({ label, desc, full: raw.replace(/\*\*([^*]+)\*\*/g, "$1").trim() });
      } else {
        const parts = raw.replace(/\*\*/g, "").split(/[—–-]/);
        steps.push({ label: parts[0].trim(), desc: parts.slice(1).join("—").trim(), full: raw.replace(/\*\*/g, "").trim() });
      }
    }
  }
  return steps;
}

function stripNextSteps(content) {
  if (!content) return content;
  return content.replace(/\n?###\s*Next Steps\s*\n[\s\S]*?(?=\n###|\n##|$)/i, "").trimEnd();
}

function parseNextSteps(content) {
  if (!content) return [];
  const match = content.match(/###\s*Next Steps\s*\n([\s\S]*?)(?=\n###|\n##|$)/i);
  if (!match) return [];
  const steps = [];
  for (const line of match[1].split("\n")) {
    const m = line.match(/^\s*\d+\.\s+(.+)/);
    if (m) {
      const raw = m[1].trim();
      const boldMatch = raw.match(/^\*\*([^*]+)\*\*\s*[—–-]?\s*(.*)/);
      if (boldMatch) {
        const label = boldMatch[1].trim();
        const desc  = boldMatch[2].replace(/\*\*([^*]+)\*\*/g, "$1").trim();
        const full  = raw.replace(/\*\*([^*]+)\*\*/g, "$1").trim();
        steps.push({ label, desc, full });
      } else {
        const full  = raw.replace(/\*\*([^*]+)\*\*/g, "$1").trim();
        const parts = full.split(/[—–-]/);
        steps.push({ label: parts[0].trim(), desc: parts.slice(1).join("—").trim(), full });
      }
    }
  }
  return steps;
}
</script>

<style>
@import "highlight.js/styles/github.css";

.hljs {
  background: transparent !important;
}
</style>

<style scoped>
/* Empty state */
.empty-state-icon {
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: var(--empty-icon-bg, rgba(255, 143, 0, 0.10));
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--empty-icon-color, var(--ntop-orange, #FF8F00));
  font-size: 1.3rem;
}

.preset-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: center;
}

.preset-chip {
  background: transparent;
  border: 1px solid var(--chat-border, rgba(0, 0, 0, 0.10));
  border-radius: 20px;
  color: var(--chat-text, #111);
  font-size: 0.76rem;
  padding: 0.3rem 0.8rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s, color 0.15s;
  white-space: nowrap;
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

/* Chat bubbles */
.chat-bubble {
  padding: 0.6rem 0.85rem;
  border-radius: 14px;
  max-width: 90%;
  animation: fadeUp 0.18s ease-out;
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(6px); }
  to   { opacity: 1; transform: translateY(0); }
}

.user-bubble {
  background: var(--user-bubble-bg, var(--ntop-orange, #FF8F00));
  color: #fff;
  box-shadow: 0 2px 8px var(--user-bubble-shadow, rgba(255, 143, 0, 0.30));
  border-bottom-right-radius: 4px;
}

.user-bubble .bubble-meta-user {
  color: rgba(255, 255, 255, 0.7);
}

.assistant-bubble {
  background: var(--assistant-bubble-bg, #fff);
  border: 1px solid var(--assistant-bubble-border, rgba(0, 0, 0, 0.10));
  box-shadow: 0 1px 6px var(--assistant-bubble-shadow, rgba(0, 0, 0, 0.06));
  color: var(--chat-text, #111);
  border-bottom-left-radius: 4px;
}

.assistant-bubble .bubble-meta-assistant {
  color: var(--chat-muted, #37474F);
}

.error-bubble {
  background: var(--error-bubble-bg, #fff3f3);
  border: 1px solid var(--error-bubble-border, rgba(220, 53, 69, 0.25));
  color: var(--error-bubble-text, #b91c1c);
  border-bottom-left-radius: 4px;
}

.error-label {
  color: var(--error-bubble-text, #b91c1c);
}

/* Avatars */
.chat-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  flex-shrink: 0;
}

.assistant-avatar {
  background: var(--assistant-avatar-bg, var(--ntop-orange, #FF8F00));
  color: #fff;
}

.user-avatar {
  background: var(--user-avatar-bg, var(--ntop-blue-light, #62717B));
  color: #fff;
}

/* Typing dots */
.typing-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--chat-muted, #37474F);
  opacity: 0.5;
  animation: typingPulse 1.2s infinite ease-in-out;
}

.typing-dot:nth-child(2) { animation-delay: 0.2s; }
.typing-dot:nth-child(3) { animation-delay: 0.4s; }

@keyframes typingPulse {
  0%, 80%, 100% { transform: scale(1);    opacity: 0.5; }
  40%           { transform: scale(1.25); opacity: 1;   }
}

/* SQL toggle / panel */
.sql-toggle-btn {
  font-size: 0.72rem;
  color: var(--chat-muted, #37474F) !important;
  text-decoration: none !important;
}

.sql-toggle-btn:hover {
  color: var(--ntop-orange, #FF8F00) !important;
}

.sql-panel {
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid var(--code-border, rgba(0, 0, 0, 0.10));
}

.sql-block {
  margin: 0;
  padding: 0.5rem 0.75rem;
  background: var(--code-bg, #f6f8fa);
  font-size: 0.78rem;
  line-height: 1.5;
  overflow-x: auto;
}

/* Evidence entries (structured tool + thinking + sql) */
.evidence-entry {
  border-bottom: 1px solid var(--code-border, rgba(0, 0, 0, 0.10));
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
  color: var(--chat-muted, #37474F);
  font-style: italic;
  opacity: 0.85;
  margin-bottom: 0.3rem;
  line-height: 1.4;
}

/* Artifact block */
.chat-artifact-block {
  margin-bottom: 0.5rem;
}

/* Markdown */
:deep(.markdown-body) p:last-child { margin-bottom: 0; }

:deep(.markdown-body) pre.code-block {
  background: var(--code-bg, #f6f8fa);
  border: 1px solid var(--code-border, rgba(0, 0, 0, 0.10));
  border-radius: 8px;
  padding: 0.75rem 1rem;
  overflow-x: auto;
  margin: 0.5rem 0;
}

:deep(.markdown-body) pre.code-block code {
  background: none;
  padding: 0;
  font-size: 0.82em;
  color: var(--code-text, #24292e);
}

:deep(.markdown-body) code:not(pre code) {
  background: var(--inline-code-bg, rgba(175, 184, 193, 0.22));
  color: var(--chat-text, #111);
  border-radius: 4px;
  padding: 0.1em 0.4em;
  font-size: 0.83em;
}

:deep(.markdown-body) ul,
:deep(.markdown-body) ol {
  padding-left: 1.4rem;
  margin-bottom: 0.5rem;
}

:deep(.markdown-body) blockquote {
  border-left: 3px solid var(--ntop-orange, #FF8F00);
  padding-left: 0.75rem;
  color: var(--chat-muted, #37474F);
  margin: 0.5rem 0;
  opacity: 0.85;
}

:deep(.markdown-body) table {
  border-collapse: collapse;
  width: 100%;
  margin: 0.5rem 0;
  font-size: 0.85em;
}

:deep(.markdown-body) th,
:deep(.markdown-body) td {
  border: 1px solid var(--chat-border, rgba(0, 0, 0, 0.10));
  padding: 0.35rem 0.65rem;
}

:deep(.markdown-body) th {
  background: var(--inline-code-bg, rgba(175, 184, 193, 0.22));
  color: var(--chat-text, #111);
  font-weight: 600;
}

:deep(.markdown-body) td { color: var(--chat-text, #111); }
:deep(.markdown-body) a  { color: var(--ntop-orange, #FF8F00); }

:deep(.markdown-body) h1,
:deep(.markdown-body) h2,
:deep(.markdown-body) h3,
:deep(.markdown-body) h4,
:deep(.markdown-body) h5,
:deep(.markdown-body) h6 {
  color: var(--chat-text, #111);
  margin-top: 0.75rem;
  margin-bottom: 0.35rem;
  font-weight: 600;
}

:deep(.markdown-body) hr {
  border: none;
  border-top: 1px solid var(--chat-border, rgba(0, 0, 0, 0.10));
  margin: 0.75rem 0;
}

/* Actionable step chips */
.actionable-steps-row {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  padding: 0.5rem 0.6rem 0.4rem;
  border-top: 2px solid var(--ntop-orange, #FF8F00);
  border-radius: 0 0 8px 8px;
  background: rgba(255, 143, 0, 0.05);
  margin-top: 0.5rem;
}

.actionable-steps-label {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--ntop-orange, #FF8F00);
  margin-bottom: 0.1rem;
}

.actionable-step-chip {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
  background: rgba(255, 143, 0, 0.10);
  border: 1px solid rgba(255, 143, 0, 0.35);
  border-radius: 0.5rem;
  padding: 0.35rem 0.75rem;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s, border-color 0.15s;
}

.actionable-step-chip:hover:not(:disabled) {
  background: rgba(255, 143, 0, 0.22);
  border-color: var(--ntop-orange, #FF8F00);
}

.actionable-step-chip:disabled { opacity: 0.4; cursor: not-allowed; }

.actionable-step-chip .fas {
  font-size: 0.65rem;
  color: var(--ntop-orange, #FF8F00);
  margin-top: 0.15rem;
  flex-shrink: 0;
}

.actionable-step-title {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--ntop-orange-dark, #C56000);
  line-height: 1.4;
}

.actionable-step-desc {
  font-size: 0.75rem;
  color: var(--chat-muted, #37474F);
  line-height: 1.4;
}

/* Next step chips */
.next-steps-row {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  padding-top: 0.5rem;
  border-top: 1px solid var(--chat-border, rgba(0, 0, 0, 0.10));
}

.next-steps-label {
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--chat-text, #111);
  opacity: 0.85;
}

.next-step-chip {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
  background: var(--inline-code-bg, rgba(175, 184, 193, 0.20));
  border: 1px solid var(--chat-border, rgba(0, 0, 0, 0.10));
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

.next-step-chip:disabled { opacity: 0.4; cursor: not-allowed; }

.next-step-chip .fas {
  font-size: 0.65rem;
  color: var(--ntop-orange, #FF8F00);
  margin-top: 0.15rem;
  flex-shrink: 0;
}

.next-step-title {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--chat-text, #111);
  line-height: 1.4;
}

.next-step-desc {
  font-size: 0.75rem;
  color: var(--chat-muted, #37474F);
  line-height: 1.4;
}

/* AI policy link */
.ai-policy-link-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.65rem;
  border-radius: 6px;
  border: 1px solid var(--ntop-orange, #FF8F00);
  background: transparent;
  color: var(--ntop-orange, #FF8F00);
  font-size: 0.75rem;
  font-weight: 600;
  text-decoration: none;
  transition: background 0.15s, color 0.15s;
}

.ai-policy-link-btn:hover {
  background: rgba(255, 143, 0, 0.10);
  color: var(--ntop-orange-dark, #C56000);
  text-decoration: none;
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
  background: var(--provider-pill-bg, rgba(255, 255, 255, 0.75));
  border: 1px solid var(--chat-border, rgba(0, 0, 0, 0.10));
  border-radius: 50%;
  color: var(--chat-muted, #37474F);
  font-size: 0.68rem;
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

/* Scrollbar */
.chat-messages::-webkit-scrollbar { width: 5px; }
.chat-messages::-webkit-scrollbar-track { background: transparent; }
.chat-messages::-webkit-scrollbar-thumb {
  background: var(--scrollbar-thumb, rgba(0, 0, 0, 0.15));
  border-radius: 4px;
}
</style>
