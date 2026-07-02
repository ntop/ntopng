<!--
  (C) 2026 - ntop.org
-->
<template>
    <div ref="container" class="line-container">
        <div v-if="chart.title" class="line-title"><strong>{{ chart.title }}</strong></div>
        <Loading v-if="!props.hideLoading" :isLoading="loading" />
        <NoData :show="no_data"></NoData>
        <div class="line-body">
            <!-- legend-div -->
            <div v-if="!loading && series.length && !no_data && !isPresence" class="d-flex align-items-center">
                <!-- Timeseries visibility toggles - dynamically generated checkboxes -->
                <div class="ms-auto" style="overflow-x: auto; white-space: nowrap;">
                    <label class="form-check-label form-control-sm" v-for="(s, i) in series" :key="i"
                        :class="{ dimmed: hiddenSeries.has(s.label) }">
                        <input type="checkbox" class="form-check-input align-middle mt-0" @click="toggleSeries(s.label)"
                            :checked="true" style="border-color: #0d6efd;" :style="{ backgroundColor: s.color }">
                        {{ s.label }}
                    </label>
                </div>
            </div>
            <div ref="wrapper" class="line-wrapper" v-show="!loading && !no_data"></div>
            <div v-if="!loading && tooltip.visible" class="line-tooltip"
                :style="{ top: tooltip.y + 'px', left: tooltip.x + 'px', transform: tooltip.flipLeft ? 'translateX(-100%)' : 'none' }">
                <h6 v-if="tooltip.xLabel">
                    <span class="badge bg-light mb-1 text-dark">{{ tooltip.xLabel }}</span>
                </h6>
                <div class="mt-1 d-flex" v-for="(row, i) in tooltip.rows" :key="i">
                    <div class="me-4">
                        <!-- Label -->
                        <span class="badge rounded-pill me-1" :style="row.present === false
                            ? { 'background-color': 'transparent' }
                            : { 'background-color': row.color }">{{ " " }}</span>
                        {{ row.label != null ? row.label : (row.present === false ? 'No data' : 'Available') }}
                    </div>
                    <div class="ms-auto">
                        {{ row.value != null ? row.value : "" }}
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount, nextTick, watch } from "vue";
import { default as Loading } from "../loading.vue";
import colorUtils from "../../utilities/color-utils.js";
import formatterUtils from "../../utilities/formatter-utils.js";
import dataUtils from "../../utilities/data-utils.js";
import NoData from '../components/no-data.vue';

const d3 = d3v7;

const props = defineProps({ chart: { type: Object, required: true }, hideLoading: Boolean });
const { refresh, unit, label, custom_fetch } = props.chart;
const formatted_label = label ? (i18n(label) || label) : null;

const container = ref(null);
const wrapper = ref(null);
const loading = ref(false);
const no_data = ref(false);
const series = ref([]);
const has_loaded = ref(false);
const hiddenSeries = ref(new Set());
const isPresence = ref(false);
const emit = defineEmits(["chart-updated", "update-requested"]);
const tooltip = reactive({ visible: false, x: 0, y: 0, flipLeft: false, xLabel: "", rows: [] });

const M = { top: 10, right: 48, bottom: 30, left: 75 };

let svgEl = null;
let gChart = null;
let xScale = null;
let yScale = null;
let clipId = null;
let currentData = null;
let refreshTimer = null;
let isUnixTs = false;
let isDateAxis = false;
let parseX = null;
let iW_last = 0;
let fmtDate_last = null;
let fmtDate_tip = null;

let hoverLine = null;
let hoverDots = [];
let hoverXLabel = null;
let resizeObs = null;

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

