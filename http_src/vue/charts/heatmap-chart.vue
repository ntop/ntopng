<!--
  (C) 2024 - ntop.org

  Props:
    chart: {
      title: string | null,
      unit: string,          // formatter-utils unit (e.g. "alerts", "number")
      x_label: string | null,
      y_label: string | null,
      custom_fetch: async () => [{ x: epoch_ms, y: string, value: number }, ...],
      refresh: number,       // ms refresh interval (0 = no refresh)
      color_scheme: string,  // "orange" | "blue" | "green" | "red" (default "orange")
      cell_size: number,     // px (default 14)
      cell_gap: number,      // px (default 2)
    }
-->
<template>
  <div ref="container" class="heatmap-container">
    <Loading v-if="!props.hideLoading" :isLoading="loading" />
    <NoData :show="no_data" />
    <div v-show="!loading && !no_data" class="heatmap-body">
      <div ref="wrapper" class="heatmap-wrapper"></div>
      <!-- Tooltip rendered in Vue for theme-awareness -->
      <div
        v-if="tooltip.visible"
        class="d3-tooltip heatmap-tooltip"
        :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px', transform: tooltip.flip ? 'translateX(-105%)' : 'none' }"
      >
        <div class="tt-time">{{ tooltip.time }}</div>
        <div class="tt-row mt-1">
          <span class="tt-series fw-semibold">{{ tooltip.y_label }}</span>
        </div>
        <div class="tt-row">
          <span class="tt-val">{{ tooltip.value }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick, watch } from "vue";
import { default as Loading } from "../loading.vue";
import { default as NoData } from "../components/no-data.vue";
import formatterUtils from "../../utilities/formatter-utils.js";

const d3 = d3v7;

const _i18n = (t) => i18n(t);

const props = defineProps({
  chart: { type: Object, required: true },
  hideLoading: { type: Boolean, default: false },
});

const container = ref(null);
const wrapper = ref(null);
const loading = ref(false);
const no_data = ref(false);
const has_loaded = ref(false);

const tooltip = reactive({
  visible: false, x: 0, y: 0, flip: false,
  time: "", y_label: "", value: "",
});

// Internal state
let svgEl = null;
let currentData = null;
let refreshTimer = null;
let resizeObs = null;
let fmtValue = null;

const MARGIN = { top: 20, right: 20, bottom: 50, left: 90 };
const DEFAULT_CELL = 14;
const DEFAULT_GAP = 2;

// Color palettes — [low, high] — plain hex or CSS var (both resolved at render time)
const PALETTES = {
  orange: ["var(--bg-elevated)", "var(--ntop-orange)"],
  blue:   ["var(--bg-elevated)", "#37a4d8"],
  green:  ["var(--bg-elevated)", "#2ea44f"],
  red:    ["var(--bg-elevated)", "#da3633"],
};

onMounted(async () => {
  await nextTick();
  fmtValue = formatterUtils.getFormatter(props.chart.unit ?? "number");

  resizeObs = new ResizeObserver(() => { if (currentData) render(currentData); });
  resizeObs.observe(wrapper.value);

  themeObs = new MutationObserver(() => { if (currentData) render(currentData); });
  themeObs.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });

  await load();
  if ((props.chart.refresh ?? 0) > 0) {
    refreshTimer = setInterval(load, props.chart.refresh);
  }
});

onBeforeUnmount(() => {
  clearInterval(refreshTimer);
  resizeObs?.disconnect();
  themeObs?.disconnect();
});

async function load() {
  if (!has_loaded.value) loading.value = true;
  let raw = null;
  try {
    raw = await props.chart.custom_fetch();
    if (!raw?.length) {
      if (!has_loaded.value) no_data.value = true;
      return;
    }
    no_data.value = false;
    has_loaded.value = true;
    currentData = raw;
  } catch (e) {
    console.error("HeatmapChart:", e);
    if (!has_loaded.value) no_data.value = true;
  } finally {
    loading.value = false;
  }
  // Render after loading=false so wrapper is visible and has layout width
  if (raw?.length) {
    await nextTick();
    render(raw);
  }
}

