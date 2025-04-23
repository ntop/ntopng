<template>
    <div class="dashboard-container bg-light">
        <!-- Main Content -->
        <div class="row g-4">
            <!-- Filters Card - Vertically stacked -->
            <div class="range-container d-flex flex-wrap">
                <div class="card-body w-100 range-picker d-flex m-auto flex-wrap">
                    <RangePicker ref="range_picker" id="range-picker" :enable_refresh="true"
                        :disabled_date_picker="false" min_time_interval_id="5_min" :round_time="true">
                        <template v-slot:extra_range_buttons>
                            <div class="ms-4 d-flex align-items-center ms-2">
                                <label class="text-nowrap form-label fw-semibold me-1"> {{
                                    _i18n("map_page.asset_in_edges")
                                }} </label>
                                <input ref="slider_min_incoming_edges" type="range" class="form-range" min="0"
                                    max="10000" v-model="minIncomingEdges" data-bs-toggle="tooltip"
                                    data-bs-placement="top" :title="minIncomingEdges" />
                            </div>
                            <div class="ms-4 d-flex align-items-center ms-2">
                                <label class="text-nowrap form-label fw-semibold me-1"> {{
                                    _i18n("map_page.asset_out_edges") }} </label>
                                <input ref="slider_min_outgoing_edges" type="range" class="form-range" min="0"
                                    max="10000" v-model="minOutgoingEdges" data-bs-toggle="tooltip"
                                    data-bs-placement="top" :title="minOutgoingEdges" />
                            </div>

                            <div class="ms-4 d-flex align-items-center">
                                <div class="w-100">
                                    <div class="d-flex">
                                        <input type="text" class="form-control form-control-sm"
                                            :class="{ 'is-invalid': nodeNotFoundMessage }" v-model="searchNodeId"
                                            placeholder="Center on IP" @keyup.enter="findNode">
                                        <button class="btn btn-sm btn-primary" @click="findNode">
                                            <i class="fas fa-search"></i>
                                        </button>
                                    </div>
                                    <div v-if="nodeNotFoundMessage" class="invalid-feedback d-block">
                                        Host not present
                                    </div>
                                </div>
                            </div>

                        </template>
                    </RangePicker>
                </div>
            </div>
            <!-- Graph Visualization Section - Full width when no node selected -->
            <div class="col-lg-8">
                <div class="card shadow-sm h-100">
                    <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0 fw-bold">{{ _i18n("alert.graph.alerts_topology") }}</h5>
                        <button class="btn btn-sm btn-outline-secondary" @click="reset_filters">
                            <i class="fa-solid fa-rotate-right"></i>
                        </button>
                    </div>
                    <div class="card-body p-0">
                        <div ref="alerts_graph" class="graph-content d-flex justify-content-center align-items-center"
                            :class="[(loading) ? 'ntopng-gray-out' : '']">
                            <Loading v-if="loading" :class="'mt-1'"></Loading>
                            <div v-if="no_data" class="d-flex justify-content-center align-items-center h-100">
                                <p class="text-center text-muted">{{ _i18n("alert.graph.no_data") }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Node Details Section - Only shown when a node is selected -->
            <div class="col-lg-4">
                <!-- Node or Alert Details Card -->
                <div class="card shadow-sm h-100" :class="[(hostDataLoading) ? 'ntopng-gray-out' : '']">
                    <!-- Conditional header based on what was clicked -->
                    <div class="card-header bg-white py-3">
                        <h5 class="card-title mb-0 fw-bold">
                            {{ lastClickedElementIsNode ? _i18n("alert.graph.node_details") : "Alert Details" }}
                        </h5>
                    </div>

                    <Loading v-if="hostDataLoading"></Loading>

                    <div v-else class="card-body">
                        <!-- Node Details Section -->
                        <div v-if="lastClickedElementIsNode" class="node-details">
                            <div class="mb-4">
                                <h6 class="fw-bold fs-5">
                                    <i class='fas fa-laptop'></i> {{ selectedNodeData?.host_info?.info?.ip || 'N/A'
                                    }}
                                </h6>
                                <div class="row g-3">
                                    <div class="col-12">
                                        <span class="detail-label">{{ _i18n("alert.graph.country") }}</span>
                                        <img :src="'/dist/images/blank.gif'" class="flag"
                                            :class="'flag-' + (selectedNodeData?.host_info?.info?.country?.toLowerCase() || '')" />
                                        {{ selectedNodeData?.host_info?.info?.country || 'NA' }}
                                    </div>
                                    <div class="col-12">
                                        <span class="detail-label">{{ _i18n("alert.graph.asn") }}</span>
                                        <a v-if="selectedNodeData?.host_info?.info?.asn_name !== selectedNodeData?.host_info?.info?.ip"
                                            :href="asnPageUrl" target="_blank" class="fw-bold">
                                            {{ selectedNodeData?.host_info?.info?.asn_name }}
                                        </a>
                                        <span v-else class="fw-bold"> None </span>
                                    </div>

                                    <div class="col-12">
                                        <span class="detail-label">{{ _i18n("alert.graph.live_flows") }}</span>
                                        <a v-if="selectedNode" :href="activeFlows.live_flows_url" target="_blank"
                                            class="fw-bold">
                                            {{ activeFlows.recordsTotal }}
                                        </a>
                                        <a v-else class="disabled">0</a>
                                    </div>
                                    <div class="col-12">
                                        <a :href="hist_flows_url" target="_blank" class="fw-bold">
                                            <i class="fas fa-lg fa-chart-area"> </i>
                                            <span class="detail-label text-primary">{{
                                                _i18n("alert.graph.hist_flows")
                                                }}</span>
                                        </a>
                                    </div>
                                    <div class="col-12">
                                        <a :href="hist_alerts_url" target="_blank" class="text-danger fw-bold">
                                            <i class="fa-solid fa-triangle-exclamation"> </i>
                                            <span class="detail-label text-primary">{{
                                                _i18n("alert.graph.hist_alerts")
                                                }} </span>
                                        </a>
                                    </div>
                                </div>
                            </div>

                            <ul class="nav nav-tabs" id="nodeRoleTabs" role="tablist">
                                <li class="nav-item" role="presentation">
                                    <button class="nav-link active" data-bs-toggle="tab" data-bs-target="#client"
                                        type="button">
                                        {{ _i18n("alert.graph.as_client") }}
                                    </button>
                                </li>
                                <li class="nav-item" role="presentation">
                                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#server"
                                        type="button">
                                        {{ _i18n("alert.graph.as_server") }}
                                    </button>
                                </li>
                            </ul>

                            <div class="tab-content pt-3">
                                <template v-for="role in ['client', 'server']" :key="role">
                                    <div class="tab-pane fade" :class="{ 'show active': role === 'client' }" :id="role">
                                        <div
                                            v-if="selectedNodeData && selectedNodeData.host_info && selectedNodeData.host_info[role]">
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.first_seen")
                                                    }}</span>
                                                <span class="detail-value">{{
                                                    selectedNodeData.host_info[role]?.first_seen
                                                    || '-' }}</span>
                                            </div>
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.last_seen")
                                                    }}</span>
                                                <span class="detail-value">{{
                                                    selectedNodeData.host_info[role]?.last_seen ||
                                                    '-' }}</span>
                                            </div>
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.alerts_count")
                                                    }}</span>
                                                <span class="detail-value">{{
                                                    formatterUtils.getFormatter("number")(selectedNodeData.host_info[role]?.alerts_count)
                                                    || '-' }}</span>
                                            </div>
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.total_score")
                                                    }}</span>
                                                <span class="detail-value">{{
                                                    formatterUtils.getFormatter("number")(selectedNodeData.host_info[role]?.total_score)
                                                    || '-' }}</span>
                                            </div>
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.total_traffic")
                                                    }}</span>
                                                <span class="detail-value">{{
                                                    formatterUtils.getFormatter("bytes")(selectedNodeData.host_info[role]?.total_traffic_bytes)
                                                    }}</span>
                                            </div>
                                        </div>

                                        <div v-else>
                                            <span class="detail-label">No data for {{ selectedNode.id }} as {{ role
                                                }}</span>
                                        </div>

                                        <div class="alert-summary card bg-light mt-3">
                                            <div class="card-body p-3">
                                                <h6 class="card-subtitle mb-2 text-muted">{{
                                                    _i18n("alert.graph.alert_summary") }}</h6>
                                                <div class="progress mb-3" style="height: 8px;">
                                                    <div v-for="(item, index) in selectedNodeData.severity_info?.[role]"
                                                        :key="index" class="progress-bar"
                                                        :style="{ width: item.percentage + '%', backgroundColor: item.severity_color }"
                                                        role="progressbar" data-bs-toggle="tooltip"
                                                        data-bs-placement="top"
                                                        :title="`${item.percentage.toFixed(2)}% ${item.severity}`">
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </template>
                            </div>
                        </div>

                        <!-- Alert Details Section -->
                        <div v-else class="alert-details">
                            <div class="mb-4">
                                <div class="row g-3">
                                    <div class="col-12">
                                        <div class="detail-row">
                                            <span class="detail-label fw-bold">
                                                {{ _i18n("alert.graph.alert_type") }}
                                            </span>
                                            <span class="detail-value">
                                                {{ selectedAlertData?.alert_type }}
                                            </span>
                                        </div>

                                        <div class="detail-row">
                                            <span class="detail-label fw-bold">
                                                {{ _i18n("alert.graph.alert_count") }}
                                            </span>
                                            <span class="detail-value">
                                                {{ selectedAlertData?.alerts_count }}
                                            </span>
                                        </div>

                                        <div class="detail-row">
                                            <span class="detail-label fw-bold">
                                                {{ _i18n("alert.graph.country") }}
                                            </span>
                                            <span class="detail-value">
                                                {{ selectedAlertData?.proto }}
                                            </span>
                                        </div>

                                        <div class="detail-row">
                                            <span class="detail-label fw-bold">
                                                {{ _i18n("alert_entities.l7") }}
                                            </span>
                                            <span class="detail-value">
                                                {{ selectedAlertData?.l7 }}
                                            </span>
                                        </div>
                                    </div>

                                    <div class="col-12">
                                        <h6 class="fw-bold">
                                            {{ _i18n("alert.graph.src_info") }}
                                        </h6>
                                        <div class="ms-2 mb-2">
                                            <div class="detail-row">
                                                <span class="detail-label fw-bold">
                                                    {{ _i18n("alert.graph.ip") }}
                                                </span>
                                                <span class="detail-value">
                                                    {{ selectedAlertData?.src_ip || 'N/A' }}
                                                </span>
                                            </div>

                                            <div class="detail-row">
                                                <span class="detail-label fw-bold">
                                                    {{ _i18n("alert.graph.country") }}
                                                </span>
                                                <span class="detail-value">
                                                    <img v-if="selectedAlertData?.src_country"
                                                        :src="'/dist/images/blank.gif'" class="flag"
                                                        :class="'flag-' + (selectedAlertData?.src_country?.toLowerCase() || '')" />
                                                    {{ selectedAlertData?.src_country || 'N/A' }}
                                                </span>
                                            </div>

                                            <div class="detail-row">
                                                <span class="detail-label fw-bold">
                                                    {{ _i18n("alert.graph.asn") }}
                                                </span>
                                                <span
                                                    v-if="selectedAlertData?.src_asn && selectedAlertData?.src_asn !== selectedAlertData?.src_ip"
                                                    class="detail-value fw-bold">
                                                    {{ selectedAlertData?.src_asn }}
                                                </span>
                                                <span v-else class="detail-value fw-bold">
                                                    N/A
                                                </span>

                                            </div>
                                        </div>
                                    </div>

                                    <div class="col-12">
                                        <h6 class="fw-bold">{{ _i18n("alert.graph.dst_info") }}</h6>
                                        <div class="ms-2">
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.ip") }}</span>
                                                <span class="detail-value">{{ selectedAlertData?.dst_ip || 'N/A'
                                                    }}</span>
                                            </div>
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.country") }}</span>
                                                <span class="detail-value">
                                                    <img v-if="selectedAlertData?.dst_country"
                                                        :src="'/dist/images/blank.gif'" class="flag"
                                                        :class="'flag-' + (selectedAlertData?.dst_country?.toLowerCase() || '')" />
                                                    {{ selectedAlertData?.dst_country || 'N/A' }}
                                                </span>
                                            </div>
                                            <div class="detail-row">
                                                <span class="detail-label">{{ _i18n("alert.graph.asn") }}</span>
                                                <span
                                                    v-if="selectedAlertData?.dst_asn && selectedAlertData?.dst_asn !== selectedAlertData?.dst_ip"
                                                    class="detail-value fw-bold">
                                                    {{ selectedAlertData?.dst_asn }}
                                                </span>
                                                <span v-else class="detail-value fw-bold">
                                                    N/A
                                                </span>

                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch, computed, nextTick } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as RangePicker } from "./range-picker.vue";
