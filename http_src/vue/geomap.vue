<template>
    <div class="geomap-container" ref="mapContainer">
        <Loading :isLoading="isLoading"></Loading>
        <!-- Zoom button group -->
        <div class="mb-2">
            <div class="btn-group btn-ontop" role="group">
                <button type="button" class="btn zoom-btn" @click="zoomChart(0.5)">
                    <i class="fa-solid fa-magnifying-glass-plus" data-bs-toggle="tooltip" data-bs-placement="top" :title="_i18n('date_time_range_picker.btn_zoom_in')"></i>
                </button>
                <button type="button" class="btn zoom-btn" @click="zoomChart(-0.5)">
                    <i class="fa-solid fa-magnifying-glass-minus" data-bs-toggle="tooltip" data-bs-placement="top" :title="_i18n('date_time_range_picker.btn_zoom_out')"></i>
                </button>
            </div>
        </div>

        <!-- Tooltip -->
        <div v-if="tooltip.show" ref="tooltipRef" class="static-tooltip" :style="{
            left: tooltip.x + 'px',
            top: tooltip.y + 'px'
        }" @mouseenter="onTooltipMouseEnter" @mouseleave="onTooltipMouseLeave">
            <div class="static-tooltip-content">
                <div class="tooltip-header">

                    <button @click="closeTooltip" class="close-btn" type="button" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div v-html="tooltip.content"></div>
            </div>
        </div>

        <svg ref="svgElement" width="100%" height="100vh"></svg>
    </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'
import Loading from "./loading.vue"

import worldAtlasData from 'world-atlas/countries-110m.json'
import * as topojson from "topojson-client"
const _i18n = (t) => i18n(t);

const d3 = d3v7
let zoom = null
const DOT_RADIUS = 1.6

const props = defineProps({
    tooltipFormatter: Function,
    geomapDataArray: Array,
    glowDots: Boolean,
    onMapClick: Function,
    showTooltipOnHover: { type: Boolean, default: true }
})

const geomapDataArray = ref(props.geomapDataArray || [])

const mapContainer = ref(null)
const svgElement = ref(null)
const isLoading = ref(true)

const tooltip = ref({
    show: false,
    x: 0,
    y: 0,
    content: '',
    targetElement: null
})

let svg = null
let projection = null
let path = null
let g = null
let zoomGroup = null
let worldData = null
let resizeObserver = null
let highlightedCountry = null

const initializeMap = async () => {
    if (!mapContainer.value || !svgElement.value) return

    isLoading.value = true

    // Convert TopoJSON -> GeoJSON ONCE
    worldData = topojson.feature(
        worldAtlasData,
        worldAtlasData.objects.countries
    )

    const rect = mapContainer.value.getBoundingClientRect()
    const width = rect.width
    const height = rect.height

    d3.select(svgElement.value).selectAll('*').remove()

    svg = d3.select(svgElement.value)
        .attr('width', width)
        .attr('height', height)
        .attr('viewBox', [0, 0, width, height])

    zoomGroup = svg.append('g')
    g = zoomGroup.append('g');

    projection = d3.geoEquirectangular()
        .scale(width / (2 * Math.PI) * 0.9)
        .translate([width / 2, height / 2])

    path = d3.geoPath().projection(projection)

    // Draw countries

    g.selectAll('path.country')
        .data(worldData.features)
        .enter()
        .append('path')
        .attr('class', 'country')
        .attr('d', path)
        .attr('fill', '#1e293b')
        .attr('stroke', '#334155')
        .attr('stroke-width', 0.5)
        .style('cursor', 'pointer')
        .on('click', function (event) {
            event.stopPropagation()

            if (highlightedCountry) {
                d3.select(highlightedCountry).attr('fill', '#1e293b')
            }

            d3.select(this).attr('fill', '#475569')
            highlightedCountry = this

            if (typeof props.onMapClick === 'function') {
                const [lng, lat] = getLatLngFromEvent(event)
                props.onMapClick({ lat, lng })
            }
        })

    // Labels
    g.append("g")
        .attr("class", "country-labels")
        .selectAll("text")
        .data(worldData.features.filter(d => path.area(d) > 60))
        .enter()
        .append("text")
        .attr("class", "country-label")
        .attr("transform", d => {
            let geom = d.geometry;

            // For MultiPolygon, pick the largest polygon by area
            if (geom.type === "MultiPolygon") {
                let largest = geom.coordinates.reduce((maxPoly, poly) => {
                    const area = d3.geoArea({ type: "Polygon", coordinates: poly });
                    return area > maxPoly.area ? { coords: poly, area } : maxPoly;
                }, { coords: geom.coordinates[0], area: 0 });
                geom = { type: "Polygon", coordinates: largest.coords };
            }

            const [x, y] = path.centroid({ type: geom.type, coordinates: geom.coordinates });
            return `translate(${x}, ${y})`;
        })
        .attr("text-anchor", "middle")
        .attr("alignment-baseline", "middle")
        .attr("font-size", "8px")
        .attr("fill", "#94a3b8")
        .attr("pointer-events", "none")
        .text(d => d.properties.name || "")


    // Zoom

    zoom = d3.zoom()
        .scaleExtent([1, 60])
        .on('zoom', (event) => {
            zoomGroup.attr('transform', event.transform)

            const k = event.transform.k
            let newRadius = DOT_RADIUS / k
            if (newRadius > DOT_RADIUS) newRadius = DOT_RADIUS
            if (newRadius < 0.3) newRadius = 0.3

            g.selectAll(".alert-dot")
                .attr("r", newRadius)
                .attr("stroke-width", 0.5 / k)

            g.selectAll(".country-label")
                .attr("font-size", `${8 / k}px`)

            const textScale = Math.max(1 / k, 0.15)

            g.selectAll(".country-label")
                .attr("transform", d => {
                    const [x, y] = path.centroid(d)
                    return `translate(${x}, ${y}) scale(${textScale})`
                })
        })

    svg.call(zoom)

    isLoading.value = false
}