function resolveColor(val) {
  // Resolve CSS variable to hex/rgb; pass plain hex/rgb straight through
  if (!val.startsWith("var(")) return val;
  const name = val.replace(/^var\(/, "").replace(/\)$/, "").trim();
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || val;
}

function render(data) {
  if (!wrapper.value) return;
  wrapper.value.replaceChildren();

  const scheme = props.chart.color_scheme ?? "orange";
  const palette = PALETTES[scheme] ?? PALETTES.orange;
  const CELL = props.chart.cell_size ?? DEFAULT_CELL;
  const GAP = props.chart.cell_gap ?? DEFAULT_GAP;
  const STEP = CELL + GAP;

  // Derive unique sorted x-bins (timestamps) and y-bins (string labels)
  const xs = [...new Set(data.map(d => d.x))].sort((a, b) => a - b);
  const ys = [...new Set(data.map(d => d.y))];

  const W_AVAIL = wrapper.value.clientWidth || 600;
  const chartW = Math.max(W_AVAIL, xs.length * STEP + MARGIN.left + MARGIN.right);
  const chartH = ys.length * STEP + MARGIN.top + MARGIN.bottom;

  const svg = d3.select(wrapper.value)
    .append("svg")
    .attr("width", "100%")
    .attr("height", chartH)
    .attr("viewBox", `0 0 ${chartW} ${chartH}`)
    .attr("preserveAspectRatio", "xMinYMid meet")
    .style("display", "block");

  const g = svg.append("g").attr("transform", `translate(${MARGIN.left},${MARGIN.top})`);

  // Scales
  const xScale = d3.scaleBand()
    .domain(xs)
    .range([0, xs.length * STEP])
    .padding(GAP / (STEP));

  const yScale = d3.scaleBand()
    .domain(ys)
    .range([0, ys.length * STEP])
    .padding(GAP / (STEP));

  const maxVal = d3.max(data, d => d.value) || 1;
  const lowColor  = resolveColor(palette[0]) || "#21262D";
  const highColor = resolveColor(palette[1]) || "#FF8F00";

  const colorScale = d3.scaleSequential()
    .domain([0, maxVal])
    .interpolator(d3.interpolateRgb(lowColor, highColor));

  // X axis — format timestamps
  const fmtTick = xs.length > 48
    ? d3.timeFormat("%m/%d")
    : xs.length > 24
    ? d3.timeFormat("%H:%M")
    : d3.timeFormat("%H:%M");

  // Choose tick count based on available width
  const maxTicks = Math.floor((xs.length * STEP) / 55);
  const tickValues = xs.filter((_, i) => i % Math.max(1, Math.floor(xs.length / maxTicks)) === 0);

  const xAxis = d3.axisBottom(xScale)
    .tickValues(tickValues)
    .tickFormat(v => fmtTick(new Date(v)));

  g.append("g")
    .attr("class", "axis-x")
    .attr("transform", `translate(0,${ys.length * STEP + 4})`)
    .call(xAxis)
    .selectAll("text")
    .attr("fill", "var(--ntop-text-color)")
    .style("font-size", "10px")
    .attr("transform", "rotate(-35)")
    .style("text-anchor", "end");

  g.select(".axis-x .domain").attr("stroke", "var(--border-color)");
  g.selectAll(".axis-x .tick line").attr("stroke", "var(--border-color)");

  const yAxis = d3.axisLeft(yScale).tickSize(0);

  g.append("g")
    .attr("class", "axis-y")
    .call(yAxis)
    .selectAll("text")
    .attr("fill", "var(--ntop-text-color)")
    .style("font-size", "11px")
    .attr("dx", "-4");

  g.select(".axis-y .domain").remove();

  // X label
  if (props.chart.x_label) {
    svg.append("text")
      .attr("x", MARGIN.left + (xs.length * STEP) / 2)
      .attr("y", chartH - 6)
      .attr("text-anchor", "middle")
      .attr("fill", "var(--ntop-text-color)")
      .style("font-size", "11px")
      .text(props.chart.x_label);
  }

  // Y label
  if (props.chart.y_label) {
    svg.append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -(MARGIN.top + (ys.length * STEP) / 2))
      .attr("y", 14)
      .attr("text-anchor", "middle")
      .attr("fill", "var(--ntop-text-color)")
      .style("font-size", "11px")
      .text(props.chart.y_label);
  }

  // Cells
  const cellRadius = Math.min(3, CELL * 0.2);

  g.selectAll(".hm-cell")
    .data(data)
    .join("rect")
    .attr("class", "hm-cell")
    .attr("x", d => xScale(d.x))
    .attr("y", d => yScale(d.y))
    .attr("width", xScale.bandwidth())
    .attr("height", yScale.bandwidth())
    .attr("rx", cellRadius)
    .attr("ry", cellRadius)
    .attr("fill", d => d.value > 0 ? colorScale(d.value) : lowColor)
    .attr("stroke", "var(--bg-base)")
    .attr("stroke-width", 0.5)
    .style("cursor", "pointer")
    .on("mouseenter", (event, d) => showTooltip(event, d))
    .on("mousemove", (event, d) => moveTooltip(event))
    .on("mouseleave", () => { tooltip.visible = false; });

  // Color legend bar (gradient)
  const LEGEND_W = Math.min(120, xs.length * STEP * 0.4);
  const LEGEND_H = 8;
  const lgX = MARGIN.left + (xs.length * STEP) - LEGEND_W;
  const lgY = chartH - LEGEND_H - 10;

  const defId = `hm-grad-${Math.random().toString(36).slice(2)}`;
  const defs = svg.append("defs");
  const grad = defs.append("linearGradient").attr("id", defId);
  grad.append("stop").attr("offset", "0%").attr("stop-color", lowColor);
  grad.append("stop").attr("offset", "100%").attr("stop-color", highColor);

  svg.append("rect")
    .attr("x", lgX).attr("y", lgY)
    .attr("width", LEGEND_W).attr("height", LEGEND_H)
    .attr("rx", 3)
    .attr("fill", `url(#${defId})`);

  svg.append("text")
    .attr("x", lgX - 4).attr("y", lgY + 7)
    .attr("text-anchor", "end")
    .attr("fill", "var(--ntop-text-color)")
    .style("font-size", "9px")
    .text(_i18n("low") || "Low");

  svg.append("text")
    .attr("x", lgX + LEGEND_W + 4).attr("y", lgY + 7)
    .attr("text-anchor", "start")
    .attr("fill", "var(--ntop-text-color)")
    .style("font-size", "9px")
    .text(_i18n("high") || "High");
}

function showTooltip(event, d) {
  const fmtTime = d3.timeFormat("%Y-%m-%d %H:%M");
  tooltip.time = fmtTime(new Date(d.x));
  tooltip.y_label = d.y;
  tooltip.value = fmtValue(d.value);
  tooltip.visible = true;
  moveTooltip(event);
}

function moveTooltip(event) {
  const rect = container.value.getBoundingClientRect();
  const x = event.clientX - rect.left + 12;
  const y = event.clientY - rect.top - 10;
  tooltip.flip = x + 160 > rect.width;
  tooltip.x = x;
  tooltip.y = y;
}

let themeObs = null;
</script>

<style scoped>
.heatmap-container {
  position: relative;
  width: 100%;
}
.heatmap-body {
  position: relative;
  width: 100%;
  overflow-x: auto;
}
.heatmap-wrapper {
  min-width: 0;
}
.heatmap-tooltip {
  position: absolute;
  min-width: 130px;
  pointer-events: none;
  white-space: nowrap;
}
.tt-time {
  font-size: 11px;
  color: var(--ntop-muted-text-color);
}
.tt-val {
  font-size: 13px;
  font-weight: 600;
  color: var(--ntop-orange);
}
</style>
