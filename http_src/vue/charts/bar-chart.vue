<!--
  (C) 2026 - ntop.org

  D3 bar chart — vertical or horizontal

  chart prop {
    update_url    string
    url_params?   object
    refresh?      number   (ms)
    unit?         string   — passed to formatterUtils.getFormatter(unit, ...)
    label?        string   — i18n label for the unit
    direction?    "vertical" | "horizontal"  (default "vertical")
    stacked?      boolean
    custom_fetch? async (url, params) => rawData
    title?        string
  }

  Server data formats accepted:
    { series:[{name?,data:[]}], xaxis:{categories:[]}, urls?:[] } 
    [{label, value, url?}]                                        
-->
<template>
  <div ref="container" class="bar-container">
    <div v-if="chart.title" class="bar-title"><strong>{{ chart.title }}</strong></div>
    <Loading v-if="!props.hideLoading" :isLoading="loading" />
    <NoData :show="no_data" />
    <div class="bar-body" v-show="!loading && !no_data">
      <div ref="wrapper" class="bar-wrapper"></div>
      <div v-if="series.length > 1" class="bar-legend">
        <div v-for="(s, i) in series" :key="i" class="legend-item">
          <span class="legend-dot" :style="{ background: s.color }"></span>
          <span class="legend-name form-control-sm" :title="s.name">{{ s.name }}</span>
        </div>
      </div>
    </div>

    <div v-if="!loading && tooltip.visible" class="bar-tooltip"
      :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px' }">
      <div v-if="tooltip.label" class="tt-label">{{ tooltip.label }}</div>
      <div v-for="(row, i) in tooltip.rows" :key="i" class="tt-row">
        <span class="tt-dot" :style="{ background: row.color }"></span>
        <span v-if="row.name" class="tt-name">{{ row.name }}</span>
        <span class="tt-val">{{ row.value }}</span>
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

const props = defineProps({
  chart: { type: Object, required: true },
  hideLoading: Boolean,
});

const emit = defineEmits(["chart-updated", "update-requested"]);

/* Resolved once at setup — these don't change during the component lifetime */
const unit      = props.chart.unit  || null;
const label     = props.chart.label || null;
const direction = props.chart.direction || "vertical";
const stacked   = !!props.chart.stacked;
const refresh   = props.chart.refresh || 0;

const formatted_label = label ? ((typeof i18n === "function" ? i18n(label) : null) || label) : null;

const container = ref(null);
const wrapper   = ref(null);
const loading   = ref(false);
const no_data   = ref(false);
const has_loaded = ref(false);
const series    = ref([]);

const tooltip = reactive({ visible: false, x: 0, y: 0, label: "", rows: [] });

let svgEl       = null;
let resizeObs   = null;
let refreshTimer = null;
let currentData = null;

function fmtVal(v) {
  if (unit) return formatterUtils.getFormatter(unit, null, null, formatted_label)(v);
  if (typeof v === "number") return v.toLocaleString();
  return v ?? "";
}

function getMargins(W, cats) {
  if (direction === "horizontal") {
    /* Left margin = full width of the longest label, capped at 40% of width */
    const maxLen  = cats ? Math.max(...cats.map(c => String(c).length)) : 8;
    const perChar = W < 250 ? 6 : 7;
    const left    = Math.min(Math.max(maxLen * perChar, 48), W * 0.40);
    return { top: 8, right: 14, bottom: 30, left };
  }
  /* Vertical: bottom margin must fit longest label (capped at MAX_CHARS=18) rotated at -35°.
     Rotated text projected height ≈ min(len,18) * charW * sin(35°) ≈ len * 4 */
  const maxLen  = cats ? Math.min(Math.max(...cats.map(c => String(c).length)), 18) : 8;
  const bottom  = Math.min(Math.max(maxLen * 4, 36), 80);
  const sampleFmt = fmtVal(1000);
  const leftPx = Math.min(Math.max(sampleFmt.length * 7, 32), 56);
  return { top: 10, right: 10, bottom, left: leftPx };
}

onMounted(async () => {
  await nextTick();
  buildSvg();
  await load();
  if (refresh > 0) refreshTimer = setInterval(load, refresh);
  resizeObs = new ResizeObserver(() => { if (currentData) redraw(currentData); });
  if (wrapper.value) resizeObs.observe(wrapper.value);
});

onBeforeUnmount(() => {
  clearInterval(refreshTimer);
  resizeObs?.disconnect();
});


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
      const res = await ntopng_utility.http_request(`${update_url}${qs}`, null, null, true);
      raw = res?.rsp?.data ?? res?.rsp;
    }
    const parsed = parse(raw);
    if (!parsed || !parsed.categories.length) {
      if (!has_loaded.value) no_data.value = true;
      return;
    }
    no_data.value   = false;
    has_loaded.value = true;
    currentData     = parsed;
    redraw(parsed);
  } catch (e) {
    console.error(`barChart:`, e);
    if (!has_loaded.value) no_data.value = true;
  } finally {
    loading.value = false;
    emit("chart-updated");
  }
}

