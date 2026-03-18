<!--
  (C) 2026 - ntop.org
-->
<template>
    <div ref="container" class="pie-container" :class="{ 'layout-column': legend_below }">
        <!-- Title -->
        <div v-if="chart.title" class="pie-title"><strong>{{ chart.title }}</strong></div>

        <Loading v-if="!props.hideLoading" :isLoading="loading" />

        <!-- no data -->
        <NoData :show="no_data && !loading"></NoData>

        <div class="pie-body">
            <div class="d-flex pie-row">
                <!-- Pie Chart -->
                <div ref="wrapper" class="pie-wrapper" v-show="!loading && !no_data"></div>

                <!-- Legend -->
                <!--
          <div v-if="!loading && items.length" class="pie-legend">
        -->
                <div v-if="!loading && items.length && !no_data" class="pie-legend">
                    <div v-for="(it, i) in items" :key="i" class="legend-item" :class="{ clickable: !!it.url }"
                        @click="it.url && (window.location.href = it.url)">
                        <span class="legend-dot" :style="{ background: it.color }"></span>
                        <span class="legend-name form-control-sm" :title="it.name">{{ it.name }}</span>
                    </div>
                </div>

            </div>

            <!-- Tooltip on hover -->
            <div v-if="!loading && tooltip.visible" class="pie-tooltip"
                :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px' }">
                <span class="tt-dot" :style="{ background: tooltip.color }"></span>
                <span class="tt-name">{{ tooltip.name }}</span>
                <span class="tt-val">{{ tooltip.value.toLocaleString() }}</span>
            </div>
        </div>

    </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick, watch } from "vue";
import { default as Loading } from "../loading.vue";
import colorUtils from "../../utilities/color-utils.js";
import formatterUtils from "../../utilities/formatter-utils.js";
import NoData from '../components/no-data.vue'

const d3 = d3v7;
const _i18n = (t) => (typeof i18n === "function" ? i18n(t) : t);

const props = defineProps({ chart: { type: Object, required: true }, hideLoading: Boolean });
const { name, update_url, url_params, refresh, unit, label, custom_fetch } = props.chart;
const formatted_label = label ? (i18n(label) || label) : null;
const container = ref(null);
const wrapper = ref(null);
const loading = ref(false);
const legend_below = ref(false);
const no_data = ref(false);
const items = ref([]);
const has_loaded = ref(false); /* true after the first successful data fetch */

// Component event definitions for parent communication
const emit = defineEmits(["chart-updated", "update-requested"]);

const tooltip = reactive({
    visible: false,
    x: 0,
    y: 0,
    name: "",
    value: 0,
    percentage: "0",
    color: ""
});

let resizeObs = null;
let svg = null;
let g = null;
let arc = null;
let pie = null;
let oldData = [];
let refreshTimer = null;
let currentR = 0, currentr = 0, currentcr = 0;

const TWEEN = 300;

const CHART_SIZE = 200;
const _R = CHART_SIZE * 0.42;
const _r = _R * 0.52;
const _cr = (_R - _r) * 0.18;

onMounted(async () => {
    await nextTick();
    resizeObs = new ResizeObserver(entries => {
        legend_below.value = entries[0].contentRect.width < 300;
    });

    resizeObs.observe(container.value);
    drawSVG();
    await load();
    if (refresh > 0) refreshTimer = setInterval(load, refresh);
});

onBeforeUnmount(() => {
    clearInterval(refreshTimer);
    resizeObs?.disconnect();
});

function drawSVG() {
    wrapper.value?.replaceChildren();

    currentR = _R; currentr = _r; currentcr = _cr;
    pie = d3.pie().value(d => Math.max(Math.round(d.value), 1)).sort(null).padAngle(0.02);
    arc = d3.arc().innerRadius(_r).outerRadius(_R).cornerRadius(_cr);

    svg = d3.select(wrapper.value)
        .append("svg")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("viewBox", `0 0 ${CHART_SIZE} ${CHART_SIZE}`)
        .attr("preserveAspectRatio", "xMidYMid meet");

    g = svg.append("g")
        .attr("transform", `translate(${CHART_SIZE / 2},${CHART_SIZE / 2})`);

    g.append("circle").attr("class", "pie-hole").attr("r", _r - 1);
}

