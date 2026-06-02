<!-- (C) 2026 - ntop.org
     This component ONLY renders — it never fetches data itself.
     The parent fetches all data in one batch call (ts-client.js fetchTimeseries)
     and passes the result for one chart via the :result prop.

     Usage:
       <ts-chart
         :id="'iface_traffic'"
         :result="batchResults['iface_traffic']"
         :meta="batchMeta"
         @zoom="onZoom"
       />
-->
<template>
    <div class="ts-chart-wrapper mb-2 position-relative">
        <!-- legend controls row -->
        <div class="d-flex align-items-center mb-1" v-if="seriesList.length > 0">
            <div v-if="!hideStacked" class="form-check form-switch form-control-sm ms-1">
                <input type="checkbox" class="form-check-input" @click="toggleStacked" :checked="isStacked">
                <label class="form-check-label">{{ _i18n('stacked') }}</label>
            </div>
            <div class="ms-auto" style="overflow-x:auto; white-space:nowrap;">
                <label class="form-check-label form-control-sm" v-for="(s, i) in seriesList" :key="s.name">
                    <input type="checkbox" class="form-check-input align-middle mt-0"
                        @click="toggleSerie(!s.visible, i)"
                        :checked="s.visible"
                        :style="{ backgroundColor: s.color, borderColor: '#0d6efd' }">
                    {{ s.name }}
                </label>
            </div>
        </div>

        <!-- loading overlay -->
        <div v-if="loading" class="text-center py-3 text-muted" style="min-height:80px;">
            <span class="spinner-border spinner-border-sm me-1"></span>
        </div>

        <!-- error state -->
        <div v-else-if="error" class="alert alert-danger py-2 small">{{ error }}</div>

        <!-- chart containers (dual-div for smooth transitions) -->
        <div v-else class="position-relative">
            <div ref="divA" class="w-100" :style="chartStyle"></div>
            <div ref="divB" class="w-100 d-none" :style="chartStyle"></div>
            <div ref="legendDiv" class="dygraph-legend" style="display:none; position:absolute; top:0; right:0; z-index:10; background:rgba(255,255,255,0.9); border:1px solid #ccc; padding:4px 8px; pointer-events:none;"></div>
        </div>
    </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from "vue";
import { Dygraph } from "../utilities/graph/dygraph.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import formatterUtils from "../utilities/formatter-utils";

const props = defineProps({
    id:          { type: String,  required: true },
    result:      { type: Object,  default: null },   // one entry from batch.results[id]
    meta:        { type: Object,  default: null },   // batch.meta
    height:      { type: Number,  default: 180 },
    hideStacked: { type: Boolean, default: false },
    loading:     { type: Boolean, default: false },
});

const emit = defineEmits(["zoom", "chart-updated"]);

const _i18n = (t) => i18n(t);

const divA        = ref(null);
const divB        = ref(null);
const legendDiv   = ref(null);
const useB        = ref(false);       // which div is currently active
const chart       = ref(null);
const seriesList  = ref([]);
const isStacked   = ref(false);
const error       = ref(null);

const chartStyle = computed(() => ({
    height: `${props.height}px`,
    width:  '100%',
}));

function activeDiv()  { return useB.value ? divB.value  : divA.value; }
function hiddenDiv()  { return useB.value ? divA.value  : divB.value; }

/* Default colors for auto-assignment when no metric config is available */
const DEFAULT_COLORS = ["#C6D9FD","#90EE90","#EE8434","#C95D63","#AE8799","#717EC3","#496DDB"];

/**
 * Convert a raw batch result { series:[{id,data}], metadata:{epoch_begin,epoch_step} }
 * to a Dygraph-ready options object { data:[[Date,...]], labels:["Time",...], colors:[], series:{} }.
 * If the result already has .data it is returned as-is (pre-formatted path).
 */
function ensureDygraphOptions(result) {
    if (!result) return null;
    if (result.data) return result;   // already formatted by dygraph-config.js

    const seriesArr = result.series || [];
    if (!seriesArr.length) return null;

    const metadata   = result.metadata || {};
    const epochBegin = metadata.epoch_begin || 0;
    const step       = metadata.epoch_step  || 300;
    const n          = seriesArr[0]?.data?.length || 0;
    const measureUnit = result.measure_unit || "number";

    const labels = ["Time", ...seriesArr.map(s => String(s.name || s.id || ""))];
    const colors = seriesArr.map((_, i) => DEFAULT_COLORS[i % DEFAULT_COLORS.length]);
    const seriesConfig = {};
    labels.slice(1).forEach(name => {
        seriesConfig[name] = { fillGraph: true, strokeWidth: 1.0, pointSize: 1.5, fillAlpha: 0.5 };
    });

    const rows = [];
    for (let i = 0; i < n; i++) {
        const t = new Date((epochBegin + i * step) * 1000);
        const row = [t];
        seriesArr.forEach(s => {
            const v = s.data?.[i];
            row.push((v === null || v === undefined || v !== v) ? NaN : v);
        });
        rows.push(row);
    }

    // Build axis formatter from measure_unit
    const formatter = formatterUtils.getFormatter(measureUnit);
    const axisConfig = {
        axisLabelFormatter: formatter,
        valueFormatter: (v) => formatter(v),
        axisLabelWidth: 80,
    };

    return {
        data:         rows,
        labels,
        colors,
        series:       seriesConfig,
        stackedGraph: false,
        axes:         { y: axisConfig },
        yRangePad:    1,
        includeZero:  true,
    };
}