const displayData = () => {
    if (!worldData || !g) return

    g.selectAll('.alert-group').remove()

    const sample = geomapDataArray.value?.[0]
    const isCoordinateBased = sample && 'lat' in sample && 'lng' in sample

    if (isCoordinateBased) {
        renderDotsByCoordinates()
    }
}

const renderDotsByCoordinates = () => {
    geomapDataArray.value.forEach(alert => {
        if (alert.lat == null || alert.lng == null) return

        const [x, y] = projection([alert.lng, alert.lat])
        if (!x || !y) return

        const node = g.append('g')
            .attr('class', 'alert-group')
            .attr('transform', `translate(${x}, ${y})`)
            .style('cursor', 'pointer')

        node.append('circle')
            .attr('class', 'alert-dot')
            .attr('r', DOT_RADIUS)
            .attr('fill', alert.color || '#FF8F00')
            .attr('stroke', '#ffffff')
            .attr('stroke-width', 0.5)
            .attr('vector-effect', 'non-scaling-stroke')

        node.on('click', (event) => {
            event.stopPropagation()
            showTooltip(event, alert)
        })
    })
}

const zoomChart = (direction) => {
    if (!svg || !zoom) return

    // 1.2 is a common multiplier for smooth zooming
    // If direction is positive (0.5), it zooms in. If negative (-0.5), it zooms out.
    const factor = direction > 0 ? 1.5 : 0.66

    svg.transition()
       .duration(300)
       .call(zoom.scaleBy, factor)
}

//////////////////////////////////////////////
// TOOLTIP

const showTooltip = (event, alert) => {
    const [mouseX, mouseY] = d3.pointer(event, mapContainer.value)

    tooltip.value = {
        show: true,
        x: mouseX + 15,
        y: mouseY + 10,
        content: props.tooltipFormatter
            ? props.tooltipFormatter(alert)
            : JSON.stringify(alert),
        targetElement: null
    }
}

const closeTooltip = () => {
    tooltip.value.show = false
}


function getLatLngFromEvent(event) {
    const [x, y] = d3.pointer(event, zoomGroup.node())
    return projection.invert([x, y])
}

onMounted(async () => {
    await nextTick()
    await initializeMap()
    displayData()

    resizeObserver = new ResizeObserver(async () => {
        await initializeMap()
        displayData()
    })

    resizeObserver.observe(mapContainer.value)
})

watch(() => props.geomapDataArray, (newVal) => {
    geomapDataArray.value = newVal || []
    displayData()
}, { deep: true })

onUnmounted(() => {
    if (resizeObserver) resizeObserver.disconnect()
})
</script>