import formatterUtils from "../utilities/formatter-utils";
import { default as Loading } from "./loading.vue";

const _i18n = (t) => i18n(t);
const d3 = d3v7;

const props = defineProps({
    context: Object,
});

// State data
const ifid = String(props.context.ifid);
const hostDataLoading = ref(true);
const alerts_graph = ref(null);
const range_picker = ref(null);
const loading = ref(true);
const no_data = ref(false);
const slider_min_incoming_edges = ref(null);
const slider_min_outgoing_edges = ref(null);
const last_url = ref();
const minIncomingEdges = ref(0); // minimum number of incoming edges (alerts) of a node
const minOutgoingEdges = ref(0); // minimum number of outgoing edges (alerts) of a node

// Selected node information (right div next to graph)
const selectedNodeData = ref({});
const selectedAlertData = ref({});
const selectedNode = ref(false);
const lastClickedElementIsNode = ref(true); // if true last clicked was a node, if false is an edge between nodes
const activeFlows = ref({ recordsTotal: 0, url: "#" });
const searchNodeId = ref('');
const nodeNotFoundMessage = ref(false); // if focus on a node does not find a node, show error

/* Computed URLs to get host information*/
const asnPageUrl = computed(() => {
    return `${http_prefix}/lua/hosts_stats.lua?asn=${selectedNodeData.value?.host_info?.info?.asn || ''}&version=&network=&traffic_type=&mode=&pool=`;
});