function loadStackedPref() {
    const saved = localStorage.getItem(`ntopng.ts.stacked.${props.id}`);
    return saved === "true";
}

function saveStackedPref(val) {
    localStorage.setItem(`ntopng.ts.stacked.${props.id}`, String(val));
}

function buildSeriesList(options) {
    if (!options || !options.series) return [];
    const list = [];
    let i = 0;
    for (const name in options.series) {
        list.push({ name, visible: true, color: (options.colors || [])[i] || "#333" });
        i++;
    }
    return list;
}

function drawChart(options, animate) {
    if (!options || !options.data) return;

    const data    = options.data;
    options.data  = null;

    isStacked.value = loadStackedPref();

    const dygraphOpts = {
        ...options,
        stackedGraph:      isStacked.value,
        labelsDiv:         legendDiv.value,
        legendFormatter:   (data) => {
            if (!data.series) return "";
            return data.series
                .map(s => {
                    const val = (s.yHTML !== undefined && s.yHTML !== "") ? s.yHTML : "—";
                    const dot = `<span style="display:inline-block;width:10px;height:10px;background:${s.color};border-radius:2px;margin-right:4px;vertical-align:middle;"></span>`;
                    return `<div style="white-space:nowrap;">${dot}${s.label}: <b>${val}</b></div>`;
                })
                .join("");
        },
        width:             activeDiv().clientWidth || undefined,
        height:            props.height,
        zoomCallback:      onZoomed,
        highlightCallback: showLegend,
        unhighlightCallback: hideLegend,
        drawCallback:      (g, isFirst) => emit("chart-updated", { dygraph: g, firstLoad: isFirst }),
    };

    seriesList.value = buildSeriesList(options);

    if (animate && chart.value) {
        // draw on hidden div, then swap
        useB.value = !useB.value;
        nextTick(() => {
            const newChart = new Dygraph(activeDiv(), data, dygraphOpts);
            hiddenDiv().classList.add("d-none");
            activeDiv().classList.remove("d-none");
            newChart.resize();
            newChart.resetZoom();
            chart.value.destroy();
            hiddenDiv().style.width  = "";
            hiddenDiv().style.height = "";
            chart.value = newChart;
        });
    } else {
        if (chart.value) { chart.value.destroy(); }
        chart.value = new Dygraph(activeDiv(), data, dygraphOpts);
    }
}

function showLegend(event) {
    if (!legendDiv.value) return;
    legendDiv.value.style.display = "block";
    const rect   = legendDiv.value.getBoundingClientRect();
    const margin = 10;
    if (rect.top < margin) {
        legendDiv.value.style.top = margin + "px";
    }
}

function hideLegend() {
    if (legendDiv.value) legendDiv.value.style.display = "none";
}

function onZoomed(minDate, maxDate) {
    if (!minDate || !maxDate) return;
    const epochBegin = Math.round(minDate / 1000);
    const epochEnd   = Math.round(maxDate / 1000);
    emit("zoom", { epoch_begin: epochBegin, epoch_end: epochEnd });
}

function toggleStacked() {
    isStacked.value = !isStacked.value;
    saveStackedPref(isStacked.value);
    if (chart.value) {
        chart.value.updateOptions({ stackedGraph: isStacked.value });
    }
}

function toggleSerie(visible, idx) {
    if (seriesList.value[idx]) {
        seriesList.value[idx].visible = visible;
        if (chart.value) chart.value.setVisibility(idx, visible);
    }
}

watch(() => props.result, (newResult) => {
    error.value = null;
    if (!newResult) return;

    if (newResult.error) {
        error.value = newResult.error;
        return;
    }

    const options = ensureDygraphOptions(newResult);
    if (!options) return;
    const animate = chart.value != null;
    nextTick(() => drawChart(options, animate));
}, { immediate: false });

onMounted(async () => {
    await nextTick();
    requestAnimationFrame(() => {
        if (props.result && !props.result.error) {
            const options = ensureDygraphOptions(props.result);
            if (options) drawChart(options, false);
        }
    });
});

onBeforeUnmount(() => {
    if (chart.value) {
        chart.value.destroy();
        chart.value = null;
    }
});

defineExpose({ toggleStacked, toggleSerie });
</script>

<style scoped>
.ts-chart-wrapper { position: relative; }
</style>
