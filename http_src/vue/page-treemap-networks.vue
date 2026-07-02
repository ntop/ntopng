<!-- (C) 2026 - ntop.org
    REST: /lua/pro/rest/v2/get/host/top/network_hosts_score.lua
    Response: { rsp: [{ name, data:[{x,y,host}] }] }
-->
<template>
  <div class="card mb-3">
    <div class="card-body p-2">
      <div class="d-flex align-items-center mb-1" style="gap:8px;">
        <div class="d-flex flex-wrap ms-2" style="gap:6px 14px;">
          <div v-for="(c, name) in legendColors" :key="name" class="d-flex align-items-center" style="gap:4px;font-size:11px;">
            <span :style="{ background: c, width:'10px', height:'10px', borderRadius:'2px', display:'inline-block' }"></span>
            {{ name }}
          </div>
        </div>
      </div>
      <div ref="wrapper" style="width:100%;height:150px;position:relative;">
        <Loading :isLoading="loading" />
      </div>
    </div>
  </div>

  <!-- tooltip rendered outside the SVG -->
  <div v-if="tooltip.visible" class="treemap-tooltip"
    :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px', transform: tooltip.flipLeft ? 'translateX(-100%)' : 'none' }">
    <div class="tt-title">{{ tooltip.network }}</div>
    <div>{{ tooltip.label }}: <strong>{{ tooltip.value }} %</strong></div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from "vue";
import { default as Loading } from "./loading.vue";
import colorUtils from "../utilities/color-utils.js";

const d3 = d3v7;

const props = defineProps({ context: Object });

const wrapper   = ref(null);
const loading   = ref(true);
const legendColors = ref({});
const tooltip   = reactive({ visible: false, x: 0, y: 0, flipLeft: false, network: "", label: "", value: "" });

let svgEl = null;
let resizeObs = null;
let lastData  = null;

const url = `${http_prefix}/lua/pro/rest/v2/get/host/top/network_hosts_score.lua`;

onMounted(async () => {
  await nextTick();
  resizeObs = new ResizeObserver(() => { if (lastData) draw(lastData); });
  resizeObs.observe(wrapper.value);
  await load();
});

onBeforeUnmount(() => resizeObs?.disconnect());

async function load() {
  try {
    loading.value = true;
    const res = await ntopng_utility.http_request(url, null, null, true);
    const series = res?.rsp ?? [];
    if (!series.length) { 
      loading.value = false; 
      return; 
    }

    lastData = series;
    draw(series);
  } catch(e) {
    console.error("treemap-networks:", e);
  } finally {
    loading.value = false;
  }
}

function draw(series) {
  if (!wrapper.value) return;

  const W = wrapper.value.clientWidth  || 600;
  const H = wrapper.value.clientHeight || 150;

  /* Build hierarchy: root -> networks -> leaves */
  const root = d3.hierarchy({ children: series.map(net => ({
    name: net.name,
    children: (net.data || []).map(pt => ({ network: net.name, label: pt.x, value: pt.y, host: pt.host })),
  }))})
    .sum(d => d.value || 0)
    .sort((a, b) => b.value - a.value);

  d3.treemap().size([W, H]).padding(2).paddingTop(0)(root);

  /* Assign colors per network */
  const networkNames = series.map(s => s.name);
  const PALETTE = colorUtils.assignRoundRobinColors(networkNames);
  const colorMap = {};
  networkNames.forEach((n, i) => { colorMap[n] = PALETTE[i]; });
  legendColors.value = colorMap;

  /* Build / replace SVG */
  wrapper.value.querySelectorAll("svg").forEach(el => el.remove());
  svgEl = d3.select(wrapper.value).append("svg")
    .attr("width", W).attr("height", H)
    .style("display", "block").style("border-radius", "4px");

  const leaves = root.leaves();

  const cell = svgEl.selectAll("g").data(leaves).join("g")
    .attr("transform", d => `translate(${d.x0},${d.y0})`)
    .style("cursor", d => d.data.host ? "pointer" : "default")
    .on("click", (ev, d) => {
      if (d.data.host)
        window.location.href = `${http_prefix}/lua/host_details.lua?host=${d.data.host}`;
    })
    .on("mouseover", (ev, d) => {
      const flipLeft = ev.clientX > window.innerWidth / 2;
      Object.assign(tooltip, {
        visible: true,
        x: ev.clientX + (flipLeft ? -14 : 14),
        y: ev.clientY - 10,
        flipLeft,
        network: d.data.network,
        label:   d.data.label,
        value:   d.data.value,
      });
      d3.select(ev.currentTarget).select("rect").attr("fill-opacity", 0.95);
    })
    .on("mousemove", (ev) => {
      const flipLeft = ev.clientX > window.innerWidth / 2;
      tooltip.x = ev.clientX + (flipLeft ? -14 : 14);
      tooltip.y = ev.clientY - 10;
      tooltip.flipLeft = flipLeft;
    })
    .on("mouseout", (ev) => {
      tooltip.visible = false;
      d3.select(ev.currentTarget).select("rect").attr("fill-opacity", 0.82);
    });

  cell.append("rect")
    .attr("width",  d => Math.max(0, d.x1 - d.x0))
    .attr("height", d => Math.max(0, d.y1 - d.y0))
    .attr("fill",   d => colorMap[d.data.network] || "#888")
    .attr("fill-opacity", 0.82)
    .attr("rx", 3);

  /* Cell labels — vertical when cell is taller than wide */
  cell.each(function(d) {
    const cw = d.x1 - d.x0;
    const ch = d.y1 - d.y0;
    if (cw < 16 && ch < 16) return;
    const g = d3.select(this);
    const vertical = ch > cw + 8;

    if (vertical) {
      /* Rotate text 90°, centered in cell */
      const label = d.data.label;
      const maxChars = Math.floor(ch / 7);
      const txt = label.length > maxChars ? label.slice(0, maxChars - 1) + "…" : label;
      g.append("text")
        .attr("transform", `translate(${cw / 2},${ch / 2}) rotate(-90)`)
        .attr("text-anchor", "middle").attr("dominant-baseline", "central")
        .attr("fill", "#fff").attr("font-size", "11px").attr("font-weight", "600")
        .style("pointer-events", "none")
        .text(txt);
    } else {
      /* Horizontal: host label + score below */
      const maxChars = Math.max(1, Math.floor(cw / 7) - 1);
      const label = d.data.label;
      const txt = label.length > maxChars ? label.slice(0, maxChars - 1) + "…" : label;
      if (cw >= 24) {
        g.append("text")
          .attr("x", 4).attr("y", 13)
          .attr("fill", "#fff").attr("font-size", "11px").attr("font-weight", "600")
          .style("pointer-events", "none")
          .text(txt);
      }
      if (cw >= 32 && ch >= 28) {
        g.append("text")
          .attr("x", 4).attr("y", 26)
          .attr("fill", "rgba(255,255,255,0.78)").attr("font-size", "10px")
          .style("pointer-events", "none")
          .text(d.data.value + " %");
      }
    }
  });
}
</script>

<style scoped>
.treemap-tooltip {
  position: fixed;
  pointer-events: none;
  background: rgba(10,10,10,0.88);
  color: #fff;
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 12px;
  white-space: nowrap;
  box-shadow: 0 4px 12px rgba(0,0,0,0.4);
  z-index: 9999;
  backdrop-filter: blur(4px);
}
.tt-title {
  font-weight: 700;
  margin-bottom: 2px;
  font-size: 11px;
  opacity: 0.75;
}
</style>
