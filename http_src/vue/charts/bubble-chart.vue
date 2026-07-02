<!--
  (C) 2026 - ntop.org

  D3 bubble/scatter chart

  Props:
    chart {
      title?          string
      update_url      string
      url_params?     object
      refresh?        number  (ms)
      custom_fetch?   (url, params) => raw_rsp
    }
    hideLoading  boolean

  REST response format accepted (ntopng /lua/pro/rest/v2/charts/host/map.lua):
    {
      series: [{ name, base_url, data: [{x, y, z, meta:{label, url_query}}, ...] }],
      colors: ["rgba(...)"],
      xaxis:  { title: { text }, labels: { ntop_utils_formatter } },
      yaxis:  { title: { text }, labels: { ntop_utils_formatter } },
    }
  Also accepts legacy array format: [{name, data:[{x,y,z}]}]
-->
<template>
  <div ref="container" class="bubble-container">
    <div v-if="chart.title" class="bubble-title"><strong>{{ chart.title }}</strong></div>
    <Loading v-if="!props.hideLoading" :isLoading="loading" />
    <NoData :show="no_data" />
    <div class="bubble-body" v-show="!loading && !no_data">
      <div ref="wrapper" class="bubble-wrapper"></div>
      <div v-if="series.length" class="bubble-legend">
        <div v-for="(s, i) in series" :key="i" class="legend-item">
          <span class="legend-dot" :style="{ background: s.color }"></span>
          <span class="legend-name form-control-sm" :title="s.name">{{ s.name }}</span>
        </div>
      </div>
    </div>

    <div v-if="!loading && tooltip.visible" class="bubble-tooltip"
      :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px', transform: tooltip.flipLeft ? 'translateX(-100%)' : 'none' }">
      <div class="tt-title">{{ tooltip.label }}</div>
      <div class="tt-row">
        <span class="tt-dot" :style="{ background: tooltip.color }"></span>
        <span class="tt-series">{{ tooltip.series }}</span>
      </div>
      <div class="tt-row tt-axis" v-if="tooltip.xTitle">
        <span class="tt-key">{{ tooltip.xTitle }}:</span>
        <span class="tt-val">{{ tooltip.xVal }}</span>
      </div>
      <div class="tt-row tt-axis" v-if="tooltip.yTitle">
        <span class="tt-key">{{ tooltip.yTitle }}:</span>
        <span class="tt-val">{{ tooltip.yVal }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick, watch } from "vue";
import { default as Loading } from "../loading.vue";
import colorUtils from "../../utilities/color-utils.js";
import NtopUtils from "../../utilities/ntop-utils.js";
import NoData from '../components/no-data.vue';

const d3 = d3v7;

const props = defineProps({
  chart: { type: Object, required: true },
  hideLoading: Boolean,
});

const emit = defineEmits(["chart-updated", "update-requested"]);

const container = ref(null);
const wrapper  = ref(null);
const loading  = ref(false);
const no_data  = ref(false);
const has_loaded = ref(false);
const series   = ref([]);

const tooltip = reactive({
  visible: false, x: 0, y: 0, flipLeft: false,
  label: "", series: "", color: "",
  xTitle: "", yTitle: "", xVal: "", yVal: "",
});

let svgEl = null;
let resizeObs = null;
let refreshTimer = null;
let currentData = null;
/* axis meta kept for tooltip */
let _xTitle = "", _yTitle = "", _fmtX = null, _fmtY = null;

const M = { top: 20, right: 24, bottom: 64, left: 80 };

onMounted(async () => {
  await nextTick();
  buildSvg();
  await load();
  const { refresh } = props.chart;
  if (refresh > 0) refreshTimer = setInterval(load, refresh);
  resizeObs = new ResizeObserver(() => { if (currentData) redraw(currentData); });
  resizeObs.observe(wrapper.value);
});

onBeforeUnmount(() => {
  clearInterval(refreshTimer);
  resizeObs?.disconnect();
});

/* Fetch */
async function load() {
  if (!has_loaded.value) loading.value = true;
  const { update_url, url_params, custom_fetch } = props.chart;
  emit("update-requested");
  try {
    let raw;
    if (custom_fetch) {
      raw = await custom_fetch(update_url, url_params);
    } else {
      const qs = url_params && Object.keys(url_params).length
        ? `?${new URLSearchParams(url_params)}` : "";
      raw = await ntopng_utility.http_request(`${update_url}${qs}`, null, null, true);
    }
    /* unwrap { rc, rsp } envelope */
    const rsp = raw?.rsp ?? raw;
    const parsed = parse(rsp);
    if (!parsed?.length) {
      if (!has_loaded.value) no_data.value = true;
      return;
    }
    no_data.value = false;
    has_loaded.value = true;
    currentData = parsed;
    redraw(parsed);
  } catch (e) {
    console.error(`bubbleChart:`, e);
    if (!has_loaded.value) no_data.value = true;
  } finally {
    loading.value = false;
    emit("chart-updated");
  }
}