const live_flows_url = computed(() => {
    return `${http_prefix}/lua/flows_stats.lua?flowhosts_type=${selectedNode.value}%400&l4proto=&application=&alert_type=&qoe=&tcp_flow_state=&dscp=&traffic_type=&host_pool_id=&network=#`;
});

const hist_flows_url = computed(() => {
    let epoch_begin = get_url_param("epoch_begin")
    let epoch_end = get_url_param("epoch_end")
    return `${http_prefix}/lua/pro/db_search.lua?ifid=${ifid}&epoch_begin=${epoch_begin}&epoch_end=${epoch_end}&aggregated=false&query_preset=&count=THROUGHPUT&ip=${selectedNode.value}%3Beq`;
});

const hist_alerts_url = computed(() => {
    let epoch_begin = get_url_param("epoch_begin")
    let epoch_end = get_url_param("epoch_end")

    return `${http_prefix}/lua/alert_stats.lua?page=flow&epoch_begin=${epoch_begin}&epoch_end=${epoch_end}&status=any&ifid=${ifid}&query_preset=&count=&ip=${selectedNode.value}%3Beq`;
});

/**************************************/

// D3 Graph data
let links = [];
let nodes = [];

let resizeTimeout;

let clickTimer = null;
let lastClickedNode = null;

/**********************************************/
const applyFilters = async () => {
    // Security check in order to not reload the component if the filters are the same
    if (last_url.value === window.location.href) return;
    let center_graph_on_ip = null;
    last_url.value = window.location.href;

    // Empty links and nodes to make request to backend
    links = [];
    nodes = [];

    // Draw graph with new filters
    await draw_graph(true, center_graph_on_ip);
};

/******************************************************************************/
/**************************** GRAPH FUNCTIONS ******************************* */

