<template>
    <div class="demo-shell">
        <h4 class="demo-title">GeomapDeck — Component Demo</h4>

        <!-- Mode switcher -->
        <div class="mode-bar">
            <button v-for="m in MODES" :key="m.id"
                :class="['mode-btn', { active: activeMode === m.id }]"
                @click="activeMode = m.id">
                {{ m.label }}
            </button>
        </div>

        <!-- Last emitted event -->
        <div v-if="lastEvent" class="event-log">
            <b>Event:</b> {{ lastEvent }}
        </div>

        <!-- MODE: Markers only -->
        <template v-if="activeMode === 'markers'">
            <p class="mode-desc">
                <b>Site markers</b> — map-pin icons coloured by status, sized by tier.
                Click a pin to emit <code>site-click</code>. Labels appear at zoom ≥ 5.
            </p>
            <GeomapDeck
                height="55vh"
                :sites="DEMO_SITES"
                :showLabels="true"
                @site-click="onSiteClick"
            />
        </template>

        <!-- MODE: Connection arcs -->
        <template v-else-if="activeMode === 'arcs'">
            <p class="mode-desc">
                <b>Connection arcs</b> — thin great-circle arcs, coloured by severity.
                Click an arc for details.
            </p>
            <GeomapDeck
                height="55vh"
                :sites="DEMO_SITES"
                :connections="DEMO_CONNECTIONS"
                @site-click="onSiteClick"
                @connection-click="onConnectionClick"
            />
        </template>

        <!-- MODE: Heatmap -->
        <template v-else-if="activeMode === 'heatmap'">
            <p class="mode-desc">
                <b>Density heatmap</b> — weight-based point density layer.
                Use the bottom-left sliders to tweak intensity, radius, opacity and time window.
            </p>
            <GeomapDeck
                height="55vh"
                :heatmapPoints="DEMO_HEATMAP"
            />
        </template>

        <!-- MODE: All layers -->
        <template v-else-if="activeMode === 'all'">
            <p class="mode-desc">
                All layers combined: basemap + site pins + connection arcs + density heatmap.
            </p>
            <GeomapDeck
                height="55vh"
                :sites="DEMO_SITES"
                :connections="DEMO_CONNECTIONS"
                :heatmapPoints="DEMO_HEATMAP"
                :showLabels="true"
                @site-click="onSiteClick"
                @connection-click="onConnectionClick"
            />
        </template>

        <!-- Data schema reference -->
        <div class="schemas">
            <details>
                <summary>Data schemas &amp; tile URL notes</summary>
                <div class="schema-grid">
                    <div>
                        <b>sites</b> — Array&lt;SiteRecord&gt;
                        <pre>{{ SITE_SCHEMA }}</pre>
                    </div>
                    <div>
                        <b>connections</b> — Array&lt;ConnectionRecord&gt;
                        <pre>{{ CONNECTION_SCHEMA }}</pre>
                    </div>
                    <div>
                        <b>heatmapPoints</b> — Array&lt;HeatmapPoint&gt;
                        <pre>{{ HEATMAP_SCHEMA }}</pre>
                    </div>
                    <div>
                        <b>tileUrl formats</b>
                        <pre>{{ TILE_NOTES }}</pre>
                    </div>
                </div>
            </details>
        </div>
    </div>
</template>

<script setup>
import { ref } from 'vue'
import GeomapDeck from './geomap-cartography.vue'

const MODES = [
    { id: 'markers', label: 'Site markers' },
    { id: 'arcs',    label: 'Connection arcs' },
    { id: 'heatmap', label: 'Density heatmap' },
    { id: 'all',     label: 'All layers' },
]
const activeMode = ref('markers')
const lastEvent  = ref(null)

function onSiteClick(site)       { lastEvent.value = `site-click → ${JSON.stringify(site)}` }
function onConnectionClick(conn) { lastEvent.value = `connection-click → ${JSON.stringify(conn)}` }

