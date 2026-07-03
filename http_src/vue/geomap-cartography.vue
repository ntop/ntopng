<template>
    <div ref="containerRef" class="deckgl-geomap" :style="{ height: height }">
        <canvas ref="canvasRef" class="deckgl-canvas" />

        <!-- Address / lat,lng search box -->
        <div v-if="enableSearch" class="geomap-search">
            <div class="input-group input-group-sm">
                <input type="text" class="form-control" v-model="searchQuery"
                    placeholder="Search address or 'lat, lng'" @keyup.enter="geocodeSearch" />
                <button type="button" class="btn search-btn" :disabled="geocoding" @click="geocodeSearch">
                    <i class="fa-solid" :class="geocoding ? 'fa-spinner fa-spin' : 'fa-magnifying-glass'"></i>
                </button>
            </div>
            <div v-if="geocodeError" class="geomap-search-error">{{ geocodeError }}</div>
            <ul v-if="searchResults.length" class="geomap-search-results">
                <li v-for="(r, idx) in searchResults" :key="idx" @click="selectSearchResult(r)">
                    {{ r.display_name }}
                </li>
            </ul>
        </div>

        <!-- Control buttons — uniform with other pages -->
        <div class="btn-group btn-ontop" role="group">
            <button type="button" class="btn zoom-btn" @click="zoomIn">
                <i class="fa-solid fa-magnifying-glass-plus" data-bs-toggle="tooltip" data-bs-placement="top" title="Zoom in"></i>
            </button>
            <button type="button" class="btn zoom-btn" @click="zoomOut">
                <i class="fa-solid fa-magnifying-glass-minus" data-bs-toggle="tooltip" data-bs-placement="top" title="Zoom out"></i>
            </button>
            <button type="button" class="btn zoom-btn" @click="resetView">
                <i class="fa-solid fa-expand" data-bs-toggle="tooltip" data-bs-placement="top" title="Reset view"></i>
            </button>
            <button type="button" class="btn zoom-btn" @click="toggleMapStyle"
                :title="mapStyle === 'terrain' ? 'Switch to dark map' : 'Switch to terrain map'">
                <i :class="mapStyle === 'terrain' ? 'fa-solid fa-moon' : 'fa-solid fa-map'"></i>
            </button>
            <button v-if="showAutoRefresh" type="button" class="btn zoom-btn"
                :class="{ 'active': autoRefreshEnabled }"
                :title="autoRefreshEnabled ? 'Auto-refresh enabled' : 'Auto-refresh disabled'"
                @click="toggleAutoRefresh">
                <i class="fa-solid fa-arrows-rotate" :class="{ 'fa-spin': autoRefreshEnabled }"></i>
            </button>
        </div>

        <!-- Tooltip -->
        <div v-if="tooltip.show" class="deckgl-tooltip"
             :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
            <div v-html="tooltip.content"></div>
        </div>

        <!-- OSM attribution -->
        <div class="osm-attribution">
            © <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap contributors</a>
        </div>
    </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted, shallowRef } from 'vue'
import { Deck, MapView } from '@deck.gl/core'
import { ScatterplotLayer, ArcLayer, TextLayer } from '@deck.gl/layers'
import { TileLayer } from '@deck.gl/geo-layers'
import { BitmapLayer } from '@deck.gl/layers'

const props = defineProps({
    height: { type: String, default: '100vh' },

    // Initial map centre and zoom
    initialLat:  { type: Number, default: 20 },
    initialLng:  { type: Number, default: 0 },
    initialZoom: { type: Number, default: 2 },

    // Site markers 
    // Array<{ lat, lng, label, type, status, connectionCount, lastSeen }>
    //   type:   'HQ' | 'Branch' | 'DataCenter' | 'CloudRegion' | 'ExternalPeer'
    //   status: 'Online' | 'Degraded' | 'Offline' | 'Unknown'
    sites: { type: Array, default: null },

    showLabels: { type: Boolean, default: true },

    // Connection arcs
    // Array<{ sourcePosition:[lng,lat], targetPosition:[lng,lat],
    //         sourceSiteId, targetSiteId, bandwidth, latency,
    //         protocol, severity, direction, packetLoss }>
    //   severity: 'Normal' | 'Warning' | 'Critical' | 'Blocked'
    connections: { type: Array, default: null },

    // Optional custom tooltip renderer
    tooltipFormatter: { type: Function, default: null },

    // Show auto-refresh toggle button
    showAutoRefresh: { type: Boolean, default: false },

    // Single "current" marker (e.g. site being added/edited) ─────────────────
    // { lat, lng, label }
    currentMarker: { type: Object, default: null },

    // Show the free-text address / lat,lng search box (Nominatim geocoding)
    enableSearch: { type: Boolean, default: false },
})