async function draw_graph(redraw = false, centerIP = null) {
    loading.value = true;
    try {

        if (redraw) {
            // remove svg if there was a new filter
            d3.select(alerts_graph.value).select("svg").remove();
        }

        // remove old tooltips
        $('.tooltip').remove();
        $('[data-toggle="tooltip"]').tooltip('dispose');

        // fetch data on first rendering
        if (links.length === 0 && nodes.length === 0) {
            const data = await get_links_and_nodes();
            links = data.links;
            nodes = data.nodes;
        }

        // redraw graph and links and nodes are not defined
        if (redraw && links.length === 0 && nodes.length === 0) {

            const data = await get_links_and_nodes();

            links = data.links;
            nodes = data.nodes;

            if (nodes.length === 0) {
                no_data.value = true;
                loading.value = false;
                hostDataLoading.value = false;
                return;

            }
        }

        const width = alerts_graph.value.clientWidth || alerts_graph.value.offsetWidth || alerts_graph.value.getBoundingClientRect().width;
        const height = alerts_graph.value.clientHeight || 500;

        // Create SVG with zoom behavior
        const svg = d3.select(alerts_graph.value)
            .append("svg")
            .attr("width", width)
            .attr("height", height)
            .style("user-select", "none")
            .style("-webkit-user-select", "none")
            .style("-moz-user-select", "none")
            .style("-ms-user-select", "none");

        // Create main group for zoom transformations
        const mainGroup = svg.append("g");

        // Calculate alerts counts for each node
        nodes.forEach(node => {
            node.alert_count = links.filter(link => link.target.id === node.id || link.target === node.id ||
                link.source.id === node.id || link.source === node.id).length;
        });

        // select as node the one with most alerts
        const maxNode = nodes.reduce((prev, current) => {
            return (prev && prev.alert_count > current.alert_count) ? prev : current;
        }, nodes[0]);

        selectedNode.value = maxNode.id;

        // add filter to url
        add_filter('ip', selectedNode.value);
        await get_host_info();

        // Node color scale based on alert count
        const nodeColorScale = d3.scaleSequential()
            .domain([0, d3.max(nodes, d => d.alert_count) || 1])
            .interpolator(d3.interpolateYlOrRd);

        // Link color scale
        const linkColorScale = d3.scaleThreshold()
            .domain([1, 50, 100])
            .range(["#E0E0E0", "#FFB74D", "#FF9800", "#FF8F00"]);

        // Link color scale for highlighted paths - using more saturated colors
        const highlightColorScale = d3.scaleThreshold()
            .domain([1, 50, 100])
            .range(["#1E88E5", "#1565C0", "#0D47A1", "#0A2472"]);

        // compute nodes position
        const simulation = d3.forceSimulation(nodes)
            .force("link", d3.forceLink(links).id(d => d.id).distance(150))
            .force("charge", d3.forceManyBody().strength(-500))
            .force("center", d3.forceCenter(width / 2, height / 2))
            .force("collision", d3.forceCollide().radius(30))
            .force("x", d3.forceX(width / 2).strength(0.1))
            .force("y", d3.forceY(height / 2).strength(0.1));
        simulation.stop();
        for (let i = 0; i < 300; ++i) simulation.tick();

        // DFS init adjacency list
        const adjacencyList = {};

        nodes.forEach(node => {
            adjacencyList[node.id] = [];
        });

        links.forEach(link => {
            const sourceId = link.source.id || link.source;
            const targetId = link.target.id || link.target;
            adjacencyList[sourceId].push({ targetId, link });
        });

        // Find all outgoing paths from a node, when clicked
        function findOutgoingPathsFromNode(sourceId) {
            const pathLinks = new Set();
            const visited = new Set();

            function dfs(currentId) {
                if (visited.has(currentId)) return;
                visited.add(currentId);

                // get neighbors of current node
                const neighbors = adjacencyList[currentId] || [];

                neighbors.forEach(neighbor => {
                    pathLinks.add(neighbor.link);
                    // iterate
                    dfs(neighbor.targetId);
                });
            }

            // start dfs from node
            dfs(sourceId);
            return pathLinks;
        }

        // Replace the line-based links with path-based curved links
        const link = mainGroup.append("g")
            .selectAll("path")
            .data(links)
            .enter().append("path")
            .attr("class", "link")
            .attr("style", d => {
                return `stroke: ${linkColorScale(d.weight)} !important`
            })
            .attr("stroke-opacity", 1)
            .attr("fill", "none")
            .attr("stroke-width", 4)
            .attr("stroke-dasharray", null)
            .attr("marker-end", "url(#arrow)")
            .attr("d", d => {
                const source = d.source;
                const target = d.target;

                // Calculate midpoint
                const midX = (source.x + target.x) / 2;
                const midY = (source.y + target.y) / 2;

                // Calculate perpendicular offset
                const dx = target.x - source.x;
                const dy = target.y - source.y;
                const dist = Math.sqrt(dx * dx + dy * dy);

                // Only apply offset if points aren't too close
                if (dist > 10) {
                    // Fixed offset - adjust based on your preference
                    const offset = 30;

                    // Calculate the offset coordinates
                    const offsetX = -dy * offset / dist;
                    const offsetY = dx * offset / dist;

                    // Return a simple curved path
                    return `M${source.x},${source.y} Q${midX + offsetX},${midY + offsetY} ${target.x},${target.y}`;
                } else {
                    // For very close nodes, use a straight line
                    return `M${source.x},${source.y} L${target.x},${target.y}`;
                }
            })
            .on("click", (event, d) => {
                event.preventDefault();

                // last clicked item is an edge
                lastClickedElementIsNode.value = false;

                // a link is an alert
                selectedAlertData.value.alerts_count = d.weight;
                selectedAlertData.value.alert_type = d.label.alert;
                selectedAlertData.value.proto = d.label.protocol;
                selectedAlertData.value.l7 = d.label.l7;

                selectedAlertData.value.src_ip = d.source.id;
                selectedAlertData.value.src_asn = d.source.src_asn;
                selectedAlertData.value.src_country = d.source.src_country;

                selectedAlertData.value.dst_ip = d.target.id;
                selectedAlertData.value.dst_asn = d.target.dst_asn;
                selectedAlertData.value.dst_country = d.target.dst_country;
            });

        // Create a map to track parallel links between the same nodes
        const linkLookup = {};

        // Update path positions with curved links
        link.each(function (d) {
            const sourceId = d.source.id || d.source;
            const targetId = d.target.id || d.target;
            const linkKey = `${sourceId}-${targetId}`;
            const reverseLinkKey = `${targetId}-${sourceId}`;

            // Track number of parallel links
            linkLookup[linkKey] = linkLookup[linkKey] || [];
            d.linkIndex = linkLookup[linkKey].length;
            linkLookup[linkKey].push(d);

            // Count total parallel links
            const totalLinks = linkLookup[linkKey].length;

            // Check if there are also reverse links
            const reverseLinks = linkLookup[reverseLinkKey] || [];
            const totalBidirectionalLinks = totalLinks + reverseLinks.length;

            // Determine curve strength based on the number of links
            // between the same source-target pair
            const curveStrength = Math.min(50, Math.max(20, 15 * totalBidirectionalLinks));

            // Calculate the curvature offset based on this link's index
            const offset = (d.linkIndex - (totalLinks - 1) / 2) * (curveStrength / totalLinks);

            // Determine curved path
            const dx = d.target.x - d.source.x;
            const dy = d.target.y - d.source.y;
            const dr = Math.sqrt(dx * dx + dy * dy);

            // Calculate midpoint with an offset perpendicular to the straight line
            const offsetX = -dy * offset / dr;
            const offsetY = dx * offset / dr;

            // Control point for the curve
            const cpx = d.source.x + dx / 2 + offsetX;
            const cpy = d.source.y + dy / 2 + offsetY;

            // Create the path
            const path = `M${d.source.x},${d.source.y} Q${cpx},${cpy} ${d.target.x},${d.target.y}`;
            d3.select(this).attr("d", path);
        });

        // Update the tooltips
        link.each(function (d) {
            let tooltipContent = `<strong>${d.label.alert}</strong><br>`;

            if (d.alert_info) tooltipContent += `Alert Info: ${d.alert_info}<br>`;

            if (d.label.alerts_count) tooltipContent += `Alerts Count: ${d.label.alerts_count}<br>`;
            if (d.label.avg_score) tooltipContent += `Avg Score: ${d.label.avg_score}<br>`;
            if ((d.label.src_asn) && (d.source.src_asn !== d.source.id)) tooltipContent += `Src ASN: ${d.label.src_asn}<br>`;
            if ((d.label.dst_asn) && (d.target.dst_asn !== d.target.id)) tooltipContent += `Dst ASN: ${d.label.dst_asn}<br>`;

            if (d.label.src_country) {
                tooltipContent += `Src Country: ${d.label.src_country} <img src='/dist/images/blank.gif' class='flag flag-${d.label.src_country.toLowerCase()}'><br>`;
            }
            if (d.label.dst_country) {
                tooltipContent += `Dst Country: ${d.label.dst_country} <img src='/dist/images/blank.gif' class='flag flag-${d.label.dst_country.toLowerCase()}'><br>`;
            }

            tooltipContent += `L4 Proto: ${d.label.protocol}<br>L7 App: ${d.label.l7}`;

            // Apply Bootstrap tooltip
            $(this).tooltip({
                title: tooltipContent,
                html: true,
                container: 'body',
                placement: 'top'
            });
        });

        mainGroup.append("defs").selectAll("marker")
            .data(["arrow", "arrowDotted"])
            .enter().append("marker")
            .attr("id", d => d)
            .attr("viewBox", "0 -5 10 10")
            .attr("refX", 25)
            .attr("refY", 0)
            .attr("markerWidth", 6)
            .attr("markerHeight", 6)
            .attr("orient", "auto")
            .append("path")
            .attr("d", d => d === "arrowDotted" ? "M0,-4L10,0L0,4" : "M0,-5L10,0L0,5")
            .attr("fill", d => d === "arrowDotted" ? "#FF5722" : "#999");

        const nodeGroup = mainGroup.append("g")
            .selectAll("g")
            .data(nodes)
            .enter().append("g")
            .attr("class", "node-group")
            .attr("transform", d => `translate(${d.x}, ${d.y})`)
            .call(drag())
            .style("pointer-events", "all")
            .on("pointerup", async (event, clicked_node) => {
                event.stopPropagation();
                event.preventDefault();

                lastClickedElementIsNode.value = true;
                selectedNode.value = clicked_node.id;

                try {
                    // Reset all node styles
                    d3.selectAll(".node-group circle")
                        .attr("stroke", "#212121")
                        .attr("stroke-width", 1);

                    // Highlight selected node
                    d3.select(event.currentTarget).select("circle")
                        .attr("stroke", "#FFC107")
                        .attr("stroke-width", 2);

                    // Reset all links to default style
                    d3.selectAll(".link")
                        .attr("style", d => `stroke: ${linkColorScale(d.weight)} !important`)
                        .attr("stroke-width", 8)
                        .attr("stroke-dasharray", null);

                    // Find all paths with the node as source
                    const outgoingPathLinks = findOutgoingPathsFromNode(clicked_node.id);

                    // Highlight outgoing paths
                    d3.selectAll(".link")
                        .filter(d => outgoingPathLinks.has(d))
                        .attr("style", d => `stroke: ${highlightColorScale(d.weight)} !important`)
                        .attr("stroke-width", 6)
                        .attr("stroke-opacity", 1.0);

                    // Dashed lines, outgoing links
                    d3.selectAll(".link")
                        .attr("stroke-dasharray", link =>
                            (link.source.id === clicked_node.id || link.source === clicked_node.id) ? "5,5" : null);

                } catch (err) {
                    console.error("Error in updating visual:", err);
                }

            // Update URL and get host info
            try {
                // add filter to url
                add_filter('ip', clicked_node.id);

                await new Promise(resolve => setTimeout(resolve, 0));

                await get_host_info();
            } catch (err) {
                console.error("Error in URL/host update:", err);
            }
        }).on("dblclick", async function (event, clicked_node) {
            event.preventDefault();

            if (clickTimer) {
                clearTimeout(clickTimer);
                clickTimer = null;
            }
            lastClickedNode = null;

            selectedNode.value = clicked_node.id;

            // Filter links where the clicked node ID appears as source or destination
            const filteredLinks = links.filter(link => {
                const sourceId = link.source.id || link.source;
                const targetId = link.target.id || link.target;
                return sourceId === clicked_node.id || targetId === clicked_node.id;
            });

            // Extract the node IDs from filtered links
            const nodeIds = new Set();
            filteredLinks.forEach(link => {
                nodeIds.add(link.source.id || link.source);
                nodeIds.add(link.target.id || link.target);
            });

            // Filter nodes that are part of the filtered links
            const filteredNodes = nodes.filter(node => nodeIds.has(node.id));

            // Update global variables
            nodes = filteredNodes;
            links = filteredLinks;

            // add filter to url
            add_filter('ip', clicked_node.id);
            await get_host_info();

            // Redraw graph with the new filtered data
            await draw_graph(true, clicked_node.id);
        });

        // Add the node circles with color based on alert count
        const nodeRadius = 10;
        nodeGroup.append("circle")
            .attr("r", nodeRadius)
            .attr("fill", d => nodeColorScale(d.alert_count))
            .attr("stroke", "#212121")
            .attr("stroke-width", 1);

        nodeGroup.append("text")
            .attr("x", -nodeRadius - 6)
            .attr("y", 4)
            .attr("text-anchor", "end")
            .attr("font-size", "12px")
            .text(d => d.name || d.id); // render resolved name or ip

        // Bootstrap tooltips to nodes
        nodeGroup.each(function (d) {
            let total_alerts = d.incoming_count + d.outgoing_count;
            $(this).tooltip({
                title: `<strong>${d.name || d.id}</strong><br>
                Total Alerts: ${total_alerts}<br>
                Incoming: ${d.incoming_count}<br>
                Outgoing: ${d.outgoing_count}`,
                html: true,
                container: 'body',
                placement: 'top'
            });

        });

        // Get node position and extent for minimap
        const xExtent = d3.extent(nodes, d => d.x);
        const yExtent = d3.extent(nodes, d => d.y);

        // Add padding to the extents
        const paddingFactor = 0.1;
        const xPadding = (xExtent[1] - xExtent[0]) * paddingFactor || width * paddingFactor;
        const yPadding = (yExtent[1] - yExtent[0]) * paddingFactor || height * paddingFactor;

        const paddedXExtent = [xExtent[0] - xPadding, xExtent[1] + xPadding];
        const paddedYExtent = [yExtent[0] - yPadding, yExtent[1] + yPadding];

        // Get graph size
        const graphWidth = paddedXExtent[1] - paddedXExtent[0];
        const graphHeight = paddedYExtent[1] - paddedYExtent[0];

        // Set max zoom level (1.0 for 1x)
        const maxZoom = 6.0;
        const minZoom = Math.max(0.1, Math.min(
            width / graphWidth,
            height / graphHeight
        ) * 0.9); // 90% of the scale

        // Create zoom behavior with constraints
        const zoomBehavior = d3.zoom()
            .scaleExtent([minZoom, maxZoom])
            .translateExtent([[paddedXExtent[0], paddedYExtent[0]], [paddedXExtent[1], paddedYExtent[1]]])
            .on("zoom", (event) => {
                mainGroup.attr("transform", event.transform);
            });

        svg.call(zoomBehavior);

        // Store this in a global variable or access it later
        window.graphZoomBehavior = zoomBehavior;
        // If centerIP is provided, center the graph on that node
        if (centerIP) {
            centerOnNode(centerIP, svg, zoomBehavior, width, height);
        } else {
            // Center and scale the view to fit all nodes
            const padding = 50;

            const xSize = xExtent[1] - xExtent[0] + padding * 2;
            const ySize = yExtent[1] - yExtent[0] + padding * 2;

            const scale = Math.min(
                maxZoom,
                Math.max(minZoom, Math.min(width / xSize, height / ySize))
            );

            // Calculate center position
            const tx = width / 2 - (xExtent[0] + xExtent[1]) / 2 * scale;
            const ty = height / 2 - (yExtent[0] + yExtent[1]) / 2 * scale;

            svg.transition().duration(750)
                .call(zoomBehavior.transform, d3.zoomIdentity.translate(tx, ty).scale(scale));
        }

        loading.value = false;

    } catch (error) {
        console.error("Error drawing graph:", error);
        loading.value = false;
        hostDataLoading.value = false;
    } finally {
        loading.value = false;
    }
}


