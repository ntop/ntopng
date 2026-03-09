<!--
  (C) 2026 - ntop.org
-->
<template>

  <div ref="container" class="pie-container">
    <!-- Title -->
    <div v-if="chart.title" class="pie-title"><strong>{{ chart.title }}</strong></div>
    
    <!-- Chart loading -->
    <Loading v-if="loading" />

    <div v-else-if="no_data" class="no-data">{{ _i18n('flows_page.no_data') }}</div>
    
    <!-- Pie Chart -->
    <div ref="wrapper" class="pie-wrapper"></div>
    
    <!-- Tooltip on hover -->
    <div v-if="tooltip.visible" class="pie-tooltip"
      :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px' }">
      <span class="tt-dot" :style="{ background: tooltip.color }"></span>
      <span class="tt-name">{{ tooltip.name }}</span>
      <span class="tt-val">{{ tooltip.value.toLocaleString() }}</span>
      <span class="tt-pct">({{ tooltip.pct }}%)</span>
    </div>
  
  <!-- Legend -->
    <div v-if="items.length" class="pie-legend">
      <div v-for="(it, i) in items" :key="i" class="legend-item"
           :class="{ clickable: !!it.url }"
           @click="it.url && (window.location.href = it.url)">

        <span class="legend-dot" :style="{ background: it.color }"></span>
        <span class="legend-text">{{ it.name }}</span>
        <span class="legend-text">{{ it.pct }}%</span>
      </div>
    </div>
  </div>

</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from "vue";
import { default as Loading } from "../loading.vue";
import colorUtils from "../../utilities/color-utils.js";
import formatterUtils from "../../utilities/formatter-utils";

const d3    = d3v7;
const _i18n = (t) => (typeof i18n === "function" ? i18n(t) : t);

const props = defineProps({ chart: { type: Object, required: true } });
const { name, update_url, url_params, refresh, unit } = props.chart;

const container = ref(null);
const wrapper   = ref(null);
const loading   = ref(false);
const no_data   = ref(false);
const items = ref([]);

const tooltip = reactive({
  visible: false,
  x: 0,
  y: 0,
  name: "",
  value: 0,
  pct: "0",
  color: ""
});

let svg = null, g = null, arc = null, arcHover = null, pie = null;
let oldData = [], refreshTimer = null, resizeTimer = null;
const W = 280, H = 220, TWEEN = 300;

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
  const R = Math.min(W, H) * 0.42;
  const r = R * 0.52;
  const cr = (R - r) * 0.18;   // subtle rounding, not pill-shaped

  pie      = d3.pie().value(d => Math.max(d.value, 1)).sort(null).padAngle(0.03);
  arc      = d3.arc().innerRadius(r).outerRadius(R).cornerRadius(cr);
  arcHover = d3.arc().innerRadius(r).outerRadius(R + 7).cornerRadius(cr);

  svg = d3.select(wrapper.value).append("svg")
    .attr("width", W).attr("height", H).style("display", "block");

  g = svg.append("g").attr("transform", `translate(${W/2},${H/2})`);
  g.append("circle").attr("class", "donut-hole").attr("r", r - 1);
}

async function load() {
  loading.value = true;

  try {
    const url = url_params && Object.keys(url_params).length
      ? `${update_url}?${new URLSearchParams(url_params)}`
      : update_url;

    const res  = await ntopng_utility.http_request(url, null, null, true);
    let data = res?.rsp;

    if (!Array.isArray(data) || !data.length) { no_data.value = true; return; }

    no_data.value = false;
    render(data.filter(d => d.value > 0));

  } catch(e) {
    console.error(`PieChart-${name}:`, e);
    no_data.value = true;

  } finally {
    loading.value = false;
  }
}

function render(data) {

  let node_label = data.map(elem => elem.label);

  //const PALETTE = colorUtils.assignColors(node_label);
  const PALETTE = colorUtils.assignRoundRobinColors(node_label);

  const getColor = (d, i) => d.color || PALETTE[i % PALETTE.length];
  const total = data.reduce((s, d) => s + d.value, 0);

  items.value = data.map((d, i) => ({
    name: d.label,
    // format if unit is defined, else plot value as is
    value: unit ? formatterUtils.getFormatter(unit)(d.value) : d.value,
    color: getColor(d, i),
    url: d.url || null,
    pct: total > 0 ? (d.value / total * 100).toFixed(1) : "0",
  }));

  const newPie = pie(data);

  const tween  = (d) => {
    const old    = oldData.find(o => o.data.label === d.data.label);
    const interp = d3.interpolate(old ?? { startAngle: 0, endAngle: 0 }, d);
    return t => arc(interp(t));
  };

  const paths = g.selectAll("path.slice").data(newPie, d => d.data.label);

  paths.enter().append("path").attr("class", "slice")
    .attr("fill", (d, i) => getColor(d.data, i))

    .on("mouseover", function(ev, d) {
      d3.select(this).transition().duration(100).attr("d", arcHover);
      const rect = container.value.getBoundingClientRect();
      const idx = items.value.findIndex(it => it.name === d.data.label);

      // Update tooltip
      Object.assign(tooltip, {
        visible: true,
        color: getColor(d.data, idx),
        x: ev.clientX - rect.left + 14,
        y: ev.clientY - rect.top - 12,
        name: d.data.label,
        // format if unit is defined, else plot value as is
        value: unit ? formatterUtils.getFormatter(unit)(d.data.value) : d.data.value,
        pct: total > 0 ? (d.data.value / total * 100).toFixed(1) : "0",
      });
    })
    .on("mousemove", (ev) => {
      const rect = container.value.getBoundingClientRect();
      tooltip.x = ev.clientX - rect.left + 14;
      tooltip.y = ev.clientY - rect.top  - 12;
    })
    .on("mouseout", function() {
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
      return t => arc(interp(t));
    }).remove();

  oldData = newPie;
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
  align-items: center;
  flex: 1 1 280px;
  min-width: 220px;
  max-width: 420px;
  min-height: 300px;
  border-radius: 12px;
  padding: 14px 14px 12px;
  box-sizing: border-box;
}

.pie-title {
  align-self: flex-start;
  margin-bottom: 4px;
}

.pie-wrapper { width: 100%; display: flex; justify-content: center; }

.no-data {
  color: #999;
  margin: auto;
}

:deep(.donut-hole) { fill: var(--loading-bg, #fff); }
:deep(path.slice)  { cursor: pointer; }

.pie-tooltip {
  position: absolute;
  pointer-events: none;
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(10,10,10,0.85);
  color: #fff;
  padding: 5px 10px 5px 8px;
  border-radius: 6px;
  white-space: nowrap;
  box-shadow: 0 2px 10px rgba(0,0,0,0.4);
  z-index: 100;
  backdrop-filter: blur(4px);
}
.tt-dot  { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.tt-name { font-weight: 500; }
.tt-val  { font-weight: 700; }
.tt-pct  { color: rgba(255,255,255,0.5); }

.pie-legend {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 4px 16px;
  margin-top: 10px;
  padding-top: 8px;
  width: 100%;
}
.legend-item {
  display: flex;
  align-items: center;
  gap: 5px;
  white-space: nowrap;
  user-select: none;
}
.legend-item.clickable { cursor: pointer; }
.legend-item.clickable:hover .legend-name { text-decoration: underline; }
.legend-dot  { width: 10px; height: 10px; border-radius: 3px; flex-shrink: 0; }
.legend-text { font-size: 0.75rem; }

</style>