function buildSVG() {
    if (!wrapper.value) return;
    wrapper.value.replaceChildren();
    clipId = `clip-${Math.random().toString(36).slice(2)}`;

    svgEl = d3.select(wrapper.value)
        .append("svg")
        .attr("width", "100%")
        .attr("height", "100%")
        .style("display", "block")

    svgEl.append("defs").append("clipPath").attr("id", clipId).append("rect");
    svgEl.append("g").attr("class", "grid-y");
    gChart = svgEl.append("g").attr("class", "chart-area").attr("clip-path", `url(#${clipId})`);
    svgEl.append("g").attr("class", "axis-x");
    svgEl.append("g").attr("class", "axis-y");
    /* Overlay on top — captures mouse, same transform as gChart */
    svgEl.append("rect").attr("class", "mouse-overlay")
        .attr("fill", "rgba(0,0,0,0)")
        .attr("stroke", "none")
        .attr("pointer-events", "all");
}

/* Data fetch */
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
        no_data.value = false;
        has_loaded.value = true;
        currentData = norm;
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

/* Presence data chart (alerts and historical charts) / presence renderer */
function renderSwimlane(data, W, _H, iW, iH) {
    const MP = { top: 14, right: 28, bottom: 14, left: 40 };
    const swimH = Math.max(16, Math.min(32, (iH - (data.length - 1) * 4) / Math.max(data.length, 1)));
    const totalH = data.length * (swimH + 4) - 4;

    svgEl.select(`#${clipId} rect`).attr("width", iW).attr("height", totalH + 4);

    const tx = `translate(${MP.left},${MP.top})`;
    gChart.attr("transform", tx);
    svgEl.select(".grid-y").selectAll("*").remove();
    svgEl.select(".axis-y").selectAll("*").remove();

    /* X axis at bottom of swimlanes */
    svgEl.select(".axis-x").attr("transform", `translate(${MP.left},${MP.top + totalH})`);
    const nXTicks = Math.max(2, Math.min(6, Math.floor(iW / 90)));
    const axX = svgEl.select(".axis-x");
    axX.call(d3.axisBottom(xScale).ticks(nXTicks).tickSizeOuter(0).tickSize(4).tickFormat(fmtDate_last));
    axX.select("path.domain").style("stroke", "var(--loading-text-color)").style("fill", "none");
    axX.selectAll(".tick line").style("stroke", "var(--loading-text-color)");
    axX.selectAll(".tick text").style("fill", "var(--loading-text-color)").style("font-size", "11px");

    /* Overlay for hover */
    svgEl.select(".mouse-overlay")
        .attr("x", MP.left).attr("y", MP.top).attr("width", iW).attr("height", totalH);

    /* Clear and draw swimlanes */
    gChart.selectAll("*").remove();
    iW_last = iW;

    const ACTIVE_COLOR = "#6FCF97";
    const BG_COLOR = "none";
    const BG_STROKE = "rgba(111,207,151,0.5)";
    series.value = data.map(s => ({ label: s.label, color: ACTIVE_COLOR }));

    const [xMin, xMax] = d3.extent(data.flatMap(s => s.data.map(d => parseX(d.x))));
    const stepMs = data.flatMap(s => {
        const pts = s.data.map(d => parseX(d.x).getTime()).sort((a, b) => a - b);
        return pts.slice(1).map((v, i) => v - pts[i]);
    }).filter(v => v > 0);
    const slotMs = stepMs.length ? Math.min(...stepMs) : (xMax - xMin) / Math.max(data[0]?.data.length - 1, 1);

    data.forEach((s, si) => {
        const y0 = si * (swimH + 4);

        /* Row background — outline only, empty when no data */
        gChart.append("rect")
            .attr("x", 0).attr("y", y0).attr("width", iW).attr("height", swimH)
            .attr("fill", BG_COLOR).attr("stroke", BG_STROKE).attr("stroke-width", 1).attr("rx", 3);

        /* Label on Y axis */
        svgEl.select(".axis-y").append("text")
            .attr("x", -4).attr("y", MP.top + y0 + swimH / 2)
            .attr("text-anchor", "end").attr("dominant-baseline", "central")
            .attr("fill", "var(--loading-text-color)").attr("font-size", "11px")
            .text(s.label.length > 10 ? s.label.slice(0, 9) + "…" : s.label);

        /* Present segments — vivid green */
        s.data.filter(d => d.y).forEach(d => {
            const px = xScale(parseX(d.x));
            const pw = Math.max(2, xScale(new Date(parseX(d.x).getTime() + slotMs)) - px - 1);
            gChart.append("rect")
                .attr("x", px).attr("y", y0).attr("width", pw).attr("height", swimH)
                .attr("fill", ACTIVE_COLOR).attr("rx", 2);
        });
    });

    /* Hover */
    svgEl.select(".mouse-overlay")
        .on("mousemove", function (ev) { onSwimlaneMove(ev, data, ACTIVE_COLOR, MP); })
        .on("mouseleave", () => { tooltip.visible = false; });
}

