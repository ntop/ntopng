<!--
  (C) 2026 - ntop.org
-->
<template>
  <div ref="container" class="pie-container" :class="`legend-${legend_position}`">
    <!-- Title -->
    <div v-if="chart.title" class="pie-title"><strong>{{ chart.title }}</strong></div>

    <Loading :isLoading="loading" />

    <!-- no data -->
    <NoData :show="no_data && !loading"></NoData>

    <div class="pie-body">
      <div class="d-flex">
        <!-- Pie Chart -->
        <div ref="wrapper" class="pie-wrapper" v-show="!loading && !no_data"></div>

        <!-- Legend -->
        <div v-if="!loading && items.length" class="pie-legend">
          <div v-for="(it, i) in items" :key="i" class="legend-item" :class="{ clickable: !!it.url }"
            @click="it.url && (window.location.href = it.url)">
            <span class="legend-dot" :style="{ background: it.color }"></span>
            <span class="legend-name form-control-sm" :title="it.name">{{ it.name }}</span>
            <span class="legend-percentage form-control-sm">{{ it.percentage }}%</span>
          </div>
        </div>

      </div>

      <!-- Tooltip on hover -->
      <div v-if="!loading && tooltip.visible" class="pie-tooltip"
        :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px' }">
        <span class="tt-dot" :style="{ background: tooltip.color }"></span>
        <span class="tt-name">{{ tooltip.name }}</span>
        <span class="tt-val">{{ tooltip.value.toLocaleString() }}</span>
        <span class="tt-percentage">({{ tooltip.percentage }}%)</span>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from "vue";
import { default as Loading } from "../loading.vue";
import colorUtils from "../../utilities/color-utils.js";
import formatterUtils from "../../utilities/formatter-utils.js";
import NoData from '../components/no-data.vue'

const d3 = d3v7;
const _i18n = (t) => (typeof i18n === "function" ? i18n(t) : t);

const props = defineProps({ chart: { type: Object, required: true } });
const { name, update_url, url_params, refresh, unit, label, custom_fetch } = props.chart;
const formatted_label = label ? i18n(label) : null;
const legend_position = props.chart.legend_position || "bottom"; // "bottom" or "left" or "right"
const container = ref(null);
const wrapper = ref(null);
const loading = ref(false);
const no_data = ref(false);
const items = ref([]);

const tooltip = reactive({
  visible: false,
  x: 0,
  y: 0,
  name: "",
  value: 0,
  percentage: "0",
  color: ""
});

let svg = null;
let g = null;
let arc = null;
let arcHover = null;
let pie = null;
let oldData = [];
let refreshTimer = null;
let resizeTimer = null;

const TWEEN = 300;

// Measure the wrapper div and return { W, H, R }
function getDims() {
  const el = wrapper.value;
  if (!el) return { W: 200, H: 200, R: 80 };

  const W = el.clientWidth || 200;
  const H = el.clientHeight || 200;
  const R = Math.min(W, H) * 0.42;
  return { W, H, R };
}

onMounted(async () => {
  await nextTick();
  drawSVG();
  await load();
  if (refresh > 0) refreshTimer = setInterval(load, refresh);
  window.addEventListener("resize", onResize);
});

onBeforeUnmount(() => {
  clearInterval(refreshTimer);
  clearTimeout(resizeTimer);
  window.removeEventListener("resize", onResize);
});

function drawSVG() {
  wrapper.value?.replaceChildren();
  
  const { W, H, R } = getDims();
  const r = R * 0.52;
  const cr = (R - r) * 0.18;

  pie = d3.pie().value(d => Math.max(Math.round(d.value), 1)).sort(null).padAngle(0.02);
  arc = d3.arc().innerRadius(r).outerRadius(R).cornerRadius(cr);
  arcHover = d3.arc().innerRadius(r).outerRadius(R + 7).cornerRadius(cr);

  svg = d3.select(wrapper.value)
    .append("svg")
    .attr("width", "100%")
    .attr("height", "100%")
    .attr("viewBox", `0 0 ${W} ${H}`)
    .attr("preserveAspectRatio", "xMidYMid meet");

  g = svg.append("g")
    .attr("transform", `translate(${W / 2},${H / 2})`);

  g.append("circle").attr("class", "pie-hole").attr("r", r - 1);
}

async function load() {
  loading.value = true;

  try {
    let data;
    // used for dashboard, as it passes data directly
    if (custom_fetch) {
      data = await custom_fetch(update_url, url_params);
    } else {
      const url = url_params && Object.keys(url_params).length
        ? `${update_url}?${new URLSearchParams(url_params)}`
        : update_url;

      const res = await ntopng_utility.http_request(url, null, null, true);
      data = res?.rsp?.data || res?.rsp;
    }

    if (!Array.isArray(data) || !data.length) { no_data.value = true; return; }
    no_data.value = false;
    render(data);

  } catch (e) {
    console.error(`pieChart-${name}:`, e);
    no_data.value = true;
  } finally {
    loading.value = false;
  }
}

