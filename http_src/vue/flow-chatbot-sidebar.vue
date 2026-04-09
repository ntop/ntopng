<template>
  <!-- Floating toggle button (always visible if LLM is available) -->
  <button
    v-if="!open && showButton"
    class="flow-chat-fab"
    :title="_i18n('llm.ask_assistant')"
    @click="openPanel"
  >
    <i class="fas fa-robot me-1"></i>
    <span>{{ _i18n('llm.ask_assistant') }}</span>
  </button>

  <!-- Side panel -->
  <transition name="slide-right">
    <div v-if="open" class="flow-chat-panel d-flex flex-column">

      <!-- Panel header -->
      <div class="flow-chat-panel-header d-flex align-items-center px-3 py-2 flex-shrink-0">
        <i class="fas fa-robot me-2" style="color: var(--ntop-orange, #FF8F00);"></i>
        <span class="fw-semibold small">{{ _i18n('llm.nAnalyst') }}</span>
        <button class="btn-close ms-auto" style="font-size:0.7rem;" @click="closePanel"></button>
      </div>

      <!-- Chatbot widget -->
      <div class="flex-grow-1" style="min-height:0; overflow:hidden;">
        <Chatbot :context="chatContext" />
      </div>

    </div>
  </transition>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from "vue";
import Chatbot from "./chatbot.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: { type: Object, default: () => ({}) },
});

const open       = ref(false);
const showButton = ref(false);

// Derive client label from flow_data for preset questions
const cli = computed(() => {
  const fd = props.context?.flow_data;
  if (!fd?.client_host_info) return "the client";
  const h = fd.client_host_info;
  return h.name || h.ip || "the client";
});

// Preset questions
const PRESET_FLOW_DETAILS = computed(() => {
  return [
    `Is this flow suspicious?`,
    `What other flows has ${cli.value} generated in the last 1h?`,
    `Are there other flows from ${cli.value} to different destinations?`,
    `Explain the alerts on this flow. Are they critical?`,
  ];
});

const PRESET_LIVE_FLOW = computed(() => {
  return [
    `Is this flow suspicious?`,
    `What other flows has ${cli.value} generated in the last 1h?`,
    `Are there other flows from ${cli.value} to different destinations?`,
    `Explain the alerts on this flow. Are they critical?`,
  ];
});

const activePresets = computed(() =>
  props.context?.page === "live_flows" ? PRESET_LIVE_FLOW.value : PRESET_FLOW_DETAILS.value
);


const chatContext = computed(() => ({
  csrf:            props.context?.csrf,
  presetQuestions: activePresets.value,
  initialMessage:  buildInitialMessage(),
  page_context: JSON.stringify({
    page:         "flow_details",
    ifid:         props.context?.ifid,
    flow_key:     props.context?.flow_key,
    flow_hash_id: props.context?.flow_hash_id,
  }),
}));