function renderChart(data) {
    if (!wrapper.value || !svgEl) return;

    const W = wrapper.value.clientWidth || 400;
    const H = wrapper.value.clientHeight || Math.round((wrapper.value.clientWidth || 400) * 5 / 16);

    const iW = W - M.left - M.right;
    const iH = H - M.top - M.bottom;
    if (iW <= 0 || iH <= 0) return;
    iW_last = iW;

    /* Colours */
    const PALETTE = colorUtils.assignRoundRobinColors(data.map(s => s.label));
    series.value = data.map((s, i) => {
        const serie_label = i18n("db_explorer." + s.label) ? i18n("db_explorer." + s.label) : s.label;
        return {
            label: serie_label, color: s.color || PALETTE[i % PALETTE.length], url: s.url || null,
        }
    });
    const getColor = (s, i) => series.value[i]?.color || PALETTE[i % PALETTE.length];

    const vis = data.filter(s => !hiddenSeries.value.has(s.label));
    const allX = vis.flatMap(s => s.data.map(d => d.x));
    const allY = vis.flatMap(s => s.data.map(d => d.y));
    if (!allX.length) return;

    /* X type detection — distinguish Unix-ms (13-digit) from Unix-s (10-digit) */
    const isUnixMs = typeof allX[0] === "number" && allX[0] >= 1_000_000_000_000;
    isUnixTs = !isUnixMs && typeof allX[0] === "number" && allX[0] > 1_000_000_000;
    isDateAxis = isUnixMs || isUnixTs || allX[0] instanceof Date
        || (typeof allX[0] === "string" && !isNaN(Date.parse(allX[0])));
    const isOrd = !isDateAxis && typeof allX[0] === "string";

    parseX = isUnixMs ? v => new Date(+v)
        : isUnixTs ? v => new Date(+v * 1000)
            : isDateAxis ? v => (v instanceof Date ? v : new Date(String(v).replace(' ', 'T')))
                : isOrd ? v => v
                    : v => +v;

    const xVals = allX.map(parseX);
    xScale = isOrd ? d3.scalePoint().domain([...new Set(xVals)]).range([0, iW]).padding(0.5)
        : isDateAxis ? d3.scaleTime().domain(d3.extent(xVals)).range([0, iW]).nice()
            : d3.scaleLinear().domain(d3.extent(xVals)).range([0, iW]).nice();

    /* Date formatters — needed by both Presence data chart (alerts and historical charts) and line chart */
    const toUtcS = v => {
        if (v instanceof Date) return v.getTime() / 1000;
        const n = +v;
        return isUnixMs ? n / 1000 : isUnixTs ? n : NaN;
    };
    const spanMs = xVals.length > 1 ? (d3.extent(xVals)[1] - d3.extent(xVals)[0]) : 0;
    fmtDate_last = v => {
        const s = toUtcS(v);
        if (isNaN(s)) return String(v);
        const d = formatterUtils.utc_s_to_server_date(s);
        if (spanMs <= 2 * 3600e3) {
            return d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false });
        } else if (spanMs <= 4 * 86400e3) {
            const date = d.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' });
            const time = d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false });
            return `${date} ${time}`;
        } else {
            return d.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' });
        }
    };
    fmtDate_tip = v => {
        const s = toUtcS(v);
        if (isNaN(s)) return String(v);
        return formatterUtils.formatDateTime(s);
    };

    /* Presence / Presence data chart (alerts and historical charts) mode */
    const presence = !!props.chart.presence
        || (allY.length > 0 && allY.every(v => v === 0 || v === 1));
    isPresence.value = presence;

    if (presence) {
        renderSwimlane(data, W, H, iW, iH);
        return;
    }

    const stacked = !!props.chart.stacked;
    let stackedLayers = null;
    let yMax = d3.max(allY);

    if (stacked && vis.length > 1) {
        const allXSet = [...new Set(vis.flatMap(s => s.data.map(d => String(d.x))))];
        const rows = allXSet.map(xk => {
            const row = { __x: xk };
            vis.forEach(s => {
                const pt = s.data.find(d => String(d.x) === xk);
                row[s.label] = pt?.y ?? 0;
            });
            return row;
        });
        const stackGen = d3.stack().keys(vis.map(s => s.label)).value((r, k) => r[k] || 0);
        stackedLayers = stackGen(rows);
        yMax = d3.max(stackedLayers[stackedLayers.length - 1], seg => seg[1]);
    }

    yScale = d3.scaleLinear().domain([0, yMax || 1]).range([iH, 0]).nice();
    /* nice() may push min below 0 — force it back */
    yScale.domain([0, yScale.domain()[1]]);


    /* SVG size — set explicit height so the chart renders even when parent has no CSS height */
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

    /* X Axis */
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
        .style("stroke", "var(--loading-text-color)")
        .style("stroke-width", "1")
        .style("fill", "none");
    axX.selectAll(".tick line")
        .style("stroke", "var(--loading-text-color)")
        .style("stroke-width", "1");
    axX.selectAll(".tick text")
        .style("fill", "var(--loading-text-color)")
        .style("font-size", "11px");

    /* Y Axis */
    const nYTicks = Math.max(2, Math.min(5, Math.floor(iH / 40)));
    const valFmt = formatterUtils.getFormatter(props.chart.unit || "number", null, null, formatted_label) ?? (v => v);
    const yAxisFn = d3.axisLeft(yScale).ticks(nYTicks).tickFormat(valFmt).tickSizeOuter(0).tickSize(5);

    const axY = svgEl.select(".axis-y");
    axY.call(yAxisFn);
    axY.select("path.domain")
        .style("stroke", "var(--loading-text-color)")
        .style("stroke-width", "1")
        .style("fill", "none");
    axY.selectAll(".tick line")
        .style("stroke", "var(--loading-text-color)")
        .style("stroke-width", "1");
    axY.selectAll(".tick text")
        .style("fill", "var(--loading-text-color)")
        .style("font-size", "11px");

    /* ── Grid lines ── */
    const gridData = yScale.ticks(nYTicks);
    const gridSel = svgEl.select(".grid-y").selectAll("line.gl").data(gridData);
    gridSel.enter().append("line").attr("class", "gl").merge(gridSel)
        .attr("x1", 0).attr("x2", iW)
        .attr("y1", d => yScale(d)).attr("y2", d => yScale(d))
        .attr("stroke", "var(--color-border-tertiary)")
        .attr("stroke-width", "0.5");
    gridSel.exit().remove();

    /* Line / area generators */
    gChart.selectAll("path.area-fill").remove();
    gChart.selectAll("path.line-path").remove();

    if (stackedLayers) {
        /* Stacked area rendering */
        stackedLayers.forEach((layer, li) => {
            const seriesIdx = data.findIndex(s => s.label === layer.key);
            const color = getColor(data[seriesIdx] || {}, seriesIdx);
            const areaStackGen = d3.area()
                .x(d => xScale(parseX(d.data.__x)))
                .y0(d => yScale(d[0]))
                .y1(d => yScale(d[1]))
                .curve(d3.curveMonotoneX);
            gChart.append("path").attr("class", "area-fill")
                .attr("d", areaStackGen(layer))
                .attr("fill", color)
                .attr("fill-opacity", 0.65)
                .attr("stroke", color)
                .attr("stroke-width", 1.2);
        });
    } else {
        /* Normal (non-stacked) area + line */
        const lineGen = d3.line()
            .x(d => xScale(parseX(d.x))).y(d => yScale(d.y))
            .defined(d => d.y != null && !isNaN(d.y)).curve(d3.curveMonotoneX);
        const areaGen = d3.area()
            .x(d => xScale(parseX(d.x))).y0(yScale(0)).y1(d => yScale(d.y))
            .defined(d => d.y != null && !isNaN(d.y)).curve(d3.curveMonotoneX);

        data.forEach((s, i) => {
            const color = getColor(s, i);
            const hidden = hiddenSeries.value.has(s.label);
            gChart.append("path").attr("class", "area-fill")
                .attr("d", areaGen(s.data))
                .attr("fill", color).attr("stroke", "none")
                .attr("opacity", hidden ? 0 : 0.08);
            gChart.append("path").attr("class", "line-path")
                .attr("fill", "none").attr("stroke-linejoin", "round").attr("stroke-linecap", "round")
                .attr("d", lineGen(s.data))
                .attr("stroke", color).attr("stroke-width", "2")
                .attr("opacity", hidden ? 0.12 : 1);
        });
    }

    /* Static dots — only when few data points, never for large series */
    const DOT_THRESH = 30;
    if (!stackedLayers) {
        data.forEach((s, si) => {
            const valid = s.data.filter(d => d.y != null && !isNaN(d.y));
            if (valid.length > DOT_THRESH) return;
            const color = getColor(s, si);
            const hidden = hiddenSeries.value.has(s.label);
            valid.forEach(d => {
                gChart.append("circle")
                    .attr("r", 3.5)
                    .attr("cx", xScale(parseX(d.x)))
                    .attr("cy", yScale(d.y))
                    .attr("fill", color)
                    .attr("stroke", "var(--color-background-primary)")
                    .attr("stroke-width", "1.5")
                    .attr("opacity", hidden ? 0 : 1)
                    .attr("pointer-events", "none");
            });
        });
    }

    /* Mouse handler */
    svgEl.select(".mouse-overlay")
        .on("mousemove", function (ev) { onMove(ev, data, iH); })
        .on("mouseleave", onLeave);
}