// assign colors from palette, first element has the same color on all pages
function render(data) {
  const PALETTE = colorUtils.assignRoundRobinColors(data.map(d => d.label));
  const getColor = (d, i) => d.color || PALETTE[i % PALETTE.length];
  const total = data.reduce((s, d) => s + d.value, 0);
  /* Filtered data, excludes values too small to be shown in the chart
   * values with a number lesser then 0.0%
   */
  const filtered_data = data.map((d, i) => ({
    label: d.label,
    value: d.value,
    percentage: total > 0 ? (d.value / total * 100).toFixed(1) : "0"
  })).filter((el) => el.percentage > 0.0);

  items.value = filtered_data.map((d, i) => ({
    name: d.label,
    value: unit ? formatterUtils.getFormatter(unit, null, null, formatted_label)(d.value) : d.value,
    color: getColor(d, i),
    url: d.url || null,
    percentage: total > 0 ? (d.value / total * 100).toFixed(1) : "0",
  }))

  const newpie = pie(filtered_data);

  const tween = (d) => {
    const old = oldData.find(o => o.data.label === d.data.label);
    const interp = d3.interpolate(old ?? { startAngle: 0, endAngle: 0 }, d);
    return t => { try { return arc(interp(t)); } catch (e) { return ""; } };
  };

  const paths = g.selectAll("path.slice").data(newpie, d => d.data.label);

  paths.enter().append("path").attr("class", "slice")
    .attr("fill", (d, i) => getColor(d.data, i))

    .on("mouseover", function (ev, d) {
      d3.select(this).transition().duration(100).attr("d", arcHover);
      const rect = container.value.getBoundingClientRect();
      const idx = items.value.findIndex(it => it.name === d.data.label);

      Object.assign(tooltip, {
        visible: true,
        color: getColor(d.data, idx),
        x: ev.clientX - rect.left + 14,
        y: ev.clientY - rect.top - 12,
        name: d.data.label,
        value: unit ? formatterUtils.getFormatter(unit, null, null, formatted_label)(d.data.value) : d.data.value,
        percentage: total > 0 ? (d.data.value / total * 100).toFixed(1) : "0",
      });

    })
    .on("mousemove", (ev) => {
      const rect = container.value.getBoundingClientRect();

      tooltip.x = ev.clientX - rect.left + 14;
      tooltip.y = ev.clientY - rect.top - 12;
    })
    .on("mouseout", function () {
      d3.select(this).transition().duration(100).attr("d", arc);
      tooltip.visible = false;
    })
    .on("click", (_, d) => { if (d.data.url) window.location.href = d.data.url; })
    .transition().duration(TWEEN).attrTween("d", tween);

  paths.attr("fill", (d, i) => getColor(d.data, i))
    .transition().duration(TWEEN).attrTween("d", tween);

  paths.exit()
    .transition().duration(TWEEN)
    .attrTween("d", d => {
      const interp = d3.interpolate(d, { startAngle: Math.PI * 2, endAngle: Math.PI * 2 });
      return t => { try { return arc(interp(t)); } catch (e) { return ""; } };
    }).remove();

  oldData = newpie;
}

const onResize = () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => { oldData = []; drawSVG(); load(); }, 150);
};

defineExpose({ update: load });
</script>

<style scoped>
.pie-container {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  width: 100%;
  height: 100%;
  min-width: 0;
  box-sizing: border-box;
}

.pie-title {
  flex-shrink: 0;
  margin-bottom: 4px;
}

.pie-body {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex: 1 1 auto;
  min-height: 0;
  width: 100%;
  gap: 8px;
}

/* Side legend */
.legend-left .pie-body,
.legend-right .pie-body {
  flex-direction: row;
  align-items: center;
  gap: 12px;
}

.legend-right .pie-body {
  flex-direction: row;
}

.legend-left .pie-body {
  flex-direction: row-reverse;
}

.pie-wrapper {
  flex: 1 1 auto;
  min-width: 0;
  min-height: 0;
  width: 100%;
  height: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  overflow: hidden;
}

.legend-left .pie-wrapper,
.legend-right .pie-wrapper {
  flex: 1 1 auto;
  max-width: 60%;
}

.no-data {
  color: #999;
  margin: auto;
}

:deep(.pie-hole) {
  fill: var(--loading-bg, #fff);
}

:deep(path.slice) {
  cursor: pointer;
}

.pie-tooltip {
  position: absolute;
  pointer-events: none;
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(10, 10, 10, 0.85);
  color: #fff;
  padding: 5px 10px 5px 8px;
  border-radius: 6px;
  white-space: nowrap;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.4);
  z-index: 100;
  backdrop-filter: blur(4px);
}

.tt-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.tt-name {
  font-weight: 500;
}

.tt-val {
  font-weight: 700;
}

.tt-percentage {
  color: rgba(255, 255, 255, 0.5);
}

.pie-legend {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  flex-wrap: nowrap;
  justify-content: center;
  align-items: flex-start;
  gap: 4px 0;
  overflow: hidden;
  min-width: 0;
  max-height: 100%;
}

.legend-left .pie-legend,
.legend-right .pie-legend {
  overflow-y: auto;
  scrollbar-width: thin;
  /* Firefox */
  scrollbar-color: rgba(255, 255, 255, 0.15) transparent;
}

.legend-left .pie-legend::-webkit-scrollbar,
.legend-right .pie-legend::-webkit-scrollbar {
  width: 3px;
}

.legend-left .pie-legend::-webkit-scrollbar-thumb,
.legend-right .pie-legend::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.15);
  border-radius: 2px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 5px;
  min-width: 0;
  width: 100%;
  user-select: none;
}

.legend-item.clickable {
  cursor: pointer;
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

.legend-percentage {
  flex-shrink: 0;
  color: color-mix(in srgb, currentColor 60%, transparent);
  margin-left: 2px;
}
</style>