const emit = defineEmits(['site-click', 'connection-click', 'auto-refresh-toggle', 'map-click', 'marker-placed'])

const containerRef     = ref(null)
const canvasRef        = ref(null)
const deck             = shallowRef(null)
const currentZoom      = ref(Math.round(props.initialZoom))
const tooltip          = ref({ show: false, x: 0, y: 0, content: '' })
const autoRefreshEnabled = ref(false)
const mapStyle         = ref('terrain') // 'terrain' | 'dark'
const hoveredSiteId    = ref(null)      // label of the site currently hovered — arcs only render for it

// Search / geocoding
const searchQuery   = ref('')
const geocoding     = ref(false)
const geocodeError  = ref('')
const searchResults = ref([])   // top Nominatim matches — user picks the right one

const viewState = ref({
    longitude: props.initialLng,
    latitude:  props.initialLat,
    zoom:      props.initialZoom,
    pitch:     0,
    bearing:   0,
    minZoom:   2,
    maxZoom:   18,
})

// Visual encoding 
const SITE_RADIUS = {
    HQ:           10,
    DataCenter:   8,
    Branch:       7,
    CloudRegion:  6,
    ExternalPeer: 5,
}

const STATUS_COLOR = {
    Online:   [34,  197, 94,  255],
    Degraded: [251, 146, 60,  255],
    Offline:  [239, 68,  68,  255],
    Unknown:  [148, 163, 184, 255],
}

const SEVERITY_COLOR = {
    Normal:   [99,  179, 237],
    Warning:  [251, 191, 36],
    Critical: [239, 68,  68],
    Blocked:  [156, 163, 175],
}

function siteRadius(s)  { return SITE_RADIUS[s?.type] ?? 6 }
function siteColor(s)   { return STATUS_COLOR[s?.status] ?? STATUS_COLOR.Unknown }
function arcColor(c)    { return SEVERITY_COLOR[c?.severity] ?? SEVERITY_COLOR.Normal }

const TILE_URLS = {
    terrain: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    dark:    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
}

const currentTileUrl = computed(() => TILE_URLS[mapStyle.value])

// Tile basemap
function buildTileLayer() {
    return new TileLayer({
        id: `basemap-${mapStyle.value}`,
        data: [currentTileUrl.value],
        maxRequests: 20,
        pickable: false,
        tileSize: 256,
        minZoom: 2,
        maxZoom: 19,
        renderSubLayers(subProps) {
            const [[west, south], [east, north]] = subProps.tile.boundingBox
            const { data, ...rest } = subProps
            return new BitmapLayer(rest, {
                image: data,
                bounds: [west, south, east, north],
            })
        },
    })
}