function resolveFormatter(name) {
  if (!name) return v => (v == null ? "-" : NtopUtils.fint(v));
  return NtopUtils[name] ?? (v => v);
}

function stripAlpha(c) {
  /* #rrggbbaa → #rrggbb */
  if (c && /^#[0-9a-fA-F]{8}$/.test(c)) return c.slice(0, 7);
  /* rgba(r,g,b,a) → rgb(r,g,b) */
  if (c) return c.replace(/rgba?\(([^,]+,[^,]+,[^,]+)(?:,[^)]+)?\)/, 'rgb($1)');
  return c;
}

function parse(rsp) {
  if (!rsp) return null;
  const srs = rsp.series ?? (Array.isArray(rsp) ? rsp : null);
  if (!srs?.length) return null;

  /* Store axis meta for tooltip / axis labels — fall back to chart prop */
  _xTitle = rsp.xaxis?.title?.text ?? props.chart.x_label ?? "";
  _yTitle = rsp.yaxis?.title?.text ?? props.chart.y_label ?? "";
  _fmtX   = resolveFormatter(rsp.xaxis?.labels?.ntop_utils_formatter);
  _fmtY   = resolveFormatter(rsp.yaxis?.labels?.ntop_utils_formatter);

  const PALETTE = colorUtils.assignRoundRobinColors(srs.map(s => s.name ?? ""));

  return srs.map((s, i) => ({
    name:     s.name ?? `S${i}`,
    base_url: s.base_url ?? null,
    color:    stripAlpha(rsp.colors?.[i]) ?? PALETTE[i],
    data:     s.data ?? [],
  }));
}

function buildSvg() {
  wrapper.value?.replaceChildren();
  svgEl = d3.select(wrapper.value).append("svg")
    .attr("width", "100%").attr("height", "100%")
    .style("display", "block").style("overflow", "visible");
}

