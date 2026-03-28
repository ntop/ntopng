<!--
  (C) 2026 - ntop.org
-->
<template>
  <div ref="container" class="line-container">
    <div v-if="chart.title" class="line-title"><strong>{{ chart.title }}</strong></div>
    <Loading v-if="!props.hideLoading" :isLoading="loading" />
    <NoData :show="no_data"></NoData>
    <div class="line-body">
      <div ref="wrapper" class="line-wrapper" v-show="!loading && !no_data"></div>
      <div v-if="!loading && tooltip.visible" class="line-tooltip"
        :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px' }">
        <span v-if="tooltip.series" class="tt-series">{{ tooltip.series }}</span>
        <span v-if="tooltip.series" class="tt-sep">·</span>
        <span class="tt-val">{{ tooltip.value }}</span>
      </div>
    </div>
    <div v-if="!loading && series.length && !no_data" class="line-legend">
      <div v-for="(s, i) in series" :key="i" class="legend-item"
        :class="{ dimmed: hiddenSeries.has(s.label) }" @click="toggleSeries(s.label)">
        <svg class="legend-line-icon" viewBox="0 0 24 12">
          <line x1="0" y1="6" x2="24" y2="6" :stroke="s.color" stroke-width="2.5" stroke-linecap="round"/>
          <circle cx="12" cy="6" r="3" :fill="s.color"/>
        </svg>
        <span class="legend-name form-control-sm" :title="s.label">{{ s.label }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick, watch } from "vue";
import { default as Loading } from "../loading.vue";
import colorUtils from "../../utilities/color-utils.js";
import formatterUtils from "../../utilities/formatter-utils.js";
import NoData from '../components/no-data.vue';

const d3 = d3v7;

const props = defineProps({ chart: { type: Object, required: true }, hideLoading: Boolean });
const { refresh, unit, label, custom_fetch } = props.chart;
const formatted_label = label ? (i18n(label) || label) : null;

const container  = ref(null);
const wrapper    = ref(null);
const loading    = ref(false);
const no_data    = ref(false);
const series     = ref([]);
const has_loaded = ref(false);
const hiddenSeries = ref(new Set());
const emit = defineEmits(["chart-updated", "update-requested"]);
const tooltip = reactive({ visible: false, x: 0, y: 0, series: "", value: "" });

const M = { top: 16, right: 20, bottom: 52, left: 56 };

let svgEl       = null;
let gChart      = null;
let xScale      = null;
let yScale      = null;
let clipId      = null;
let currentData = null;
let refreshTimer = null;
let isUnixTs    = false;
let isDateAxis  = false;
let parseX      = null;
let iW_last     = 0;
let iH_last     = 0;
let fmtDate_last = null;

let hoverLine   = null;
let hoverDots   = [];
let hoverXLabel = null;
let resizeObs   = null;

/* ── Lifecycle ── */
onMounted(async () => {
  await nextTick();
  resizeObs = new ResizeObserver(() => { if (currentData) renderChart(currentData); });
  resizeObs.observe(wrapper.value);
  buildSVG();
  await load();
  if (refresh > 0) refreshTimer = setInterval(load, refresh);
});

onBeforeUnmount(() => {
  clearInterval(refreshTimer);
  resizeObs?.disconnect();
});

/* ── SVG scaffold ── */
function buildSVG() {
  if (!wrapper.value) return;
  wrapper.value.replaceChildren();
  clipId = `clip-${Math.random().toString(36).slice(2)}`;

  svgEl = d3.select(wrapper.value)
    .append("svg")
    .attr("width", "100%")
    .attr("height", "100%")
    .style("display", "block");

  svgEl.append("defs").append("clipPath").attr("id", clipId).append("rect");
  svgEl.append("g").attr("class", "grid-y");
  gChart = svgEl.append("g").attr("class", "chart-area").attr("clip-path", `url(#${clipId})`);
  svgEl.append("g").attr("class", "axis-x");
  svgEl.append("g").attr("class", "axis-y");
  /* Overlay on top — captures mouse, same transform as gChart */
  svgEl.append("rect").attr("class", "mouse-overlay")
    .attr("fill", "transparent")
    .attr("stroke", "none");
}