// ─── Demo data ────────────────────────────────────────────────────────────────

const DEMO_SITES = [
    { lat: 40.71, lng: -74.01, label: 'New York HQ',    type: 'HQ',           status: 'Online',   connectionCount: 42,  lastSeen: '2 min ago' },
    { lat: 51.51, lng:  -0.13, label: 'London Branch',  type: 'Branch',       status: 'Online',   connectionCount: 17,  lastSeen: '1 min ago' },
    { lat: 35.68, lng: 139.69, label: 'Tokyo DC',       type: 'DataCenter',   status: 'Degraded', connectionCount: 8,   lastSeen: '5 min ago' },
    { lat: 48.86, lng:   2.35, label: 'Paris Branch',   type: 'Branch',       status: 'Offline',  connectionCount: 0,   lastSeen: '1 h ago' },
    { lat: 37.38, lng: -122.0, label: 'AWS us-west-2',  type: 'CloudRegion',  status: 'Online',   connectionCount: 120, lastSeen: 'now' },
    { lat:-33.87, lng:  151.2, label: 'Sydney Branch',  type: 'Branch',       status: 'Unknown',  connectionCount: 3,   lastSeen: '30 min ago' },
    { lat:  1.35, lng: 103.82, label: 'Singapore DC',   type: 'DataCenter',   status: 'Online',   connectionCount: 55,  lastSeen: '10 s ago' },
    { lat: 50.11, lng:   8.68, label: 'Frankfurt Peer', type: 'ExternalPeer', status: 'Online',   connectionCount: 6,   lastSeen: '3 min ago' },
]

const DEMO_CONNECTIONS = [
    { sourcePosition: [-74.01, 40.71], targetPosition: [-0.13, 51.51],   sourceSiteId: 'New York HQ',   targetSiteId: 'London Branch',  bandwidth: 500,  latency: 72,  protocol: 'IPSEC',  severity: 'Normal',   direction: 'Bidirectional', packetLoss: 0.1 },
    { sourcePosition: [-74.01, 40.71], targetPosition: [-122.0, 37.38],  sourceSiteId: 'New York HQ',   targetSiteId: 'AWS us-west-2',  bandwidth: 2000, latency: 55,  protocol: 'SD-WAN', severity: 'Normal',   direction: 'Outbound',      packetLoss: 0   },
    { sourcePosition: [139.69, 35.68], targetPosition: [103.82,  1.35],  sourceSiteId: 'Tokyo DC',       targetSiteId: 'Singapore DC',  bandwidth: 100,  latency: 88,  protocol: 'MPLS',   severity: 'Warning',  direction: 'Bidirectional', packetLoss: 2.4 },
    { sourcePosition: [  2.35, 48.86], targetPosition: [  8.68, 50.11], sourceSiteId: 'Paris Branch',   targetSiteId: 'Frankfurt Peer', bandwidth: 10,   latency: 200, protocol: 'BGP',    severity: 'Critical', direction: 'Inbound',       packetLoss: 15  },
    { sourcePosition: [ -0.13, 51.51], targetPosition: [151.2, -33.87], sourceSiteId: 'London Branch',  targetSiteId: 'Sydney Branch',  bandwidth: 50,   latency: 280, protocol: 'IPSEC',  severity: 'Normal',   direction: 'Bidirectional', packetLoss: 0.5 },
]

const DEMO_HEATMAP = (() => {
    const pts = []
    const now = Math.floor(Date.now() / 1000)
    const clusters = [
        { lat: 48.8, lng:   2.3,   spread: 5, n: 80, wMax: 10 },
        { lat: 51.5, lng:  -0.1,   spread: 4, n: 70, wMax: 8  },
        { lat: 40.7, lng: -74,     spread: 6, n: 90, wMax: 12 },
        { lat: 52.5, lng:  13.4,   spread: 3, n: 50, wMax: 6  },
        { lat: 35.7, lng: 139.7,   spread: 4, n: 60, wMax: 9  },
    ]
    for (const c of clusters) {
        for (let i = 0; i < c.n; i++) {
            pts.push({
                lat:       c.lat + (Math.random() - 0.5) * c.spread,
                lng:       c.lng + (Math.random() - 0.5) * c.spread,
                weight:    Math.random() * c.wMax + 1,
                timestamp: now - Math.floor(Math.random() * 7200),
            })
        }
    }
    return pts
})()