/* Presence data chart (alerts and historical charts) mouse */
function onSwimlaneMove(ev, data, ACTIVE_COLOR, MP) {
    const [svgX] = d3.pointer(ev, svgEl.node());
    const cx = svgX - MP.left;
    if (cx < 0 || cx > iW_last) { tooltip.visible = false; return; }

    let best = null, bestDx = Infinity;
    data.forEach(s => s.data.forEach(d => {
        const dx = Math.abs(xScale(parseX(d.x)) - cx);
        if (dx < bestDx) { bestDx = dx; best = d.x; }
    }));
    if (!best) return;

    const rect = container.value.getBoundingClientRect();
    const svgRect = svgEl.node().getBoundingClientRect();
    const flipLeft = cx > iW_last / 2;
    const chartPixelX = MP.left + cx;

    const rows = data.map(s => {
        const present = !!s.data.find(d => String(d.x) === String(best))?.y;
        const serie_label = i18n("db_explorer." + s.label) ? i18n("db_explorer." + s.label) : s.label;
        /* Use an null string in case of s.label being "", undefined or null */
        return { label: serie_label, color: present ? ACTIVE_COLOR : "#888", present };
    });

    Object.assign(tooltip, {
        visible: true,
        x: flipLeft
            ? svgRect.left - rect.left + chartPixelX - 14
            : svgRect.left - rect.left + chartPixelX + 14,
        y: MP.top,
        flipLeft,
        xLabel: fmtDate_tip ? fmtDate_tip(parseX(best)) : fmtDate_last(parseX(best)),
        rows,
    });
}