function centerOnNode(nodeId, svg, zoom, width, height) {
    const node = nodes.find(n => n.id === nodeId);
    if (!node) return;

    const x = node.x;
    const y = node.y;

    // Calculate the translation to center the node
    const tx = width / 2 - x * zoom.scale();
    const ty = height / 2 - y * zoom.scale();

    svg.transition().duration(750)
        .call(zoom.transform, d3.zoomIdentity.translate(tx, ty).scale(zoom.scale()));
}

function findNode() {

    if (!searchNodeId.value) return;

    const foundNode = nodes.find(node => ((node.id === searchNodeId.value) || (node.name === searchNodeId.value)));

    if (foundNode) {

        selectedNode.value = foundNode.id;

        const svg = d3.select(alerts_graph.value).select("svg");
        const zoom = window.graphZoomBehavior; // reuse the zoom behavior
        const g = svg.select("g"); // assuming your nodes/links are inside a <g> tag

        const newZoom = 3;

        const svgNode = svg.node();
        const width = svgNode.clientWidth || svgNode.getBoundingClientRect().width;
        const height = svgNode.clientHeight || svgNode.getBoundingClientRect().height;

        // First, apply scale
        svg.transition().duration(300)
            .call(zoom.scaleTo, newZoom)
            .transition().duration(300)
            .call(zoom.translateTo, foundNode.x, foundNode.y);

        // Highlight links and node
        d3.selectAll(".link")
            .attr("stroke-dasharray", link =>
                (link.source.id === foundNode.id || link.source === foundNode.id) ? "5,5" : null);

        d3.selectAll(".node-group circle")
            .attr("stroke", "#212121")
            .attr("stroke-width", 1);

        d3.selectAll(".node-group")
            .filter(d => d.id === foundNode.id)
            .select("circle")
            .attr("stroke", "#FFC107")
            .attr("stroke-width", 2);

        nodeNotFoundMessage.value = false;
    } else {
        nodeNotFoundMessage.value = true;
    }
}

