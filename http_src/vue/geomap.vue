<template>
    <div class="geomap-container" ref="mapContainer">
        <Loading :isLoading="isLoading"></Loading>
        <!-- Zoom button group -->
        <div class="btn-group btn-ontop" role="group">
            <button type="button" class="btn zoom-btn" @click="zoomChart(0.5)">
                <i class="fa-solid fa-magnifying-glass-plus" data-bs-toggle="tooltip" data-bs-placement="top" :title="_i18n('date_time_range_picker.btn_zoom_in')"></i>
            </button>
            <button type="button" class="btn zoom-btn" @click="zoomChart(-0.5)">
                <i class="fa-solid fa-magnifying-glass-minus" data-bs-toggle="tooltip" data-bs-placement="top" :title="_i18n('date_time_range_picker.btn_zoom_out')"></i>
            </button>
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
import formatterUtils from '../utilities/formatter-utils.js'

import worldAtlasData from 'world-atlas/countries-110m.json'
import * as topojson from "topojson-client"
const _i18n = (t) => i18n(t);

const d3 = d3v7
let zoom = null
const DOT_RADIUS = 1.6

// Taken from scripts/lua/modules/country_keys.lua
const ISO_ALPHA2_TO_NUMERIC = {
  AF:'004',AL:'008',DZ:'012',AS:'016',AD:'020',AO:'024',AI:'660',AQ:'010',AG:'028',AR:'032',
  AM:'051',AW:'533',AU:'036',AT:'040',AZ:'031',BS:'044',BH:'048',BD:'050',BB:'052',BY:'112',
  BE:'056',BZ:'084',BJ:'204',BM:'060',BT:'064',BO:'068',BQ:'535',BA:'070',BW:'072',BV:'074',
  BR:'076',IO:'086',BN:'096',BG:'100',BF:'854',BI:'108',CV:'132',KH:'116',CM:'120',CA:'124',
  KY:'136',CF:'140',TD:'148',CL:'152',CN:'156',CX:'162',CC:'166',CO:'170',KM:'174',CD:'180',
  CG:'178',CK:'184',CR:'188',HR:'191',CU:'192',CW:'531',CY:'196',CZ:'203',CI:'384',DK:'208',
  DJ:'262',DM:'212',DO:'214',EC:'218',EG:'818',SV:'222',GQ:'226',ER:'232',EE:'233',SZ:'748',
  ET:'231',FK:'238',FO:'234',FJ:'242',FI:'246',FR:'250',GF:'254',PF:'258',TF:'260',GA:'266',
  GM:'270',GE:'268',DE:'276',GH:'288',GI:'292',GR:'300',GL:'304',GD:'308',GP:'312',GU:'316',
  GT:'320',GG:'831',GN:'324',GW:'624',GY:'328',HT:'332',HM:'334',VA:'336',HN:'340',HK:'344',
  HU:'348',IS:'352',IN:'356',ID:'360',IR:'364',IQ:'368',IE:'372',IM:'833',IL:'376',IT:'380',
  JM:'388',JP:'392',JE:'832',JO:'400',KZ:'398',KE:'404',KI:'296',KP:'408',KR:'410',KW:'414',
  KG:'417',LA:'418',LV:'428',LB:'422',LS:'426',LR:'430',LY:'434',LI:'438',LT:'440',LU:'442',
  MO:'446',MG:'450',MW:'454',MY:'458',MV:'462',ML:'466',MT:'470',MH:'584',MQ:'474',MR:'478',
  MU:'480',YT:'175',MX:'484',FM:'583',MD:'498',MC:'492',MN:'496',ME:'499',MS:'500',MA:'504',
  MZ:'508',MM:'104',NA:'516',NR:'520',NP:'524',NL:'528',NC:'540',NZ:'554',NI:'558',NE:'562',
  NG:'566',NU:'570',NF:'574',MP:'580',NO:'578',OM:'512',PK:'586',PW:'585',PS:'275',PA:'591',
  PG:'598',PY:'600',PE:'604',PH:'608',PN:'612',PL:'616',PT:'620',PR:'630',QA:'634',MK:'807',
  RO:'642',RU:'643',RW:'646',RE:'638',BL:'652',SH:'654',KN:'659',LC:'662',MF:'663',PM:'666',
  VC:'670',WS:'882',SM:'674',ST:'678',SA:'682',SN:'686',RS:'688',SC:'690',SL:'694',SG:'702',
  SX:'534',SK:'703',SI:'705',SB:'090',SO:'706',ZA:'710',GS:'239',SS:'728',ES:'724',LK:'144',
  SD:'729',SR:'740',SJ:'744',SE:'752',CH:'756',SY:'760',TW:'158',TJ:'762',TZ:'834',TH:'764',
  TL:'626',TG:'768',TK:'772',TO:'776',TT:'780',TN:'788',TR:'792',TM:'795',TC:'796',TV:'798',
  UG:'800',UA:'804',AE:'784',GB:'826',US:'840',UM:'581',UY:'858',UZ:'860',VU:'548',VE:'862',
  VN:'704',VG:'092',VI:'850',WF:'876',EH:'732',YE:'887',ZM:'894',ZW:'716',AX:'248',
}