/* Mouse */
function clearHover() {
    hoverLine?.remove(); hoverLine = null;
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
        const serie_label = i18n("db_explorer." + s.label) ? i18n("db_explorer." + s.label) : s.label;
        const color = series.value.find(sv => sv.label === serie_label)?.color || "#888";
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

    /* Tooltip — find if any series has data at snap point */
    let closePt = null;
    vis.forEach(s => {
        const pt = s.data.find(d => String(d.x) === String(snapRaw));
        if (!pt || pt.y == null) return;
        if (!closePt) closePt = pt;
    });
    if (!closePt) return;

    const curUnit = props.chart.unit || "number";
    const curLabel = props.chart.label ? (i18n(props.chart.label) || props.chart.label) : null;
    const valFmt = formatterUtils.getFormatter(curUnit, null, null, curLabel) ?? (v => v);
    const rect = container.value.getBoundingClientRect();
    const svgRect = svgEl.node().getBoundingClientRect();
    const chartPixelX = M.left + cx;
    const flipLeft = cx > iW_last / 2;
    const xLblTxt = isDateAxis ? (fmtDate_tip ?? fmtDate_last)(parseX(snapRaw)) : String(snapRaw);

    const rows = [];
    const rawValues = [];
    vis.forEach(s => {
        const pt = s.data.find(d => String(d.x) === String(snapRaw));
        if (!pt || pt.y == null || isNaN(pt.y)) return;
        const serie_label = i18n("db_explorer." + s.label) ? i18n("db_explorer." + s.label) : s.label;
        const color = series.value.find(sv => sv.label === serie_label)?.color || "#888";
        rawValues.push({ label: serie_label, value: valFmt(pt.y), rawY: pt.y, color });
    });
    if (!rawValues.length) return;

    rawValues.sort((a, b) => b.rawY - a.rawY);
    rawValues.forEach(({ label, value, color }) => rows.push({ label, value, color }));

    Object.assign(tooltip, {
        visible: true,
        x: flipLeft
            ? svgRect.left - rect.left + chartPixelX - 14
            : svgRect.left - rect.left + chartPixelX + 14,
        y: M.top,
        flipLeft,
        xLabel: xLblTxt,
        rows,
    });

}