function buildLayers() {
    const layers = [buildTileLayer()]

    // Connection arcs — non-dynamic: only drawn for the currently hovered site.
    // Dual-pass: wide glow + thin bright line.
    const hoveredConnections = hoveredSiteId.value
        ? props.connections?.filter(c => c.sourceSiteId === hoveredSiteId.value || c.targetSiteId === hoveredSiteId.value)
        : null

    if (hoveredConnections?.length) {
        // Glow pass
        layers.push(new ArcLayer({
            id: 'arcs-glow',
            data: hoveredConnections,
            getSourcePosition: d => d.sourcePosition,
            getTargetPosition: d => d.targetPosition,
            getSourceColor: d => [...arcColor(d), 35],
            getTargetColor: d => [...arcColor(d), 35],
            getWidth: 8,
            widthUnits: 'pixels',
            opacity: 1,
            pickable: false,
        }))
        // Bright line pass
        layers.push(new ArcLayer({
            id: 'arcs',
            data: hoveredConnections,
            getSourcePosition: d => d.sourcePosition,
            getTargetPosition: d => d.targetPosition,
            getSourceColor: d => [...arcColor(d), 220],
            getTargetColor: d => [...arcColor(d), 60],
            getWidth: 1.5,
            widthUnits: 'pixels',
            opacity: 1,
            pickable: true,
            autoHighlight: true,
            highlightColor: [255, 255, 255, 80],
            onClick: ({ object, x, y }) => {
                if (!object) return
                emit('connection-click', object)
                showTooltip(x, y, formatConnectionTooltip(object))
            },
            onHover: ({ object, x, y }) => {
                if (object) showTooltip(x, y, formatConnectionTooltip(object))
                else hideTooltip()
            },
        }))
    }

    // Site markers — dot glow + solid dot
    if (props.sites?.length) {
        // Outer glow
        layers.push(new ScatterplotLayer({
            id: 'sites-glow',
            data: props.sites,
            getPosition:      d => [d.lng, d.lat],
            getRadius:        d => siteRadius(d) * 2.8,
            radiusUnits:      'pixels',
            getFillColor:     d => [...siteColor(d).slice(0, 3), 45],
            stroked:          false,
            pickable:         false,
        }))
        // Mid ring
        layers.push(new ScatterplotLayer({
            id: 'sites-ring',
            data: props.sites,
            getPosition:      d => [d.lng, d.lat],
            getRadius:        d => siteRadius(d) * 1.6,
            radiusUnits:      'pixels',
            getFillColor:     d => [...siteColor(d).slice(0, 3), 90],
            stroked:          false,
            pickable:         false,
        }))
        // Core dot
        layers.push(new ScatterplotLayer({
            id: 'sites',
            data: props.sites,
            getPosition:      d => [d.lng, d.lat],
            getRadius:        d => siteRadius(d),
            radiusUnits:      'pixels',
            radiusMinPixels:  3,
            radiusMaxPixels:  18,
            getFillColor:     d => siteColor(d),
            getLineColor:     [255, 255, 255, 180],
            lineWidthMinPixels: 1,
            stroked:          true,
            pickable:         true,
            autoHighlight:    true,
            highlightColor:   [255, 255, 255, 60],
            onClick: ({ object, x, y }) => {
                if (!object) return
                emit('site-click', object)
                showTooltip(x, y, formatSiteTooltip(object))
            },
            onHover: ({ object, x, y }) => {
                const id = object?.label ?? null
                if (id !== hoveredSiteId.value) {
                    hoveredSiteId.value = id
                    rerenderLayers()
                }
                if (object) showTooltip(x, y, formatSiteTooltip(object))
                else hideTooltip()
            },
        }))

        if (props.showLabels && currentZoom.value >= 5) {
            layers.push(new TextLayer({
                id: 'site-labels',
                data: props.sites,
                getPosition:    d => [d.lng, d.lat],
                getText:        d => d.label ?? '',
                getColor:       [255, 255, 255, 220],
                getSize:        12,
                getPixelOffset: [0, -18],
                fontSettings:   { sdf: true },
                outlineWidth:   2,
                outlineColor:   [0, 0, 0, 220],
                pickable:       false,
            }))
        }
    }

    // Current marker — the single location being placed/edited (address search, lat/lng input or map click
    if (props.currentMarker && props.currentMarker.lat != null && props.currentMarker.lng != null) {
        const pos = [props.currentMarker.lng, props.currentMarker.lat]
        layers.push(new ScatterplotLayer({
            id: 'current-marker-glow',
            data: [props.currentMarker],
            getPosition: () => pos,
            getRadius: 26,
            radiusUnits: 'pixels',
            getFillColor: [251, 146, 60, 60],
            stroked: false,
            pickable: false,
        }))
        layers.push(new ScatterplotLayer({
            id: 'current-marker',
            data: [props.currentMarker],
            getPosition: () => pos,
            getRadius: 9,
            radiusUnits: 'pixels',
            getFillColor: [251, 146, 60, 255],
            getLineColor: [255, 255, 255, 220],
            lineWidthMinPixels: 2,
            stroked: true,
            pickable: false,
        }))
    }

    return layers
}