function resetZoom() {
    const svg = d3.select(alerts_graph.value).select("svg");
    const zoom = window.graphZoomBehavior;

    svg.transition()
        .duration(500)
        .call(zoom.transform, d3.zoomIdentity);
}


/******************************************************************************/
/****************************** API GETTERS ********************************* */

const get_alerts_data = async function () {

    // Create url filters
    let url = `${http_prefix}/lua/pro/rest/v2/get/alert/graph/alerts.lua?`;
    url = create_url(url);

    try {
        let headers = {
            "Content-Type": "application/json",
        };
        const rsp = await ntopng_utility.http_request(url, { method: "get", headers });
        no_data.value = false;

        return rsp;

    } catch (err) {
        console.error(err);
    }
};


const get_host_info = async function () {
    // Create url filters
    hostDataLoading.value = true;
    let url = `${http_prefix}/lua/pro/rest/v2/get/alert/graph/host_info.lua?`;
    url = create_url(url);

    try {
        let headers = {
            "Content-Type": "application/json",
        };
        const rsp = await ntopng_utility.http_request(url, { method: "get", headers });

        if (rsp) {
            no_data.value = false;
            selectedNodeData.value = rsp
        }
        hostDataLoading.value = false;

        return [];
    } catch (err) {
        console.error(err);
        hostDataLoading.value = false;
    }
};
const get_active_flows = async function () {

    try {
        let headers = {
            "Content-Type": "application/json",
        };
        let url = `${http_prefix}/lua/rest/v2/get/flow/active_list.lua?start=0&length=10&map_search=&visible_columns=actions%2Clast_seen%2Cfirst_seen%2Cprotocol%2Cscore%2Cqoe%2Cflow%2Cthroughput%2Cbytes%2Cinfo&flowhosts_type=${selectedNode.value}%400&l4proto=&application=&alert_type=&qoe=&tcp_flow_state=&dscp=&traffic_type=&host_pool_id=&network=`;
        const rsp = await ntopng_utility.http_request(url, { method: "get", headers }, false, true);

        if (rsp && rsp.recordsTotal !== undefined) {
            return { recordsTotal: rsp.recordsTotal, live_flows_url };
        }

        return { recordsTotal: 0, live_flows_url };
    } catch (err) {
        console.error(err);
        return { recordsTotal: 0, url: "#" };
    }
};