const props = defineProps({
    tooltipFormatter: Function,
    geomapDataArray: Array,
    glowDots: Boolean,
    onMapClick: Function,
    showTooltipOnHover: { type: Boolean, default: true },
    // Array of { country: "IT", value: Number } — alpha-2 codes, enables heatmap mode
    countryHeatmap: { type: Array, default: null },
    // formatterUtils type key e.g. "bytes", "number", "bps" — used to format heatmap tooltip value
    heatmapUnit: { type: String, default: 'number' },
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
let hide_timer = null;


const onTooltipMouseEnter = () => {
    if (hide_timer) { clearTimeout(hide_timer); hide_timer = null; }
}

const onTooltipMouseLeave = () => {
    hide_timer = setTimeout(() => {
        if (tooltip.value.show) closeTooltip()
    }, 200)
}

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
        .fitSize([width, height], worldData)

    path = d3.geoPath().projection(projection)

    // Draw countries

    g.selectAll('path.country')
        .data(worldData.features)
        .enter()
        .append('path')
        .attr('class', 'country')
        .attr('d', path)
        .attr('fill', d => _countryFill(d))
        .attr('stroke', '#334155')
        .attr('stroke-width', 0.5)
        .style('cursor', 'pointer')
        .on('click', function (event) {
            event.stopPropagation()

            // Restore previous highlight without toggling off
            if (highlightedCountry && highlightedCountry !== this) {
                const prev = d3.select(highlightedCountry)
                prev.attr('fill', _countryFill(prev.datum()))
            }

            if (highlightedCountry !== this) {
                d3.select(this).attr('fill', '#475569')
                highlightedCountry = this
            }

            if (typeof props.onMapClick === 'function') {
                const [lng, lat] = getLatLngFromEvent(event)
                props.onMapClick({ lat, lng })
            }
        })
        .on('mouseover', function (event) {
            if (!props.countryHeatmap || props.countryHeatmap.length === 0) return
            const feature = d3.select(this).datum()
            const name = feature?.properties?.name
            if (!name) return
            const [mouseX, mouseY] = d3.pointer(event, mapContainer.value)
            let content = `<b>${name}</b>`
            const index = _buildHeatmapIndex()
            const featureId = String(feature?.id).padStart(3, '0')
            const val = index[featureId]
            if (val != null) {
                const fmt = formatterUtils.getFormatter(props.heatmapUnit || 'number')
                content += `<br>${fmt(val)}`
            }
            tooltip.value = { show: true, x: mouseX + 12, y: mouseY - 10, content }
        })
        .on('mouseout', function () {
            tooltip.value.show = false
        })

    // Skip labels when heatmap
    if (props.countryHeatmap && props.countryHeatmap.length > 0) {
        isLoading.value = false
        zoom = d3.zoom()
            .scaleExtent([1, 60])
            .on('zoom', (event) => {
                zoomGroup.attr('transform', event.transform)
                const k = event.transform.k
                let newRadius = DOT_RADIUS / k
                if (newRadius > DOT_RADIUS) newRadius = DOT_RADIUS
                if (newRadius < 0.15) newRadius = 0.15
                g.selectAll(".alert-dot").attr("r", newRadius).attr("stroke-width", 0.5 / k)
            })
        svg.call(zoom)
        return
    }
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
            if (newRadius < 0.15) newRadius = 0.15

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

// Build a lookup map { numericId -> value } once when heatmap data changes
const _buildHeatmapIndex = () => {
    if (!props.countryHeatmap || props.countryHeatmap.length === 0) return null
    const index = {}
    for (const entry of props.countryHeatmap) {
        const numId = ISO_ALPHA2_TO_NUMERIC[entry.country]
        if (numId) index[numId] = entry.value
    }
    return index
}

// Returns the base fill for a country feature, applying heatmap if active
const _countryFill = (feature) => {
    if (!props.countryHeatmap || props.countryHeatmap.length === 0) return '#1e293b'
    const index = _buildHeatmapIndex()
    const featureId = String(feature?.id).padStart(3, '0')
    const val = index[featureId]
    if (val == null) return '#1e293b'
    const values = props.countryHeatmap.map(c => c.value)
    const maxVal = Math.max(...values)
    const minVal = Math.min(...values)
    const t = maxVal === minVal ? 1 : (val - minVal) / (maxVal - minVal)
    return d3.interpolateRgb('#7a3000', '#FF8F00')(t)
}

const _applyHeatmap = () => {
    if (!g) return
    g.selectAll('path.country')
        .attr('fill', d => _countryFill(d))
}

const displayData = () => {
    if (!worldData || !g) return

    g.selectAll('.alert-group').remove()

    // Heatmap mode: color countries, skip dots
    if (props.countryHeatmap && props.countryHeatmap.length > 0) {
        _applyHeatmap()
        return
    }

    const sample = geomapDataArray.value?.[0]
    const isCoordinateBased = sample && 'lat' in sample && 'lng' in sample

    if (isCoordinateBased) {
        renderDotsByCoordinates()
    }
}

///////////////////////////////
const renderDotsByCoordinates = () => {
    geomapDataArray.value.forEach(alert => {
        const latitude = alert.lat;
        const longitude = alert.lng;
        const color = '#FF8F00';

        if (latitude == null || longitude == null) return;

        const coordinates = projection([longitude, latitude]);
        if (!coordinates || isNaN(coordinates[0]) || isNaN(coordinates[1])) return;

        const [x, y] = coordinates;

        const nodeGroup = g.append('g')
            .attr('class', 'alert-group')
            .attr('transform', `translate(${x}, ${y})`)
            .style('cursor', 'pointer');

        nodeGroup.append('circle')
            .attr('class', 'alert-dot')
            .attr('r', DOT_RADIUS)
            .attr('fill', color)
            .attr('stroke', '#ffffff')
            .attr('stroke-width', 0.5)
            .attr('data-original-radius', DOT_RADIUS)
            .attr('data-original-color', color);

        nodeGroup.on('click', function (event) {
            if (hide_timer) { clearTimeout(hide_timer); hide_timer = null; }
            showTooltip(event, alert);
        });
        nodeGroup.on('mouseover', function (event) {
            if (hide_timer) { clearTimeout(hide_timer); hide_timer = null; }
            if (props.showTooltipOnHover) {
                showTooltip(event, alert);
            }
        });
        nodeGroup.on('mouseout', function (event) {
            // Delay close so the user can move the pointer to the tooltip without it disappearing
            hide_timer = setTimeout(() => {
                if (tooltip.value.show) closeTooltip();
            }, 200);
        });
    });
};

const showTooltip = (eventName, alert) => {
// prevent map click handler from firing
    eventName.stopPropagation();
    const tooltipContent = props.tooltipFormatter(alert);

    // get mouse position to put tooltip
    const [mouseX, mouseY] = d3.pointer(eventName, mapContainer.value);

    // show tooltip
    tooltip.value = {
        show: true,
        x: mouseX,
        y: mouseY,
        content: tooltipContent,
        targetElement: this
    };

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

watch(() => props.countryHeatmap, () => {
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
    /* overflow: visible so the tooltip is not clipped; the SVG is clipped separately */
    overflow: visible;
    font-family: 'Inter', 'Segoe UI', sans-serif;
}

.graph-svg,
:deep(svg) {
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
    right: 10px;
    top: 10px;
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