function showTooltip(x, y, content) {
    tooltip.value = { show: true, x, y, content }
}
function hideTooltip() {
    tooltip.value.show = false
}

function formatSiteTooltip(s) {
    if (props.tooltipFormatter) return props.tooltipFormatter(s)
    const col = { Online: '#22c55e', Degraded: '#fb923c', Offline: '#ef4444', Unknown: '#94a3b8' }
    return `<b>${s.label ?? 'Site'}</b><br>
        Type: ${s.type ?? '—'}<br>
        Status: <span style="color:${col[s.status] ?? col.Unknown}">${s.status ?? '—'}</span><br>
        Connections: ${s.connectionCount ?? '—'}<br>
        Last seen: ${s.lastSeen ?? '—'}`
}

function formatConnectionTooltip(c) {
    if (props.tooltipFormatter) return props.tooltipFormatter(c)
    return `<b>${c.sourceSiteId ?? '?'} → ${c.targetSiteId ?? '?'}</b><br>
        Protocol: ${c.protocol ?? '—'}<br>
        Bandwidth: ${c.bandwidth ?? '—'} Mbps<br>
        Latency: ${c.latency ?? '—'} ms<br>
        Packet loss: ${c.packetLoss ?? 0}%<br>
        Severity: ${c.severity ?? '—'}`
}

function initDeck() {
    if (deck.value) { deck.value.finalize(); deck.value = null }

    deck.value = new Deck({
        canvas: canvasRef.value,
        parent: containerRef.value,
        width:  '100%',
        height: '100%',
        views:  new MapView({ repeat: true }),
        initialViewState: { ...viewState.value },
        controller: true,
        layers: buildLayers(),
        parameters: { clearColor: [15/255, 23/255, 42/255, 1] },
        onViewStateChange: ({ viewState: vs }) => {
            viewState.value = vs
            currentZoom.value = Math.round(vs.zoom)
        },
        onClick: (info) => {
            if (info.object || !info.coordinate) return
            const [lng, lat] = info.coordinate
            emit('map-click', { lat, lng })
        },
    })
}

function rerenderLayers() {
    deck.value?.setProps({ layers: buildLayers() })
}

function zoomIn()  { applyZoomDelta(+1) }
function zoomOut() { applyZoomDelta(-1) }

function resetView() {
    deck.value?.setProps({
        initialViewState: {
            longitude: props.initialLng,
            latitude:  props.initialLat,
            zoom:      props.initialZoom,
            transitionDuration: 500,
        },
    })
}

function applyZoomDelta(delta) {
    const z = Math.max(2, Math.min(18, (viewState.value.zoom ?? props.initialZoom) + delta))
    deck.value?.setProps({
        initialViewState: { ...viewState.value, zoom: z, transitionDuration: 300 },
    })
}

function toggleMapStyle() {
    mapStyle.value = mapStyle.value === 'terrain' ? 'dark' : 'terrain'
    rerenderLayers()
}

function toggleAutoRefresh() {
    autoRefreshEnabled.value = !autoRefreshEnabled.value
    emit('auto-refresh-toggle', autoRefreshEnabled.value)
}

let resizeObserver = null

onMounted(() => {
    initDeck()
    resizeObserver = new ResizeObserver(() => {
        deck.value?.setProps({
            width:  containerRef.value.clientWidth,
            height: containerRef.value.clientHeight,
        })
    })
    resizeObserver.observe(containerRef.value)
})

onUnmounted(() => {
    resizeObserver?.disconnect()
    deck.value?.finalize()
    deck.value = null
})

watch(
    [
        () => props.sites,
        () => props.connections,
        () => props.currentMarker,
        () => currentZoom.value,
    ],
    () => rerenderLayers(),
    { deep: true }
)

