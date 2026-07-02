<!--
  (C) 2024 - ntop.org
  Demo page: alerts-over-time heatmap driven by the REST endpoint.
-->
<template>
  <div class="container-fluid px-3 py-3">
    <!-- Controls row -->
    <div class="row g-2 mb-3 align-items-end">
      <div class="col-auto">
        <label class="form-label small mb-1 text-muted">{{ _i18n('unit') }}</label>
        <select class="form-select form-select-sm" v-model="selected_unit" @change="refresh_chart">
          <option value="alerts">{{ _i18n('alerts') || 'Alerts' }}</option>
          <option value="number">{{ _i18n('number') || 'Number' }}</option>
          <option value="bytes">{{ _i18n('bytes') || 'Bytes' }}</option>
          <option value="flows">{{ _i18n('flows') || 'Flows' }}</option>
        </select>
      </div>
      <div class="col-auto">
        <label class="form-label small mb-1 text-muted">{{ _i18n('color_scheme') || 'Color Scheme' }}</label>
        <select class="form-select form-select-sm" v-model="selected_scheme" @change="refresh_chart">
          <option value="orange">{{ _i18n('orange') || 'Orange (ntop)' }}</option>
          <option value="red">{{ _i18n('red') || 'Red (alerts)' }}</option>
          <option value="blue">{{ _i18n('blue') || 'Blue' }}</option>
          <option value="green">{{ _i18n('green') || 'Green' }}</option>
        </select>
      </div>
      <div class="col-auto">
        <label class="form-label small mb-1 text-muted">{{ _i18n('time_window') || 'Time Window' }}</label>
        <select class="form-select form-select-sm" v-model="selected_hours" @change="refresh_chart">
          <option :value="6">{{ '6h' }}</option>
          <option :value="12">{{ '12h' }}</option>
          <option :value="24">{{ '24h' }}</option>
          <option :value="48">{{ '48h' }}</option>
        </select>
      </div>
      <div class="col-auto ms-auto">
        <button class="btn btn-sm btn-primary" @click="refresh_chart">
          <i class="fas fa-sync-alt me-1"></i>{{ _i18n('refresh') || 'Refresh' }}
        </button>
      </div>
    </div>

    <!-- Main heatmap card -->
    <div class="card border-0 shadow-sm mb-4">
      <div class="card-body p-3">
        <div class="d-flex align-items-center mb-2">
          <i class="fas fa-th me-2" style="color: var(--ntop-orange)"></i>
          <span class="fw-semibold">{{ _i18n('alerts_over_time') || 'Alerts Over Time' }}</span>
          <span class="badge bg-secondary ms-2 small">{{ _i18n('heatmap') || 'Heatmap' }}</span>
        </div>
        <HeatmapChart :key="chart_key" :chart="chart_cfg" />
      </div>
    </div>

    <!-- Compact embed example -->
    <div class="row g-3">
      <div class="col-lg-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-body p-3">
            <p class="small text-muted mb-2">
              <i class="fas fa-info-circle me-1"></i>
              {{ _i18n('heatmap_embed_note') || 'Compact embed — set cell_size/cell_gap for density' }}
            </p>
            <HeatmapChart :key="chart_key + '_compact'" :chart="compact_cfg" />
          </div>
        </div>
      </div>
      <div class="col-lg-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-body p-3">
            <p class="small text-muted mb-2">
              <i class="fas fa-shield-alt me-1"></i>
              {{ _i18n('severity_breakdown') || 'Severity Breakdown — red scheme' }}
            </p>
            <HeatmapChart :key="chart_key + '_red'" :chart="severity_cfg" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from "vue";
import { default as HeatmapChart } from "./charts/heatmap-chart.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({ context: { type: Object, default: () => ({}) } });

const selected_unit   = ref("alerts");
const selected_scheme = ref("orange");
const selected_hours  = ref(24);
const chart_key       = ref(0);

// Refresh forces re-mount of the chart (new key = new fetch)
function refresh_chart() {
  chart_key.value++;
}

// Fetch from the REST endpoint; fall back to generated demo data if endpoint is absent
async function fetch_heatmap_data(hours) {
  try {
    const epoch_end   = Math.floor(Date.now() / 1000);
    const epoch_begin = epoch_end - hours * 3600;
    const ifid        = props.context?.ifid ?? -1;
    const url = `${http_prefix}/lua/rest/v2/get/heatmap/alerts.lua?ifid=${ifid}&epoch_begin=${epoch_begin}&epoch_end=${epoch_end}`;
    const envelope = await ntopng_utility.http_request(url, null, null, true);
    const rsp = envelope?.rsp ?? envelope;
    if (rsp?.data?.length) return rsp.data;
  } catch (_) { /* endpoint not yet available — use demo */ }

  // Demo data: 24h x 10 entities
  return generate_demo(hours);
}

function generate_demo(hours) {
  const now   = Date.now();
  const step  = 3600_000; // 1h buckets
  const rows  = [];
  const entities = [
    "192.168.1.1", "10.0.0.5", "172.16.0.10",
    "192.168.1.50", "10.0.0.20", "172.16.0.1",
    "192.168.2.1",  "10.0.0.100",
  ];
  for (let h = 0; h < hours; h++) {
    const ts = now - (hours - h) * step;
    for (const entity of entities) {
      const spike = (h >= 8 && h <= 10) || (h >= 20 && h <= 22);
      const base  = Math.round(Math.random() * 5);
      const val   = spike ? base + Math.round(Math.random() * 40) : base;
      rows.push({ x: ts, y: entity, value: val });
    }
  }
  return rows;
}

const chart_cfg = computed(() => ({
  unit:          selected_unit.value,
  color_scheme:  selected_scheme.value,
  x_label:       _i18n("time") || "Time",
  y_label:       _i18n("host") || "Host",
  cell_size:     14,
  cell_gap:      2,
  refresh:       0,
  custom_fetch:  () => fetch_heatmap_data(selected_hours.value),
}));

const compact_cfg = computed(() => ({
  unit:          "alerts",
  color_scheme:  "orange",
  cell_size:     10,
  cell_gap:      1,
  refresh:       0,
  custom_fetch:  () => fetch_heatmap_data(24),
}));

const severity_cfg = computed(() => ({
  unit:          "alerts",
  color_scheme:  "red",
  x_label:       _i18n("time") || "Time",
  y_label:       _i18n("severity") || "Severity",
  cell_size:     14,
  cell_gap:      2,
  refresh:       0,
  custom_fetch:  async () => {
    const base = await generate_demo_severity(selected_hours.value);
    return base;
  },
}));

function generate_demo_severity(hours) {
  const now = Date.now();
  const step = 3600_000;
  const severities = ["Critical", "High", "Medium", "Low", "Info"];
  const rows = [];
  for (let h = 0; h < hours; h++) {
    const ts = now - (hours - h) * step;
    for (const sev of severities) {
      const weight = severities.indexOf(sev) + 1; // Critical=1 heaviest
      const spike  = (h >= 9 && h <= 11);
      const base   = Math.round(Math.random() * 3 * weight);
      const val    = spike ? base + Math.round(Math.random() * 30 / weight) : base;
      rows.push({ x: ts, y: sev, value: val });
    }
  }
  return rows;
}
</script>