<style scoped>
.geomap-container {
    position: relative;
    width: 100%;
    height: 100%;
    min-height: 500px;
    background-color: #0f172a;
    border-radius: 8px;
    /* overflow: visible so the tooltip is not clipped; the SVG is clipped separately */
    overflow: visible;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.5);
    font-family: 'Inter', 'Segoe UI', sans-serif;
}

.graph-svg,
:deep(svg) {
    border-radius: 8px;
    overflow: hidden;
}

.static-tooltip {
    position: absolute;
    z-index: 1000;
    pointer-events: auto;
    background-color: rgba(15, 23, 42, 0.95);
    border: 1px solid #334155;
    border-radius: 8px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(10px);
    min-width: 200px;
    max-width: 300px;
    color: #e2e8f0;
}

.static-tooltip-content {
    position: relative;
    padding: 12px;
}

.tooltip-header {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 8px;
}

.close-btn {
    background: none;
    border: none;
    color: #e2e8f0;
    font-size: 18px;
    font-weight: bold;
    cursor: pointer;
    padding: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: all 0.2s ease;
}

.close-btn:hover {
    background-color: rgba(255, 255, 255, 0.1);
    color: #ffffff;
}

.close-btn:focus {
    outline: none;
    box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
}

:deep(.custom-tooltip-content) {
    color: #e2e8f0;
}

:deep(.custom-tooltip-content h6) {
    color: #ffffff;
    margin-bottom: 8px;
}

:deep(.custom-tooltip-content hr) {
    border-color: rgba(148, 163, 184, 0.3);
}

:deep(.custom-tooltip-content .flag) {
    width: 16px;
    height: 12px;
    margin-right: 8px;
}

:deep(.custom-tooltip-content .badge) {
    font-size: 0.75rem;
}

.map-controls {
    position: absolute;
    top: 15px;
    right: 15px;
    z-index: 5;
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.control-button {
    background-color: rgba(15, 23, 42, 0.8);
    color: #e2e8f0;
    border: 1px solid rgba(148, 163, 184, 0.3);
    border-radius: 4px;
    padding: 8px 12px;
    font-size: 12px;
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    transition: all 0.2s;
}

.control-button:hover {
    background-color: rgba(30, 41, 59, 0.9);
    border-color: rgba(148, 163, 184, 0.5);
}

.button-icon {
    font-size: 14px;
}

.legend {
    background-color: rgba(15, 23, 42, 0.8);
    border-radius: 4px;
    padding: 10px;
    border: 1px solid rgba(148, 163, 184, 0.3);
}

.legend-title {
    color: #e2e8f0;
    font-size: 12px;
    font-weight: 600;
    margin-bottom: 8px;
    border-bottom: 1px solid rgba(148, 163, 184, 0.2);
    padding-bottom: 4px;
}

.legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #e2e8f0;
    font-size: 11px;
    margin-bottom: 5px;
}

.severity-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
}

.severity-dot.critical {
    background-color: #ff2d55;
    box-shadow: 0 0 5px rgba(255, 45, 85, 0.7);
}

.severity-dot.high {
    background-color: #ff9500;
    box-shadow: 0 0 5px rgba(255, 149, 0, 0.7);
}

.severity-dot.medium {
    background-color: #ffcc00;
    box-shadow: 0 0 5px rgba(255, 204, 0, 0.7);
}

.severity-dot.low {
    background-color: #5cd65c;
    box-shadow: 0 0 5px rgba(92, 214, 92, 0.7);
}

/* Basic styling for map elements */
:deep(.country) {
    transition: fill 0.3s ease;
}

:deep(.alert-dot) {
    transition: r 0.2s ease;
}

/* Pulse animation */
@keyframes pulse {
    0% {
        transform: scale(1);
        opacity: 0.8;
    }

    100% {
        transform: scale(3);
        opacity: 0;
    }
}

:deep(.pulse-circle) {
    animation: pulse 1.5s infinite ease-out;
}

:deep(.country-label) {
    fill: #94a3b8;
    font-size: 8px;
    pointer-events: none;
    user-select: none;
    transition: opacity 0.2s ease;
}

/* zoom controls */
.btn-ontop {
    position: absolute;
    right: 0;
    top: -0.7rem;
    z-index: 10;
}

.zoom-btn {
    background-color: #fd7e14 !important;
    color: white !important;
    border: none !important;
    height: 24px;
    display: flex;
    align-items: center;
    padding: 0 8px;
}

.zoom-btn:hover {
    background-color: #e76b06 !important;
}
</style>