function redraw(srs) {
  if (!wrapper.value || !svgEl) return;

  const W = wrapper.value.clientWidth  || 400;
  const H = wrapper.value.clientHeight || 280;
  const iW = W - M.left - M.right;
  const iH = H - M.top  - M.bottom;
  if (iW <= 0 || iH <= 0) return;

  svgEl.attr("viewBox", `0 0 ${W} ${H}`).attr("height", H);
  svgEl.selectAll("*").remove();

  const g = svgEl.append("g").attr("transform", `translate(${M.left},${M.top})`);

  const allPts = srs.flatMap(s => s.data);
  if (!allPts.length) return;

  const xExt = d3.extent(allPts, d => d.x);
  const yExt = d3.extent(allPts, d => d.y);
  const xScale = d3.scaleLinear().domain([Math.min(0, xExt[0]), xExt[1]]).nice().range([0, iW]);
  const yScale = d3.scaleLinear().domain([Math.min(0, yExt[0]), yExt[1]]).nice().range([iH, 0]);
  const zMax   = d3.max(allPts, d => d.z ?? 1) || 1;
  const rScale = d3.scaleSqrt().domain([0, zMax]).range([4, Math.min(28, iW / 10)]);

  /* Grid */
  const nX = Math.max(2, Math.min(6, Math.floor(iW / 80)));
  const nY = Math.max(2, Math.min(5, Math.floor(iH / 40)));

  g.selectAll(".gl-x").data(xScale.ticks(nX)).join("line").attr("class", "gl-x grid-line")
    .attr("x1", v => xScale(v)).attr("x2", v => xScale(v)).attr("y1", 0).attr("y2", iH);
  g.selectAll(".gl-y").data(yScale.ticks(nY)).join("line").attr("class", "gl-y grid-line")
    .attr("x1", 0).attr("x2", iW).attr("y1", v => yScale(v)).attr("y2", v => yScale(v));

  /* X axis */
  const axX = g.append("g").attr("transform", `translate(0,${iH})`);
  axX.call(d3.axisBottom(xScale).ticks(nX).tickFormat(_fmtX).tickSizeOuter(0));
  axX.select(".domain").style("stroke", "var(--loading-text-color)");
  axX.selectAll(".tick line").style("stroke", "var(--loading-text-color)");
  axX.selectAll(".tick text").style("fill", "var(--loading-text-color)").style("font-size", "11px");
  if (_xTitle) {
    axX.append("text")
      .attr("x", iW / 2).attr("y", 48)
      .attr("text-anchor", "middle")
      .style("fill", "var(--loading-text-color)").style("font-size", "12px").style("font-weight", "600")
      .text(_xTitle);
  }

  /* Y axis */
  const axY = g.append("g");
  axY.call(d3.axisLeft(yScale).ticks(nY).tickFormat(_fmtY).tickSizeOuter(0));
  axY.select(".domain").style("stroke", "var(--loading-text-color)");
  axY.selectAll(".tick line").style("stroke", "var(--loading-text-color)");
  axY.selectAll(".tick text").style("fill", "var(--loading-text-color)").style("font-size", "11px");
  if (_yTitle) {
    axY.append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -iH / 2).attr("y", -M.left + 16)
      .attr("text-anchor", "middle")
      .style("fill", "var(--loading-text-color)").style("font-size", "12px").style("font-weight", "600")
      .text(_yTitle);
  }

  /* Bubbles */
  srs.forEach(s => {
    g.selectAll(null).data(s.data).join("circle")
      .attr("cx", d => xScale(d.x))
      .attr("cy", d => yScale(d.y))
      .attr("r",  d => rScale(d.z ?? 1))
      .attr("fill", s.color)
      .attr("fill-opacity", 0.65)
      .attr("stroke", s.color)
      .attr("stroke-width", 1.5)
      .style("cursor", d => d.meta?.url_query ? "pointer" : "default")
      .on("mouseover", function(ev, d) {
        d3.select(this).attr("fill-opacity", 0.92).attr("stroke-width", 2.5);
        const rect = container.value.getBoundingClientRect();
        const cx = ev.clientX - rect.left;
        const cy = ev.clientY - rect.top;
        const flipLeft = cx > rect.width / 2;
        Object.assign(tooltip, {
          visible:  true,
          x:        cx + (flipLeft ? -14 : 14),
          y:        cy - 10,
          flipLeft,
          label:    d.meta?.label ?? "",
          series:   s.name,
          color:    s.color,
          xTitle:   _xTitle,
          yTitle:   _yTitle,
          xVal:     _fmtX(d.x),
          yVal:     _fmtY(d.y),
        });
      })
      .on("mousemove", function(ev) {
        const rect = container.value.getBoundingClientRect();
        const cx = ev.clientX - rect.left;
        const cy = ev.clientY - rect.top;
        const flipLeft = cx > rect.width / 2;
        tooltip.x = cx + (flipLeft ? -14 : 14);
        tooltip.y = cy - 10;
        tooltip.flipLeft = flipLeft;
      })
      .on("mouseout", function(ev) {
        d3.select(this).attr("fill-opacity", 0.65).attr("stroke-width", 1.5);
        tooltip.visible = false;
      })
      .on("click", function(ev, d) {
        if (d.meta?.url_query && s.base_url) {
          window.location.href = `${http_prefix}${s.base_url}?${d.meta.url_query}`;
        }
      });
  });

  series.value = srs.map(s => ({ name: s.name, color: s.color }));
}

defineExpose({ update: load });
watch(() => props.chart, () => load(), { deep: true });
</script>

<style scoped>
.bubble-container {
  position: relative;
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  min-width: 0;
  box-sizing: border-box;
}

.bubble-title {
  flex-shrink: 0;
  margin-bottom: 4px;
}

.bubble-body {
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.bubble-wrapper {
  flex: 1 1 auto;
  min-height: 120px;
  overflow: hidden;
}

.bubble-legend {
  flex-shrink: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 6px 12px;
  padding: 6px 4px 0;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 5px;
}

.legend-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.legend-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.bubble-tooltip {
  position: absolute;
  pointer-events: none;
  display: flex;
  flex-direction: column;
  gap: 4px;
  background: rgba(10, 10, 10, 0.88);
  color: #fff;
  padding: 7px 12px 7px 10px;
  border-radius: 8px;
  white-space: nowrap;
  box-shadow: 0 4px 14px rgba(0,0,0,0.45);
  z-index: 100;
  backdrop-filter: blur(6px);
  font-size: 13px;
}

.tt-title {
  font-weight: 700;
  font-size: 12px;
  opacity: 0.9;
  margin-bottom: 2px;
}

.tt-row {
  display: flex;
  align-items: center;
  gap: 6px;
}

.tt-axis {
  font-size: 12px;
}

.tt-key {
  opacity: 0.7;
}

.tt-val {
  font-weight: 700;
}

.tt-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.tt-series { font-weight: 500; }

:deep(.grid-line) {
  stroke: rgba(128,128,128,0.15);
  stroke-dasharray: 3 3;
}
:deep(.tick text) { fill: currentColor; font-size: 11px; }
:deep(.tick line), :deep(.domain) { stroke: rgba(128,128,128,0.3); }
</style>