const get_links_and_nodes = async function () {
    const data = await get_alerts_data();
    const links = [];
    const nodesDict = new Map();

    const incomingAlertsCounts = new Map();
    const outgoingAlertsCounts = new Map();

    // compute incoming and outgoing count for each node
    for (let alert of data) {

        const src_ip = alert.src_ip;
        const dst_ip = alert.dst_ip;
        const alertCount = parseInt(alert.alerts_count);

        // outgoing count for source IP (cli_ip)
        const currentOutgoing = outgoingAlertsCounts.get(src_ip) || 0;
        outgoingAlertsCounts.set(src_ip, currentOutgoing + alertCount);

        // incoming count for target IP (srv_ip)
        const currentIncoming = incomingAlertsCounts.get(dst_ip) || 0;
        incomingAlertsCounts.set(dst_ip, currentIncoming + alertCount);
    }

    for (let alert of data) {

        let link = {
            source: alert.src_ip,
            target: alert.dst_ip,
            weight: parseInt(alert.avg_alert_score),
            label: { alert_count: alert.alert_count, alert: alert.alert, avg_score: alert.avg_alert_score, src_asn: alert.src_asn, dst_asn: alert.dst_asn, src_country: alert.src_country, dst_country: alert.dst_country, protocol: alert.l4_proto, l7: alert.l7_app },
            alert_info: alert.info
        };

        links.push(link);

        // prepare node data
        if (!nodesDict.has(alert.src_ip)) {

            let node_data = {
                id: alert.src_ip, name: alert.src_ip, src_asn: alert.src_asn, src_country: alert.src_country,
                incoming_count: incomingAlertsCounts.get(alert.src_ip) || 0,
                outgoing_count: outgoingAlertsCounts.get(alert.src_ip) || 0,
                // total alerts count for node
                alert_count: (incomingAlertsCounts.get(alert.src_ip) || 0) +
                    (outgoingAlertsCounts.get(alert.src_ip) || 0)
            }

            if (alert?.src_name) {
                node_data["name"] = alert.src_name
            }
            nodesDict.set(alert.src_ip, node_data);
        }

        if (!nodesDict.has(alert.dst_ip)) {
            let node_data = {
                id: alert.dst_ip, name: alert.dst_ip, dst_asn: alert.dst_asn, dst_country: alert.dst_country,
                incoming_count: incomingAlertsCounts.get(alert.dst_ip) || 0,
                outgoing_count: outgoingAlertsCounts.get(alert.dst_ip) || 0,
                // total alerts count for node
                alert_count: (incomingAlertsCounts.get(alert.dst_ip) || 0) +
                    (outgoingAlertsCounts.get(alert.dst_ip) || 0)
            }

            if (alert?.dst_name) {
                node_data["name"] = alert.dst_name
            }
            nodesDict.set(alert.dst_ip, node_data);
        }
    }
    const nodes = Array.from(nodesDict.values());

    return { links, nodes };
};

/******************************************************************************/
/****************************** GUI HELPERS ********************************* */
// Handle resize event
function resize() {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(() => {
        draw_graph(true);
    }, 250);
}

function drag() {
    return d3.drag()
        .on("start", dragstarted)
        .on("drag", dragged)
        .on("end", dragended);

    function dragstarted(event, d) {
        // Sync d.x and d.y with the actual position from the transform
        const [x, y] = d3.select(this).attr("transform").match(/translate\(([^,]+),([^)]+)\)/).slice(1).map(Number);
        d.x = x;
        d.y = y;

        $(this).tooltip('hide');
        $(this).tooltip('disable');

        d3.select(this).raise();
    }

    function dragged(event, d) {
        d.x = event.x;
        d.y = event.y;

        // Move group
        d3.select(this).attr("transform", `translate(${d.x}, ${d.y})`);
        
        // Create a direct reference to the node being dragged
        const draggedNode = d;
        
        // Use a Map to group links by source-target pair
        const linkGroups = new Map();
        
        // First pass: group links by their source-target combinations
        d3.selectAll(".link").each(function(linkData, i) {
            if (!linkData) return;
            
            // Extract source and target IDs
            const sourceId = typeof linkData.source === 'object' ? linkData.source.id : linkData.source;
            const targetId = typeof linkData.target === 'object' ? linkData.target.id : linkData.target;
            
            // Only process links connected to the dragged node
            if (sourceId === draggedNode.id || targetId === draggedNode.id) {
                // Create a unique key for each source-target pair
                const key = sourceId < targetId ? 
                           `${sourceId}-${targetId}` : 
                           `${targetId}-${sourceId}`;
                
                if (!linkGroups.has(key)) {
                    linkGroups.set(key, []);
                }
                
                linkGroups.get(key).push({
                    element: this,
                    linkData: linkData,
                    sourceId: sourceId,
                    targetId: targetId
                });
            }
        });
        
        // Second pass: update each group of links with different offsets
        let totalLinks = 0;
        
        linkGroups.forEach((links, key) => {
            totalLinks += links.length;
            
            // For each group of links between the same nodes
            links.forEach((pathInfo, groupIndex) => {
                const element = pathInfo.element;
                const linkData = pathInfo.linkData;
                
                // Update source/target positions
                if (typeof linkData.source === 'object' && linkData.source) {
                    if (linkData.source.id === draggedNode.id) {
                        linkData.source.x = draggedNode.x;
                        linkData.source.y = draggedNode.y;
                    }
                }
                
                if (typeof linkData.target === 'object' && linkData.target) {
                    if (linkData.target.id === draggedNode.id) {
                        linkData.target.x = draggedNode.x;
                        linkData.target.y = draggedNode.y;
                    }
                }
                
                // Get source and target positions
                const sourceX = linkData.source.x !== undefined ? linkData.source.x : 0;
                const sourceY = linkData.source.y !== undefined ? linkData.source.y : 0;
                const targetX = linkData.target.x !== undefined ? linkData.target.x : 0;
                const targetY = linkData.target.y !== undefined ? linkData.target.y : 0;
                
                // Calculate path with varying offsets for multiple links between same nodes
                const midX = (sourceX + targetX) / 2;
                const midY = (sourceY + targetY) / 2;
                const dx = targetX - sourceX;
                const dy = targetY - sourceY;
                const dist = Math.sqrt(dx * dx + dy * dy);
                
                // Base offset
                const baseOffset = 10;
                
                // Vary offset by group index for multiple links between same nodes
                // Links in the same group get progressively larger offsets
                const offsetMultiplier = links.length > 1 ? 
                                         (1 + groupIndex * 0.5) : 1;
                const offset = baseOffset * offsetMultiplier;
                
                // Create path
                let pathD;
                if (dist > 10) {
                    const offsetX = -dy * offset / dist;
                    const offsetY = dx * offset / dist;
                    pathD = `M${sourceX},${sourceY} Q${midX + offsetX},${midY + offsetY} ${targetX},${targetY}`;
                } else {
                    pathD = `M${sourceX},${sourceY} L${targetX},${targetY}`;
                }
                
                // Update path
                d3.select(element).attr("d", pathD);
            });
        });

    }

    function dragended(event, d) {
        // re-enable tooltip
        $(this).tooltip('enable');
    }
}