/* Toggle / expose / watch */
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
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: stretch;
    width: 100%;
    height: 100%;
    min-width: 0;
    box-sizing: border-box;
}

.line-title {
    flex-shrink: 0;
    margin-bottom: 4px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.line-body {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    flex: 1 1 auto;
    min-height: 0;
    width: 100%;
    height: 100%;
    position: relative;
}

.line-wrapper {
    flex: 1 1 auto;
    min-height: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
}

.line-legend {
    flex-shrink: 0;
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;
    align-items: center;
    gap: 4px 12px;
    overflow: hidden;
}

.legend-item {
    display: flex;
    align-items: center;
    gap: 5px;
    min-width: 0;
    cursor: pointer;
    user-select: none;
    transition: opacity 0.25s ease;
}

.legend-item.dimmed {
    opacity: 0.35;
}

.legend-line-icon {
    width: 24px;
    height: 12px;
    flex-shrink: 0;
}

.legend-name {
    flex: 1 1 0;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.line-tooltip {
    /* layout */
    position: absolute;
    pointer-events: none;
    display: flex;
    flex-direction: column;
    gap: 3px;
    z-index: 9999 !important;

    /* like dygraph-legend */
    color: var(--ntop-text-color);
    background-color: var(--timeseries-legend-bg-color) !important;
    border-color: var(--timeseries-legend-border-color);
    border-style: solid;
    border-width: thin;
    border-radius: 0.375rem;
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, .15);
    padding: 8px !important;
    width: auto;
    word-wrap: break-word;
    white-space: nowrap;

    font-size: 13px;
    line-height: 1.4;
}

.line-tooltip>span {
    color: #111111;
    padding-left: 5px;
    padding-right: 2px;
    margin-left: -5px;
    background-color: #FFFFFF;
}

.line-tooltip>span:first-child {
    margin-top: 2px;
}

.tt-series {
    font-weight: 500;
}

.tt-sep {
    opacity: 0.35;
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
</style>