// Accepts either "lat, lng" or a free-text street address shows up to 5 candidate matches for the user to pick from
async function geocodeSearch() {
    const query = searchQuery.value.trim()
    if (!query) return

    geocodeError.value = ''
    searchResults.value = []
    geocoding.value = true

    try {
        const latLngMatch = query.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/)
        if (latLngMatch) {
            const lat = parseFloat(latLngMatch[1])
            const lng = parseFloat(latLngMatch[2])
            placeMarkerAt(lat, lng, query)
            return
        }

        const url = `https://nominatim.openstreetmap.org/search?format=json&limit=5&q=${encodeURIComponent(query)}`
        const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
        const results = await res.json()

        if (!results?.length) {
            geocodeError.value = 'Address not found'
            return
        }

        if (results.length === 1) {
            const { lat, lon, display_name } = results[0]
            placeMarkerAt(parseFloat(lat), parseFloat(lon), display_name)
            return
        }

        searchResults.value = results
    } catch (e) {
        geocodeError.value = 'Geocoding failed'
    } finally {
        geocoding.value = false
    }
}

// Called when the user picks one of the candidate results from the list.
function selectSearchResult(r) {
    searchResults.value = []
    searchQuery.value = r.display_name
    placeMarkerAt(parseFloat(r.lat), parseFloat(r.lon), r.display_name)
}

// Places/updates the current marker, recenters the map on it, and notifies the parent.
function placeMarkerAt(lat, lng, address = null) {
    emit('marker-placed', { lat, lng, address })
    deck.value?.setProps({
        initialViewState: { ...viewState.value, longitude: lng, latitude: lat, zoom: 12, transitionDuration: 500 },
    })
}

defineExpose({ placeMarkerAt })
</script>

<style scoped>
.deckgl-geomap {
    position: relative;
    width: 100%;
    background: #0f172a;
    overflow: hidden;
}

.deckgl-canvas {
    position: absolute;
    inset: 0;
    width: 100% !important;
    height: 100% !important;
}

.geomap-search {
    position: absolute;
    left: 10px;
    top: 10px;
    z-index: 10;
    width: 260px;
}

.geomap-search .search-btn {
    background-color: #fd7e14 !important;
    color: white !important;
    border: none !important;
}

.geomap-search .search-btn:hover {
    background-color: #e76b06 !important;
}

.geomap-search-error {
    margin-top: 4px;
    padding: 4px 8px;
    background: rgba(239, 68, 68, 0.9);
    color: white;
    font-size: 11px;
    border-radius: 4px;
}

.geomap-search-results {
    list-style: none;
    margin: 4px 0 0;
    padding: 4px 0;
    background: rgba(15, 23, 42, 0.97);
    border: 1px solid #334155;
    border-radius: 6px;
    max-height: 200px;
    overflow-y: auto;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    scrollbar-width: thin;
    scrollbar-color: #475569 transparent;
}

.geomap-search-results::-webkit-scrollbar {
    width: 6px;
}

.geomap-search-results::-webkit-scrollbar-track {
    background: transparent;
}

.geomap-search-results::-webkit-scrollbar-thumb {
    background-color: #475569;
    border-radius: 3px;
}

.geomap-search-results::-webkit-scrollbar-thumb:hover {
    background-color: #64748b;
}

.geomap-search-results li {
    padding: 6px 10px;
    font-size: 12px;
    line-height: 1.4;
    color: #e2e8f0;
    cursor: pointer;
}

.geomap-search-results li:hover {
    background: rgba(251, 146, 60, 0.2);
}

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
    transition: background-color 0.15s;
}

.zoom-btn:hover {
    background-color: #e76b06 !important;
}

.zoom-btn.active {
    background-color: #c25c00 !important;
    box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.3);
}

.deckgl-tooltip {
    position: absolute;
    z-index: 20;
    background: rgba(15, 23, 42, 0.95);
    border: 1px solid #334155;
    border-radius: 6px;
    padding: 10px 12px;
    color: #e2e8f0;
    font-size: 12px;
    line-height: 1.6;
    max-width: 260px;
    pointer-events: none;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    transform: translate(12px, -50%);
}

.osm-attribution {
    position: absolute;
    bottom: 4px;
    right: 8px;
    font-size: 10px;
    color: rgba(148, 163, 184, 0.7);
    z-index: 10;
}
.osm-attribution a { color: rgba(148, 163, 184, 0.9); }
</style>