onMounted(async () => {
    // Set default url parameters
    init_url_params();

    // Initially draw the graph
    await draw_graph();

    window.addEventListener("resize", resize);

    // get active flows value
    activeFlows.value = await get_active_flows();

    // Init bootstrap tooltip
    nextTick(() => {
        NtopUtils.reloadBSTooltips();
    });

    const tooltipTriggerminIncomingEdges = new bootstrap.Tooltip(slider_min_incoming_edges.value, { trigger: 'manual' });
    slider_min_incoming_edges.value.addEventListener('input', () => {
        $(".tooltip-inner").text(minIncomingEdges.value)
        slider_min_incoming_edges.value.setAttribute('data-bs-original-title', minIncomingEdges.value);
        tooltipTriggerminIncomingEdges.show();
    });
    slider_min_incoming_edges.value.addEventListener('mouseup', () => {
        applyFilters()
    })

    const tooltipTriggerminOutgoingEdges = new bootstrap.Tooltip(slider_min_outgoing_edges.value, { trigger: 'manual' });
    slider_min_outgoing_edges.value.addEventListener('input', () => {
        $(".tooltip-inner").text(minOutgoingEdges.value)
        slider_min_outgoing_edges.value.setAttribute('data-bs-original-title', minOutgoingEdges.value);
        tooltipTriggerminOutgoingEdges.show();
    });
    slider_min_outgoing_edges.value.addEventListener('mouseup', () => {
        applyFilters()
    })
    last_url.value = window.location.href;
    ntopng_events_manager.on_event_change('range_picker', ntopng_events.FILTERS_CHANGE, (new_status) => { applyFilters(); }, true);
    ntopng_events_manager.on_event_change('range_picker', ntopng_events.EPOCH_CHANGE, (new_status) => { applyFilters(); }, true);
});

onBeforeUnmount(() => {
    document.removeEventListener('click', () => { });

});

watch(minOutgoingEdges, (newValue) => {
    let min_outgoing_edges = newValue;
    add_filter('min_outgoing', min_outgoing_edges);
});

watch(minIncomingEdges, (newValue) => {
    let min_incoming_edges = newValue;
    add_filter('min_incoming', min_incoming_edges);
});

watch(searchNodeId, (newValue) => {
    // reset zoom if no node is selected
    if (newValue.length === 0) {
        resetZoom();
    }
});

function init_url_params() {
    ntopng_url_manager.set_key_to_url("ifid", ifid);
    // This is to retrieve all alerts and not filter on engaged or require attention
    ntopng_url_manager.set_key_to_url("status", "any");

    if (ntopng_url_manager.get_url_entry("epoch_begin") == null
        || ntopng_url_manager.get_url_entry("epoch_end") == null) {
        let now = Date.now();
        let default_epoch_begin = Number.parseInt((now - 1000 * 30 * 60) / 1000);
        let default_epoch_end = Number.parseInt(now / 1000);
        ntopng_url_manager.set_key_to_url("epoch_begin", default_epoch_begin);
        ntopng_url_manager.set_key_to_url("epoch_end", default_epoch_end);
    }

    // initial filters
    let score_greater_equal = minOutgoingEdges.value + ";gte";
    ntopng_url_manager.set_key_to_url("score", score_greater_equal);
    ntopng_url_manager.set_key_to_url("severity", "");
    ntopng_url_manager.set_key_to_url("ip", "");
    ntopng_url_manager.set_key_to_url("min_outgoing", 0);
    ntopng_url_manager.set_key_to_url("min_incoming", 0);
}

function add_filter(filter, value) {
    ntopng_url_manager.set_key_to_url(filter, value);
}

function reset_filters() {
    minOutgoingEdges.value = 0;
    minIncomingEdges.value = 0;
    
    // get all url parameters
    const currentParams = Object.keys(ntopng_url_manager.get_url_object());
    
    // remove all parameters
    ntopng_url_manager.delete_params(currentParams);

    init_url_params();

    applyFilters();
}

function get_url_param(param) {
    let params = ntopng_url_manager.get_url_object();
    for (const param_key in params) {
        if (param === param_key) {
            return params[param];
        }
    }

    return null;
}
const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

const create_url = (url) => {
    let req_params = get_extra_params_obj();

    let params_inserted = 0;

    for (let param in req_params) {

        if (params_inserted > 0) {
            url += '&';
        }

        url += `${param}=${encodeURIComponent(req_params[param])}`;
        params_inserted += 1;
    }

    return url;
}

/******************************************************************************/

</script>

<style scoped>
.dashboard-container {
    min-height: 60vh;
    padding: 1.5rem;
}

.filter-panel {
    border-radius: 8px;
    border: none;
}

.graph-content {
    width: 100%;
    height: 100%;
    min-height: 60vh;
}

.card {
    border: none;
    border-radius: 8px;
    overflow: hidden;
}

.card-header {
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    padding: 1rem 1.5rem;
}

.card-footer {
    border-top: 1px solid rgba(0, 0, 0, 0.05);
    padding: 0.75rem 1.5rem;
}

.detail-item {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.75rem;
}

.detail-label {
    color: #6c757d;
    font-weight: bold;
}


.alert-summary {
    border-radius: 6px;
}

.dropdown-menu {
    max-height: 200px;
    overflow-y: auto;
    border: none;
    border-radius: 6px;
}

.dropdown-item {
    padding: 0.5rem 1rem;
}

.dropdown-item:hover {
    background-color: #f8f9fa;
}

.badge {
    width: 12px;
    height: 12px;
    display: inline-block;
    border-radius: 50%;
}

.nav-tabs {
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

.nav-tabs .nav-link {
    border: none;
    color: #6c757d;
    padding: 0.5rem 1rem;
    font-weight: 500;
}

.nav-tabs .nav-link.active {
    color: #0d6efd;
    border-bottom: 2px solid #0d6efd;
    background: transparent;
}

.tab-content {
    padding-top: 1rem;
}

.detail-row {
    display: flex;
    justify-content: space-between;
    padding: 5px 0;
}

.detail-label {
    font-weight: bold;
    flex: 1;
    text-align: left;
}

.detail-value {
    flex: 1;
    text-align: right;
    font-weight: 600;
}

.dropdown {
    position: relative;
}

.dropdown-menu.show {
    display: block;
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 1000;
    width: 100%;
    max-height: 300px;
    overflow-y: auto;
    margin-top: 2px;
}
</style>