/* ── Data fetch ── */
async function load() {
  if (!has_loaded.value) loading.value = true;
  const { update_url, url_params, custom_fetch } = props.chart;
  emit("update-requested");
  try {
    let data;
    if (custom_fetch) {
      data = await custom_fetch(update_url, url_params);
    } else {
      const url = url_params && Object.keys(url_params).length
        ? `${update_url}?${new URLSearchParams(url_params)}`
        : update_url;
      const res = await ntopng_utility.http_request(url, null, null, true);
      data = res?.rsp?.data || res?.rsp;
    }
    if (!data || (Array.isArray(data) && !data.length)) {
      if (!has_loaded.value) no_data.value = true; return;
    }
    const norm = normaliseData(data);
    if (!norm.length) { if (!has_loaded.value) no_data.value = true; return; }
    no_data.value    = false;
    has_loaded.value = true;
    currentData      = norm;
    renderChart(norm);
  } catch (e) {
    console.error(`lineChart-${props.chart.name}:`, e);
    if (!has_loaded.value) no_data.value = true;
  } finally {
    loading.value = false;
    emit("chart-updated");
  }
}

function normaliseData(raw) {
  if (raw.length && raw[0].data && Array.isArray(raw[0].data)) return raw;
  if (raw.length && "y" in raw[0]) return [{ label: formatted_label || "", data: raw }];
  return [];
}