function buildInitialMessage() {
  const fd   = props.context?.flow_data;
  const ifid = props.context?.ifid;
  const fk   = props.context?.flow_key;
  const fh   = props.context?.flow_hash_id;

  const lines = [];
  lines.push(`FLOW CONTEXT — ifid=${ifid} flow_key=${fk} flow_hash_id=${fh}`);

  if (fd && typeof fd === "object") {
    const c = fd.client_host_info || {};
    const s = fd.server_host_info || {};
    const p = fd.protocol || {};
    const t = fd.traffic_stats || {};
    const ts = fd.timestamps || {};
    const c2s = t.client_to_server || {};
    const s2c = t.server_to_client || {};

    lines.push(`Client : ${c.name || c.ip || "?"}:${c.port ?? "?"} | local=${c.is_local} | AS${c.asn ?? "N/A"} ${c.asn_name ?? ""} | country=${c.country ?? "?"}`);
    lines.push(`Server : ${s.name || s.ip || "?"}:${s.port ?? "?"} | local=${s.is_local} | AS${s.asn ?? "N/A"} ${s.asn_name ?? ""} | country=${s.country ?? "?"}`);
    lines.push(`Protocol: ${p.l4 ?? "?"}/${p.ndpi ?? "?"} | category=${p.ndpi_category ?? "?"} | encrypted=${p.is_encrypted} | confidence=${p.confidence ?? "?"}`);
    lines.push(`Traffic: total=${t.bytes_total ?? 0}B | C→S=${c2s.bytes ?? 0}B (${c2s.packets ?? 0}pkt) | S→C=${s2c.bytes ?? 0}B (${s2c.packets ?? 0}pkt)`);
    if (ts.duration_sec != null) lines.push(`Duration: ${ts.duration_sec}s | first=${ts.first_seen} | last=${ts.last_seen}`);
    if (fd.score)                lines.push(`Score: flow=${fd.score.flow_score} | net=${fd.score.network} | sec=${fd.score.security}`);

    if (fd.tls) {
      const parts = [];
      if (fd.tls.client_requested_sni) parts.push(`SNI=${fd.tls.client_requested_sni}`);
      if (fd.tls.ja4_client_hash)      parts.push(`JA4=${fd.tls.ja4_client_hash}`);
      if (fd.tls.ja4_client_malicious) parts.push("JA4=MALICIOUS");
      if (parts.length) lines.push(`TLS: ${parts.join(" | ")}`);
    }
    if (fd.dns)  lines.push(`DNS: query=${fd.dns.query} type=${fd.dns.query_type} rcode=${fd.dns.return_code}`);
    if (fd.http) lines.push(`HTTP: ${fd.http.method} ${fd.http.url} → ${fd.http.return_code}`);

    if (fd.alerts?.length) {
      lines.push("Alerts:");
      for (const a of fd.alerts) {
        let row = `  - [${a.source}] ${a.label}`;
        if (a.risk_label) row += `: ${a.risk_label}`;
        if (a.mitre)      row += ` (MITRE ${a.mitre.id} – ${a.mitre.tactic ?? ""})`;
        if (a.alert_description) row += `\n    ${a.alert_description}`;
        lines.push(row);
      }
    }

    lines.push("Full snapshot (JSON): " + JSON.stringify(fd));
  }

  lines.push("---");
  lines.push(
    `You are analysing this specific flow. The identifiers ifid=${ifid}, flow_key=${fk}, flow_hash_id=${fh} ` +
    `are fixed for this session — use them directly with get_live_flow to refresh counters. ` +
    `Never ask the user for these values. Correlate with ClickHouse for broader context. Be concise.`
  );
  return lines.join("\n");
}

async function checkLlmAvailable() {
  try {
    const url = `${http_prefix}/lua/pro/rest/v2/get/llm/providers.lua`;
    const list = await ntopng_utility.http_request(url);
    showButton.value = Array.isArray(list) && list.length > 0;
  } catch (_) {
    showButton.value = false;
  }
}

// Panel open / close
function openPanel() {
  open.value = true;
  document.body.classList.add("flow-chat-sidebar-open");
}

function closePanel() {
  open.value = false;
  document.body.classList.remove("flow-chat-sidebar-open");
}

onMounted(() => {
  checkLlmAvailable();
});

onBeforeUnmount(() => {
  document.body.classList.remove("flow-chat-sidebar-open");
});

</script>

<style>
body.flow-chat-sidebar-open main,
body.flow-chat-sidebar-open .main-content {
  margin-right: 20vw;
  transition: margin-right 0.25s ease;
}
</style>

<style scoped>
/* Floating action button */
.flow-chat-fab {
  position: fixed;
  bottom: 28px;
  right: 28px;
  z-index: 1050;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 18px;
  border-radius: 24px;
  border: none;
  background: var(--ntop-orange, #FF8F00);
  color: #fff;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(255, 143, 0, 0.4);
  transition: background 0.15s ease, box-shadow 0.15s ease;
}
.flow-chat-fab:hover {
  background: var(--ntop-orange-dark, #C56000);
  box-shadow: 0 4px 20px rgba(255, 143, 0, 0.55);
}

/* Side panel */
.flow-chat-panel {
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  width: 20vw;
  min-width: 280px;
  z-index: 1040;
  background: var(--content-bg, #ffffff);
  border-left: 1px solid rgba(0, 0, 0, 0.12);
  box-shadow: -4px 0 24px rgba(0, 0, 0, 0.10);
}

.flow-chat-panel-header {
  background: var(--navbar-tab-container-bg, #f1f3f5);
  border-bottom: 1px solid rgba(0, 0, 0, 0.10);
  flex-shrink: 0;
}

/* Slide-in transition */
.slide-right-enter-active,
.slide-right-leave-active {
  transition: transform 0.25s ease, opacity 0.2s ease;
}
.slide-right-enter-from,
.slide-right-leave-to {
  transform: translateX(100%);
  opacity: 0;
}
</style>
