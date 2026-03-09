<!--
  (C) 2026 - ntop.org
-->
<template>
  <div ref="container" class="sparkline-container">
    <svg ref="svg"></svg>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch } from "vue";

const d3 = d3v7;

const props = defineProps({
  data:       { type: Array,   default: () => [] },  // array of numbers
  width:      { type: Number,  default: 100 },
  height:     { type: Number,  default: 30 },
  color:      { type: String,  default: "#FF6B35" },
  fill:       { type: String,  default: null },       // null = auto (transparent tint)
  max:        { type: Number,  default: null },       // null = auto
  min:        { type: Number,  default: 0 },
  stroke_width: { type: Number, default: 1.5 },
});

const container = ref(null);
const svg       = ref(null);

let xScale = null, yScale = null, line = null, area = null;

function draw() {
  const data = props.data;
  if (!svg.value || !data.length) return;

  const W = props.width;
  const H = props.height;

  d3.select(svg.value)
    .attr("width", W)
    .attr("height", H)
    .style("display", "block");

  const yMax = props.max != null ? props.max : d3.max(data);
  const yMin = props.min;

  xScale = d3.scaleLinear().domain([0, data.length - 1]).range([0, W]);
  yScale = d3.scaleLinear().domain([yMin, yMax || 1]).range([H, 0]);

  line = d3.line()
    .x((_, i) => xScale(i))
    .y(d => yScale(d))
    .curve(d3.curveMonotoneX);

  area = d3.area()
    .x((_, i) => xScale(i))
    .y0(H)
    .y1(d => yScale(d))
    .curve(d3.curveMonotoneX);

  const s = d3.select(svg.value);
  s.selectAll("*").remove();

  // Fill area
  const fillColor = props.fill || (props.color + "33"); // 20% opacity tint
  s.append("path")
    .datum(data)
    .attr("class", "spark-area")
    .attr("d", area)
    .attr("fill", fillColor);

  // Line
  s.append("path")
    .datum(data)
    .attr("class", "spark-line")
    .attr("d", line)
    .attr("fill", "none")
    .attr("stroke", props.color)
    .attr("stroke-width", props.stroke_width)
    .attr("stroke-linejoin", "round")
    .attr("stroke-linecap", "round");

  // Dot at last value
  const last = data[data.length - 1];
  s.append("circle")
    .attr("cx", xScale(data.length - 1))
    .attr("cy", yScale(last))
    .attr("r", 2.5)
    .attr("fill", props.color);
}

// Push a new value and redraw (keeps a rolling window)
function push(value, maxPoints = 30) {
  const next = [...props.data, value].slice(-maxPoints);
  // emit so parent can update :data
  emit("update:data", next);
}

const emit = defineEmits(["update:data"]);

watch(() => props.data, draw, { deep: true });

onMounted(() => draw());

defineExpose({ push, draw });
</script>

<style scoped>
.sparkline-container {
  display: inline-flex;
  align-items: center;
}
</style>