function parse(raw) {
  /* [{label, value, url?}] — pie-style */
  if (Array.isArray(raw) && raw[0]?.label !== undefined) {
    const data    = raw.filter(d => d.value > 0).sort((a, b) => b.value - a.value);
    const PALETTE = colorUtils.assignRoundRobinColors(data.map(d => d.label));
    return {
      categories: data.map(d => d.label),
      series: [{ name: "", data: data.map(d => d.value), colors: PALETTE, _singleColor: null }],
      urls: data.map(d => d.url || null),
    };
  }
  /* {series:[{name?,data}], xaxis:{categories}, urls?} */
  if (raw?.series && raw?.xaxis?.categories) {
    const allCats = raw.xaxis.categories;
    const srs     = raw.series.filter(s => s.data?.some(v => v > 0));
    if (!srs.length) return null;
    /* Keep only category indices where at least one series has a non-zero value */
    const keepIdx = allCats.map((_, ci) => srs.some(s => (s.data[ci] ?? 0) > 0));
    const cats    = allCats.filter((_, ci) => keepIdx[ci]);
    const PALETTE = colorUtils.assignRoundRobinColors(
      srs.length === 1 ? cats : srs.map(s => s.name)
    );
    return {
      categories: cats,
      series: srs.map((s, i) => ({
        name: s.name || "",
        data: s.data.filter((_, ci) => keepIdx[ci]),
        colors: srs.length === 1 ? PALETTE : Array(cats.length).fill(PALETTE[i]),
        _singleColor: srs.length > 1 ? PALETTE[i] : null,
      })),
      urls: (raw.urls || []).filter((_, ci) => keepIdx[ci]),
    };
  }
  return null;
}

function buildSvg() {
  wrapper.value?.replaceChildren();
  svgEl = d3.select(wrapper.value)
    .append("svg")
    .style("display", "block")
    .style("overflow", "visible");
}

function redraw(d) {
  if (!wrapper.value || !svgEl) return;
  if (direction === "horizontal") drawHorizontal(d);
  else drawVertical(d);

  series.value = d.series.length > 1
    ? d.series.map((s, i) => ({ name: s.name, color: s._singleColor || s.colors[i] }))
    : [];
}