/* ── Render ── */
function renderChart(data) {
  if (!wrapper.value || !svgEl) return;

  const W  = wrapper.value.clientWidth  || 400;
  const H  = wrapper.value.clientHeight || 220;
  const iW = W - M.left - M.right;
  const iH = H - M.top  - M.bottom;
  if (iW <= 0 || iH <= 0) return;
  iW_last = iW;
  iH_last = iH;

  /* Colours */
  const PALETTE = colorUtils.assignRoundRobinColors(data.map(s => s.label));
  series.value  = data.map((s, i) => ({
    label: s.label, color: s.color || PALETTE[i % PALETTE.length], url: s.url || null,
  }));
  const getColor = (s, i) => series.value[i]?.color || PALETTE[i % PALETTE.length];

  const vis  = data.filter(s => !hiddenSeries.value.has(s.label));
  const allX = vis.flatMap(s => s.data.map(d => d.x));
  const allY = vis.flatMap(s => s.data.map(d => d.y));
  if (!allX.length) return;

  /* X type detection */
  isUnixTs   = typeof allX[0] === "number" && allX[0] > 1_000_000_000;
  isDateAxis = isUnixTs || allX[0] instanceof Date
    || (typeof allX[0] === "string" && !isNaN(Date.parse(allX[0])));
  const isOrd = !isDateAxis && typeof allX[0] === "string";

  parseX = isUnixTs    ? v => new Date(+v * 1000)
         : isDateAxis  ? v => (v instanceof Date ? v : new Date(v))
         : isOrd       ? v => v
         :               v => +v;

  const xVals = allX.map(parseX);
  xScale = isOrd       ? d3.scalePoint().domain([...new Set(xVals)]).range([0, iW]).padding(0.5)
         : isDateAxis  ? d3.scaleTime().domain(d3.extent(xVals)).range([0, iW]).nice()
         :               d3.scaleLinear().domain(d3.extent(xVals)).range([0, iW]).nice();

  const yMin = Math.min(0, d3.min(allY));
  const yMax = d3.max(allY);
  yScale = d3.scaleLinear().domain([yMin, yMax]).range([iH, 0]).nice();

  /* SVG size */
  svgEl.attr("viewBox", `0 0 ${W} ${H}`);
  svgEl.select(`#${clipId} rect`).attr("width", iW).attr("height", iH + 4);

  /* All groups share the same (M.left, M.top) offset */
  const tx = `translate(${M.left},${M.top})`;
  gChart.attr("transform", tx);
  svgEl.select(".grid-y").attr("transform", tx);

  /* Axes are shifted: x-axis goes to bottom of chart area */
  svgEl.select(".axis-x").attr("transform", `translate(${M.left},${M.top + iH})`);
  svgEl.select(".axis-y").attr("transform", `translate(${M.left},${M.top})`);

  /* Overlay exactly covers the chart area */
  svgEl.select(".mouse-overlay")
    .attr("x", M.left).attr("y", M.top)
    .attr("width", iW).attr("height", iH);

  /* Date formatter — expects ms */
  fmtDate_last = v => {
    const ms = v instanceof Date ? v.getTime() : (isUnixTs ? +v * 1000 : +v);
    return formatterUtils.getFormatter('date')(ms);
  };

  /* ── X Axis ── */
  const nXTicks = Math.max(2, Math.min(6, Math.floor(iW / 90)));
  const xAxisFn = isOrd
    ? d3.axisBottom(xScale).tickSizeOuter(0).tickSize(5)
    : isDateAxis
      ? d3.axisBottom(xScale).ticks(nXTicks).tickSizeOuter(0).tickSize(5).tickFormat(fmtDate_last)
      : d3.axisBottom(xScale).ticks(nXTicks).tickSizeOuter(0).tickSize(5);

  const axX = svgEl.select(".axis-x");
  axX.call(xAxisFn);
  /* Remove D3 default stroke:none on domain by forcing attr (not style) */
  axX.select("path.domain")
    .attr("stroke", "var(--color-border-secondary)")
    .attr("stroke-width", "1")
    .attr("fill", "none");
  axX.selectAll(".tick line")
    .attr("stroke", "var(--color-border-secondary)")
    .attr("stroke-width", "1");
  axX.selectAll(".tick text")
    .attr("fill", "var(--color-text-secondary)")
    .attr("font-size", "11px");

  /* ── Y Axis ── */
  const nYTicks = Math.max(2, Math.min(5, Math.floor(iH / 40)));
  const valFmt  = unit ? formatterUtils.getFormatter(unit, null, null, formatted_label) : d3.format("~s");
  const yAxisFn = d3.axisLeft(yScale).ticks(nYTicks).tickFormat(valFmt).tickSizeOuter(0).tickSize(5);

  const axY = svgEl.select(".axis-y");
  axY.call(yAxisFn);
  axY.select("path.domain")
    .attr("stroke", "var(--color-border-secondary)")
    .attr("stroke-width", "1")
    .attr("fill", "none");
  axY.selectAll(".tick line")
    .attr("stroke", "var(--color-border-secondary)")
    .attr("stroke-width", "1");
  axY.selectAll(".tick text")
    .attr("fill", "var(--color-text-secondary)")
    .attr("font-size", "11px");

  /* ── Grid lines ── */
  const gridData = yScale.ticks(nYTicks);
  const gridSel  = svgEl.select(".grid-y").selectAll("line.gl").data(gridData);
  gridSel.enter().append("line").attr("class", "gl").merge(gridSel)
    .attr("x1", 0).attr("x2", iW)
    .attr("y1", d => yScale(d)).attr("y2", d => yScale(d))
    .attr("stroke", "var(--color-border-tertiary)")
    .attr("stroke-width", "0.5");
  gridSel.exit().remove();

  /* ── Line / area generators ── */
  const lineGen = d3.line()
    .x(d => xScale(parseX(d.x))).y(d => yScale(d.y))
    .defined(d => d.y != null && !isNaN(d.y)).curve(d3.curveMonotoneX);
  const areaGen = d3.area()
    .x(d => xScale(parseX(d.x))).y0(yScale(Math.max(yMin, 0))).y1(d => yScale(d.y))
    .defined(d => d.y != null && !isNaN(d.y)).curve(d3.curveMonotoneX);

  /* Areas */
  const areas = gChart.selectAll("path.area-fill").data(data, d => d.label);
  areas.enter().append("path").attr("class", "area-fill").attr("stroke", "none")
    .merge(areas)
    .attr("d", s => areaGen(s.data))
    .attr("fill", (s, i) => getColor(s, i))
    .attr("opacity", s => hiddenSeries.value.has(s.label) ? 0 : 0.08);
  areas.exit().remove();

  /* Lines */
  const lines = gChart.selectAll("path.line-path").data(data, d => d.label);
  lines.enter().append("path").attr("class", "line-path").attr("fill", "none")
    .attr("stroke-linejoin", "round").attr("stroke-linecap", "round")
    .merge(lines)
    .attr("d", s => lineGen(s.data))
    .attr("stroke", (s, i) => getColor(s, i))
    .attr("stroke-width", "2")
    .attr("opacity", s => hiddenSeries.value.has(s.label) ? 0.12 : 1);
  lines.exit().remove();

  /* Static dots */
  const DOT_THRESH = 30;
  const dg = gChart.selectAll("g.dg").data(data, d => d.label);
  dg.enter().append("g").attr("class", "dg").merge(dg).each(function(s, si) {
    const g      = d3.select(this);
    const color  = getColor(s, si);
    const hidden = hiddenSeries.value.has(s.label);
    const valid  = s.data.filter(d => d.y != null && !isNaN(d.y));
    const pts    = valid.length <= DOT_THRESH ? valid : (valid.length ? [valid[valid.length - 1]] : []);
    const c = g.selectAll("circle.sd").data(pts, d => d.x);
    c.enter().append("circle").attr("class", "sd").merge(c)
      .attr("r",  valid.length <= DOT_THRESH ? 3.5 : 4)
      .attr("cx", d => xScale(parseX(d.x)))
      .attr("cy", d => yScale(d.y))
      .attr("fill", color)
      .attr("stroke", "var(--color-background-primary)")
      .attr("stroke-width", "1.5")
      .attr("opacity", hidden ? 0 : 1);
    c.exit().remove();
  });
  dg.exit().remove();

  /* Mouse handler */
  svgEl.select(".mouse-overlay")
    .on("mousemove", function(ev) { onMove(ev, data, iH); })
    .on("mouseleave", onLeave);
}