// ─── Schema docs ─────────────────────────────────────────────────────────────

const SITE_SCHEMA = `{
  lat:             number   // GPS latitude
  lng:             number   // GPS longitude
  label:           string   // display name
  type:            'HQ' | 'Branch' | 'DataCenter'
                 | 'CloudRegion' | 'ExternalPeer'
  status:          'Online' | 'Degraded' | 'Offline' | 'Unknown'
  connectionCount: number
  lastSeen:        string
}`

const CONNECTION_SCHEMA = `{
  sourcePosition: [lng, lat]   // deck.gl: lng first!
  targetPosition: [lng, lat]
  sourceSiteId:   string
  targetSiteId:   string
  bandwidth:      number       // Mbps
  latency:        number       // ms
  protocol:       'IPSEC' | 'MPLS' | 'SD-WAN' | 'BGP' | 'OTHER'
  severity:       'Normal' | 'Warning' | 'Critical' | 'Blocked'
  direction:      'Bidirectional' | 'Inbound' | 'Outbound'
  packetLoss:     number       // 0–100 %
}`

const HEATMAP_SCHEMA = `{
  lat:       number   // GPS latitude
  lng:       number   // GPS longitude
  weight:    number   // relative density (connections / bytes)
  timestamp: number   // Unix epoch seconds
}`

const TILE_NOTES = `// Default — OpenStreetMap (no API key):
tileUrl="https://tile.openstreetmap.org/{z}/{x}/{y}.png"

// OpenFreeMap dark (free, no key):
tileUrl="https://tiles.openfreemap.org/styles/dark/{z}/{x}/{y}.png"

// Protomaps self-hosted (offline):
tileUrl="https://your-host/map.pmtiles/{z}/{x}/{y}.mvt"`
</script>

<style scoped>
.demo-shell {
    padding: 20px;
    background: #0f172a;
    color: #e2e8f0;
    min-height: 100vh;
    font-family: 'Inter', 'Segoe UI', sans-serif;
}

.demo-title {
    color: #f1f5f9;
    margin-bottom: 14px;
}

.mode-bar {
    display: flex;
    gap: 8px;
    margin-bottom: 12px;
    flex-wrap: wrap;
}

.mode-btn {
    padding: 6px 16px;
    border-radius: 4px;
    border: 1px solid #334155;
    background: #1e293b;
    color: #94a3b8;
    cursor: pointer;
    font-size: 13px;
    transition: all 0.15s;
}
.mode-btn:hover { background: #263450; }
.mode-btn.active {
    background: #fb923c;
    color: #fff;
    border-color: #fb923c;
}

.mode-desc {
    font-size: 13px;
    color: #94a3b8;
    margin-bottom: 10px;
    line-height: 1.5;
}

.event-log {
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 4px;
    padding: 6px 10px;
    font-size: 12px;
    color: #94a3b8;
    margin-bottom: 10px;
    word-break: break-all;
}

.schemas { margin-top: 20px; }

details > summary {
    cursor: pointer;
    color: #94a3b8;
    font-size: 13px;
    padding: 6px 0;
    user-select: none;
}

.schema-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
    margin-top: 12px;
}

.schema-grid > div {
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 6px;
    padding: 12px;
    font-size: 12px;
}

.schema-grid b {
    color: #fb923c;
    display: block;
    margin-bottom: 6px;
}

pre {
    color: #94a3b8;
    font-size: 11px;
    white-space: pre-wrap;
    margin: 0;
}
</style>