/* Vertical */
function drawVertical(d) {
  const W  = wrapper.value.clientWidth  || 300;
  const H  = wrapper.value.clientHeight || 220;
  if (W < 20 || H < 20) return;

  const M  = getMargins(W, d.categories);
  const iW = Math.max(W - M.left - M.right, 20);
  const iH = Math.max(H - M.top - M.bottom, 20);

  svgEl
    .attr("width",   W)
    .attr("height",  H)
    .attr("viewBox", `0 0 ${W} ${H}`);
  svgEl.selectAll("*").remove();

  const g    = svgEl.append("g").attr("transform", `translate(${M.left},${M.top})`);
  const cats = d.categories;

  const x0 = d3.scaleBand().domain(cats).range([0, iW]).padding(0.28);
  const x1 = d3.scaleBand()
    .domain(d.series.map(s => s.name))
    .range([0, x0.bandwidth()])
    .padding(0.05);

  const maxVal = stacked
    ? d3.max(cats.map((_, ci) => d3.sum(d.series, s => s.data[ci] || 0)))
    : d3.max(d.series, s => d3.max(s.data));
  const y = d3.scaleLinear().domain([0, maxVal || 1]).nice().range([iH, 0]);

  const yTicks = y.ticks(iH < 80 ? 2 : 4);

  /* Grid */
  g.selectAll(".gl").data(yTicks).join("line")
    .attr("class", "gl grid-line")
    .attr("x1", 0).attr("x2", iW)
    .attr("y1", v => y(v)).attr("y2", v => y(v));

  /* Y axis */
  g.append("g")
    .call(d3.axisLeft(y).tickValues(yTicks).tickFormat(fmtVal).tickSizeOuter(0))
    .call(ax => {
      ax.select(".domain").remove();
      ax.selectAll("text").style("font-size", W < 220 ? "9px" : "11px");
    });

  /* X axis — rotate when labels are long or bars are narrow */
  const bw      = x0.bandwidth();
  const maxLbl  = cats.reduce((m, c) => Math.max(m, String(c).length), 0);
  const rotate  = bw < 64 || maxLbl > 10;
  const MAX_CHARS = 18;
  const truncate = s => s.length > MAX_CHARS ? s.slice(0, MAX_CHARS - 1) + "…" : s;
  g.append("g")
    .attr("transform", `translate(0,${iH})`)
    .call(d3.axisBottom(x0).tickSizeOuter(0).tickFormat(rotate ? truncate : d => d))
    .call(ax => {
      ax.select(".domain").remove();
      ax.selectAll("text")
        .style("font-size", W < 220 ? "9px" : "11px")
        .attr("text-anchor", rotate ? "end" : "middle")
        .attr("transform",   rotate ? "rotate(-35)" : null)
        .attr("dx",          rotate ? "-0.4em"      : null)
        .attr("dy",          rotate ? "0.4em"       : "0.9em");
    });

  /* Bars */
  if (stacked) {
    const keys  = d.series.map(s => s.name);
    const stack = d3.stack().keys(keys).value((row, key) => {
      const si = keys.indexOf(key);
      return d.series[si].data[row.ci] || 0;
    });
    const rows   = cats.map((c, ci) => ({ ci }));
    const layers = stack(rows);

    layers.forEach((layer, si) => {
      const color = d.series[si]._singleColor || d.series[si].colors[0];
      g.selectAll(`.ls${si}`).data(layer).join("rect")
        .attr("class", `ls${si}`)
        .attr("x",      (_, j) => x0(cats[j]))
        .attr("width",  x0.bandwidth())
        .attr("y",      seg => y(seg[1]))
        .attr("height", seg => Math.max(0, y(seg[0]) - y(seg[1])))
        .attr("fill",   color).attr("rx", 2)
        .on("mouseover", (ev, seg) => showTooltip(ev, cats[seg.data.ci], d.series, seg.data.ci))
        .on("mousemove", moveTooltip)
        .on("mouseout", () => { tooltip.visible = false; });
    });
  } else {
    d.series.forEach((s, si) => {
      g.selectAll(`.bs${si}`).data(s.data.map((v, i) => ({ v, i }))).join("rect")
        .attr("class", `bs${si}`)
        .attr("x",      ({ i }) => x0(cats[i]) + (d.series.length > 1 ? x1(s.name) : 0))
        .attr("width",  d.series.length > 1 ? x1.bandwidth() : x0.bandwidth())
        .attr("y",      ({ v }) => y(Math.max(v, 0)))
        .attr("height", ({ v }) => Math.max(0, iH - y(Math.max(v, 0))))
        .attr("fill",   ({ i }) => s._singleColor || s.colors[i] || s.colors[0])
        .attr("rx", 2)
        .attr("cursor", ({ i }) => d.urls[i] ? "pointer" : "default")
        .on("mouseover", (ev, { i }) => { showTooltip(ev, cats[i], d.series, i); d3.select(ev.currentTarget).attr("opacity", 0.8); })
        .on("mousemove", moveTooltip)
        .on("mouseout",  ev => { tooltip.visible = false; d3.select(ev.currentTarget).attr("opacity", 1); })
        .on("click",     (_, { i }) => { if (d.urls[i]) window.location.href = d.urls[i]; });
    });
  }
}

