<!--
  (C) 2024 - ntop.org

  PeityChart — Pure D3v7 sparkline display component.

  Mounted by vue_page.template which passes `context` as the root prop.
  context shape (from Lua page_context):
    upload_values    Array<Number>  initial bps history, newest last
    download_values  Array<Number>  initial bps history, newest last
    upload_label     String
    download_label   String
    width            Number   px (default 96)
    height           Number   px (default 24)

  Live updates arrive via window.__peity_update(up_arr, dn_arr, up_label, dn_label)
  which is installed as a queue-proxy in footer.lua BEFORE DOMContentLoaded.
  On mount this component calls window.__peity_register(fn) to hand over control.
-->
<template>
  <div class="info-stats">
    <div class="up d-flex align-items-center gap-1">
      <i class="fas fa-arrow-up"></i>
      <svg ref="svg_up"
           :width="width"
           :height="height"
           style="display:inline-block;vertical-align:middle;" />
      <span class="text-end chart-upload-text" style="min-width:60px">{{ upload_label }}</span>
    </div>
    <div class="down d-flex align-items-center gap-1">
      <i class="fas fa-arrow-down"></i>
      <svg ref="svg_down"
           :width="width"
           :height="height"
           style="display:inline-block;vertical-align:middle;" />
      <span class="text-end chart-download-text" style="min-width:60px">{{ download_label }}</span>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, nextTick } from "vue";

const d3 = d3v7;

/* ── vue_page.template passes everything as a single `context` prop ─────── */
const props = defineProps({
  context: { type: Object, default: () => ({}) },
});

/* ── Reactive state initialised from context ────────────────────────────── */
const svg_up        = ref(null);
const svg_down      = ref(null);
const upload_values  = ref((props.context.upload_values  || []).slice());
const download_values = ref((props.context.download_values || []).slice());
const upload_label   = ref(props.context.upload_label   || "");
const download_label = ref(props.context.download_label || "");
const width          = props.context.width  || 96;
const height         = props.context.height || 24;

/* ── Colours ────────────────────────────────────────────────────────────── */
const UPLOAD_STROKE   = "#ff7f0e";
const UPLOAD_FILL     = "rgba(255,127,14,0.25)";
const DOWNLOAD_STROKE = "#2ca02c";
const DOWNLOAD_FILL   = "rgba(144,238,144,0.4)";

/* ── Draw one sparkline ─────────────────────────────────────────────────── */
function draw(svg_el, data, stroke, fill) {
  if (!svg_el) return;

  const values = (data && data.length >= 2)
    ? data.map(v => Math.abs(+v || 0))
    : Array(2).fill(0);
  const n = values.length;

  const x = d3.scaleLinear().domain([0, n - 1]).range([0, width]);
  const y = d3.scaleLinear().domain([0, d3.max(values) || 1]).range([height, 0]);

  const area_fn = d3.area()
    .x((_, i) => x(i))
    .y0(height)
    .y1(d => y(d))
    .curve(d3.curveMonotoneX);

  const line_fn = d3.line()
    .x((_, i) => x(i))
    .y(d => y(d))
    .curve(d3.curveMonotoneX);

  const svg = d3.select(svg_el);

  let ap = svg.select("path.spark-area");
  if (ap.empty()) ap = svg.append("path").attr("class", "spark-area").attr("stroke", "none");
  ap.attr("fill", fill).attr("d", area_fn(values));

  let lp = svg.select("path.spark-line");
  if (lp.empty()) lp = svg.append("path").attr("class", "spark-line").attr("fill", "none").attr("stroke-width", 1.5);
  lp.attr("stroke", stroke).attr("d", line_fn(values));
}

function redraw() {
  draw(svg_up.value,   upload_values.value,   UPLOAD_STROKE,   UPLOAD_FILL);
  draw(svg_down.value, download_values.value, DOWNLOAD_STROKE, DOWNLOAD_FILL);
}

/* ── Updater called by window.__peity_register handshake ────────────────── */
function apply_update(up_vals, dn_vals, up_lbl, dn_lbl) {
  upload_values.value   = up_vals;
  download_values.value = dn_vals;
  if (up_lbl !== undefined) upload_label.value   = up_lbl;
  if (dn_lbl !== undefined) download_label.value = dn_lbl;
  nextTick(redraw);
}

/* ── Lifecycle ──────────────────────────────────────────────────────────── */
onMounted(() => {
  // Register with the proxy that footer.lua installed before DOMContentLoaded.
  // __peity_register hands over apply_update and immediately flushes any
  // calls that arrived before this component finished mounting.
  if (typeof window.__peity_register === "function") {
    window.__peity_register(apply_update);
  }

  nextTick(redraw);
});

onBeforeUnmount(() => {
  delete window.__peity_register;
  delete window.__peity_update;
});
</script>