/* ── Mouse ── */
function clearHover() {
  hoverLine?.remove();   hoverLine   = null;
  hoverXLabel?.remove(); hoverXLabel = null;
  hoverDots.forEach(d => d.remove()); hoverDots = [];
}

function onLeave() { tooltip.visible = false; clearHover(); }

function onMove(ev, data, iH) {
  /* Use the SVG element as reference for d3.pointer.
     This gives coords in SVG viewBox space.
     Subtract M.left/M.top to get chart-area (gChart) space. */
  const svgNode = svgEl.node();
  const [svgX, svgY] = d3.pointer(ev, svgNode);
  const cx = svgX - M.left;   /* x in chart space */
  const cy = svgY - M.top;    /* y in chart space */

  if (cx < 0 || cx > iW_last || cy < 0 || cy > iH) return;

  const vis = data.filter(s => !hiddenSeries.value.has(s.label));
  if (!vis.length) return;

  /* Nearest data point by X pixel distance */
  let bestDx = Infinity, snapPx = null, snapRaw = null;
  vis.forEach(s => {
    s.data.forEach(d => {
      const px = xScale(parseX(d.x));
      const dx = Math.abs(px - cx);
      if (dx < bestDx) { bestDx = dx; snapPx = px; snapRaw = d.x; }
    });
  });
  if (snapPx === null) return;

  clearHover();

  /* Vertical line at MOUSE x (cx), in gChart space */
  hoverLine = gChart.append("line")
    .attr("x1", cx).attr("x2", cx).attr("y1", 0).attr("y2", iH)
    .attr("stroke", "var(--color-border-primary)")
    .attr("stroke-width", "1")
    .attr("stroke-dasharray", "3 3")
    .attr("pointer-events", "none");

  /* X axis label at snapped point — appended to axis-x group (coords relative to that group) */
  const labelTxt = isDateAxis ? fmtDate_last(snapRaw) : String(snapRaw);
  hoverXLabel = svgEl.select(".axis-x").append("g").attr("class", "hxl");
  hoverXLabel.append("line")
    .attr("x1", snapPx).attr("x2", snapPx).attr("y1", 0).attr("y2", 6)
    .attr("stroke", "var(--color-text-primary)").attr("stroke-width", "1.5");
  hoverXLabel.append("text")
    .attr("x", snapPx).attr("y", 20)
    .attr("text-anchor", "middle")
    .attr("fill", "var(--color-text-primary)")
    .attr("font-size", "11").attr("font-weight", "700")
    .text(labelTxt);

  /* Dots at snapped data point, in gChart space */
  vis.forEach(s => {
    const pt = s.data.find(d => String(d.x) === String(snapRaw));
    if (!pt || pt.y == null || isNaN(pt.y)) return;
    const color = series.value.find(sv => sv.label === s.label)?.color || "#888";
    hoverDots.push(
      gChart.append("circle")
        .attr("cx", snapPx)          /* snap to data point x */
        .attr("cy", yScale(pt.y))    /* exact y from scale */
        .attr("r", 5)
        .attr("fill", color)
        .attr("stroke", "var(--color-background-primary)")
        .attr("stroke-width", "2")
        .attr("pointer-events", "none")
    );
  });

  /* Tooltip — series closest in Y to cursor */
  let closeS = null, closePt = null, minDY = Infinity;
  vis.forEach(s => {
    const pt = s.data.find(d => String(d.x) === String(snapRaw));
    if (!pt || pt.y == null) return;
    const dy = Math.abs(yScale(pt.y) - cy);
    if (dy < minDY) { minDY = dy; closeS = s; closePt = pt; }
  });
  if (!closePt) return;

  const valFmt = unit ? formatterUtils.getFormatter(unit, null, null, formatted_label) : v => v;
  const rect   = container.value.getBoundingClientRect();
  Object.assign(tooltip, {
    visible: true,
    x: ev.clientX - rect.left + 14,
    y: ev.clientY - rect.top  - 12,
    series: closeS.label,
    value:  valFmt(closePt.y),
  });
}