async function load() {
    /* show loading on first fetch, then reffresh */
    if (!has_loaded.value) loading.value = true;
    const { update_url, url_params, custom_fetch } = props.chart;
    emit("update-requested");

    try {
        let data;

        if (custom_fetch) {
            data = await custom_fetch(update_url, url_params);
        } else {
            const url =
                url_params && Object.keys(url_params).length
                    ? `${update_url}?${new URLSearchParams(url_params)}`
                    : update_url;

            const res = await ntopng_utility.http_request(url, null, null, true);
            data = res?.rsp?.data || res?.rsp;
        }

        if (!Array.isArray(data) || !data.length) {
            if (!has_loaded.value) no_data.value = true;
            return;
        }

        no_data.value = false;
        has_loaded.value = true;
        render(data);

    } catch (e) {
        console.error(`pieChart-${props.chart.name}:`, e);
        if (!has_loaded.value) no_data.value = true;
    } finally {
        loading.value = false;
        emit("chart-updated");
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
    })).sort((a, b) => b.percentage - a.percentage) // sort percentage descending to display the legend descending

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
            const R = currentR, r = currentr, cr = currentcr;
            d3.select(this).transition().duration(100).attrTween("d", () => {
                const interp = d3.interpolate(R, R + 7);
                const a = d3.arc().innerRadius(r).cornerRadius(cr);
                return t => a.outerRadius(interp(t))(d);
            });
            const rect = container.value.getBoundingClientRect();
            const idx = items.value.findIndex(it => it.name === d.data.label);

            Object.assign(tooltip, {
                visible: true,
                color: getColor(d.data, idx),
                x: ev.clientX - rect.left + 14,
                y: ev.clientY - rect.top - 12,
                name: d.data.label,
                value: unit ? formatterUtils.getFormatter(unit, null, null, formatted_label)(d.data.value) : d.data.value,
                percentage: d.data.percentage,
            });

        })
        .on("mousemove", (ev) => {
            const rect = container.value.getBoundingClientRect();

            tooltip.x = ev.clientX - rect.left + 14;
            tooltip.y = ev.clientY - rect.top - 12;
        })
        .on("mouseout", function (ev, d) {
            const R = currentR, r = currentr, cr = currentcr;
            d3.select(this).transition().duration(100).attrTween("d", () => {
                const interp = d3.interpolate(R + 7, R);
                const a = d3.arc().innerRadius(r).cornerRadius(cr);
                return t => a.outerRadius(interp(t))(d);
            });
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

defineExpose({
    update: async () => {
        await load();
    }
});

// url params updated
watch(() => props.chart.url_params, () => {
    load();
}, { deep: true });

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
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.pie-body {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    flex: 1 1 auto;
    min-height: 0;
    width: 100%;
    height: 100%;
}

.pie-row {
    flex: 1 1 auto;
    min-height: 0;
    align-items: stretch;
    gap: 12px;
    padding: 4px 0;
}

.pie-wrapper {
    flex: 0 0 auto;
    height: 100%;
    min-height: 0;
    aspect-ratio: 1 / 1;
    max-width: 60%;
    overflow: hidden;
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

/* legend below (narrow container) */
.layout-column {
    justify-content: center;
}

.layout-column .pie-body {
    height: auto;
    flex: 0 0 auto;
    overflow: visible;
}

.layout-column .pie-row {
    flex-direction: column;
    align-items: center;
    flex: 0 0 auto;
    height: auto;
    min-height: 0;
}

.layout-column .pie-wrapper {
    width: 140px;
    height: 140px;
    max-width: 100%;
    flex-shrink: 0;
}

.layout-column .pie-legend {
    flex: 0 0 auto;
    flex-direction: row;
    flex-wrap: wrap;
    justify-content: flex-start;
    align-items: center;
    max-height: none;
    width: 100%;
    overflow: visible;
}

.layout-column .legend-item {
    width: auto;
    flex: 0 0 auto;
    padding-right: 8px;
}

.pie-legend {
    flex: 1 1 0;
    min-width: 0;
    display: flex;
    flex-direction: column;
    flex-wrap: nowrap;
    justify-content: center;
    align-items: flex-start;
    gap: 4px 0;
    overflow-y: auto;
    overflow-x: hidden;
    max-height: 100%;
    scrollbar-width: thin;
    scrollbar-color: rgba(0, 0, 0, 0.15) transparent;
}

.pie-legend::-webkit-scrollbar {
    width: 3px;
}

.pie-legend::-webkit-scrollbar-thumb {
    background: rgba(0, 0, 0, 0.15);
    border-radius: 2px;
}

.legend-item {
    display: flex;
    align-items: center;
    gap: 5px;
    min-width: 0;
    width: 100%;
    user-select: none;
    transition: opacity 0.3s ease;
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
    transition: opacity 0.3s ease;
}
</style>