/* Horizontal */
function drawHorizontal(d) {
  const cats  = d.categories;
  const W     = wrapper.value.clientWidth || 300;
  if (W < 20) return;

  const M     = getMargins(W, cats);
  const BAR_H = Math.max(12, Math.min(20, W * 0.055));
  const GAP   = Math.max(3, BAR_H * 0.35);
  const iW    = Math.max(W - M.left - M.right, 20);
  const iH    = Math.max(cats.length * (BAR_H + GAP), 20);
  const H     = iH + M.top + M.bottom;

  svgEl
    .attr("width",   W)
    .attr("height",  H)
    .attr("viewBox", `0 0 ${W} ${H}`);
  svgEl.selectAll("*").remove();

  const g = svgEl.append("g").attr("transform", `translate(${M.left},${M.top})`);

  const y = d3.scaleBand().domain(cats).range([0, iH]).padding(0.28);
  const maxVal = d3.max(d.series, s => d3.max(s.data)) || 1;
  const x = d3.scaleLinear().domain([0, maxVal]).nice().range([0, iW]);

  const xTicks = x.ticks(Math.max(2, Math.min(5, Math.floor(iW / 55))));

  /* Grid */
  g.selectAll(".gl").data(xTicks).join("line")
    .attr("class", "gl grid-line")
    .attr("x1", v => x(v)).attr("x2", v => x(v))
    .attr("y1", 0).attr("y2", iH);

  /* X axis (bottom) */
  g.append("g")
    .attr("transform", `translate(0,${iH})`)
    .call(d3.axisBottom(x).tickValues(xTicks).tickFormat(fmtVal).tickSizeOuter(0))
    .call(ax => {
      ax.select(".domain").remove();
      ax.selectAll("text").style("font-size", W < 220 ? "9px" : "11px");
    });

  /* Y axis (category labels) — full label, margin was sized to fit */
  g.append("g")
    .call(d3.axisLeft(y).tickSizeOuter(0))
    .call(ax => {
      ax.select(".domain").remove();
      ax.selectAll("text")
        .style("font-size", W < 220 ? "9px" : "11px")
        .attr("text-anchor", "end");
    });

  /* Bars */
  const y1 = d3.scaleBand()
    .domain(d.series.map(s => s.name))
    .range([0, y.bandwidth()])
    .padding(0.05);

  d.series.forEach((s, si) => {
    g.selectAll(`.bh${si}`).data(s.data.map((v, i) => ({ v, i }))).join("rect")
      .attr("class", `bh${si}`)
      .attr("y",      ({ i }) => y(cats[i]) + (d.series.length > 1 ? y1(s.name) : 0))
      .attr("height", d.series.length > 1 ? y1.bandwidth() : y.bandwidth())
      .attr("x",      0)
      .attr("width",  ({ v }) => Math.max(0, x(v)))
      .attr("fill",   ({ i }) => s._singleColor || s.colors[i] || s.colors[0])
      .attr("rx", 2)
      .attr("cursor", ({ i }) => d.urls?.[i] ? "pointer" : "default")
      .on("mouseover", (ev, { i }) => { showTooltip(ev, cats[i], d.series, i); d3.select(ev.currentTarget).attr("opacity", 0.8); })
      .on("mousemove", moveTooltip)
      .on("mouseout",  ev => { tooltip.visible = false; d3.select(ev.currentTarget).attr("opacity", 1); })
      .on("click",     (_, { i }) => { if (d.urls?.[i]) window.location.href = d.urls[i]; });
  });
}

/* Tooltip */
function showTooltip(ev, cat, srs, ci) {
  const rect = container.value.getBoundingClientRect();
  tooltip.label = cat;
  tooltip.rows  = srs.map(s => ({
    name:  s.name,
    color: s._singleColor || s.colors[ci] || s.colors[0],
    value: fmtVal(s.data[ci] ?? 0),
  }));
  tooltip.x       = ev.clientX - rect.left + 14;
  tooltip.y       = ev.clientY - rect.top  - 12;
  tooltip.visible = true;
}

function moveTooltip(ev) {
  const rect  = container.value.getBoundingClientRect();
  tooltip.x   = ev.clientX - rect.left + 14;
  tooltip.y   = ev.clientY - rect.top  - 12;
}

defineExpose({ update: load });
watch(() => props.chart.url_params, () => load(), { deep: true });
</script>

<style scoped>
.bar-container {
  position: relative;
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  box-sizing: border-box;
  overflow: hidden;
  container-type: inline-size;
}

.bar-title {
  flex-shrink: 0;
  margin-bottom: 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: clamp(11px, 3cqi, 14px);
}

.bar-body {
  flex: 1 1 auto;
  min-height: 0;
  min-width: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* vertical: SVG fills the wrapper exactly */
.bar-wrapper {
  flex: 1 1 auto;
  min-height: 60px;
  min-width: 0;
  overflow: hidden;
  position: relative;
}

.bar-wrapper svg {
  display: block;
}

.bar-legend {
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
  min-width: 0;
}

.legend-dot {
  width: 10px;
  height: 10px;
  border-radius: 3px;
  flex-shrink: 0;
}

.legend-name {
  flex: 1 1 0;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.bar-tooltip {
  position: absolute;
  pointer-events: none;
  background: rgba(10, 10, 10, 0.88);
  color: #fff;
  padding: 6px 10px;
  border-radius: 6px;
  white-space: nowrap;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.45);
  z-index: 100;
  backdrop-filter: blur(4px);
  font-size: 13px;
}

.tt-label {
  font-weight: 600;
  margin-bottom: 3px;
  border-bottom: 1px solid rgba(255,255,255,0.18);
  padding-bottom: 3px;
}

.tt-row {
  display: flex;
  align-items: center;
  gap: 6px;
  line-height: 1.6;
}

.tt-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.tt-name { font-weight: 500; }
.tt-val  { font-weight: 700; margin-left: auto; padding-left: 10px; }

:deep(.grid-line) {
  stroke: rgba(128,128,128,0.18);
  stroke-dasharray: 3 3;
}
:deep(.tick text)  { fill: currentColor; }
:deep(.tick line), :deep(.domain) { stroke: rgba(128,128,128,0.3); }
</style>