/* ── Toggle / expose / watch ── */
function toggleSeries(label) {
  const n = new Set(hiddenSeries.value);
  n.has(label) ? n.delete(label) : n.add(label);
  hiddenSeries.value = n;
  if (currentData) renderChart(currentData);
}

defineExpose({ update: async () => { await load(); } });
watch(() => props.chart.url_params, () => { load(); }, { deep: true });
</script>

<style scoped>
.line-container {
  position: relative; display: flex; flex-direction: column;
  align-items: stretch; width: 100%; height: 100%;
  min-width: 0; box-sizing: border-box;
}
.line-title {
  flex-shrink: 0; margin-bottom: 4px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.line-body {
  display: flex; flex-direction: column; align-items: stretch;
  flex: 1 1 auto; min-height: 0; width: 100%; height: 100%; position: relative;
}
.line-wrapper { flex: 1 1 auto; min-height: 0; width: 100%; height: 100%; overflow: hidden; }
.line-legend {
  flex-shrink: 0; display: flex; flex-direction: row; flex-wrap: wrap;
  align-items: center; gap: 4px 12px; padding: 6px 0 2px; overflow: hidden;
}
.legend-item {
  display: flex; align-items: center; gap: 5px; min-width: 0;
  cursor: pointer; user-select: none; transition: opacity 0.25s ease;
}
.legend-item.dimmed { opacity: 0.35; }
.legend-line-icon   { width: 24px; height: 12px; flex-shrink: 0; }
.legend-name        { flex: 1 1 0; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.line-tooltip {
  position: absolute; pointer-events: none; display: flex; align-items: center; gap: 6px;
  background: rgba(10,10,10,0.85); color: #fff; padding: 5px 10px 5px 8px;
  border-radius: 6px; white-space: nowrap; box-shadow: 0 2px 10px rgba(0,0,0,0.4);
  z-index: 100; backdrop-filter: blur(4px);
}
.tt-series { font-weight: 500; }
.tt-sep    { opacity: 0.45; }
.tt-val    { font-weight: 700; }
</style>