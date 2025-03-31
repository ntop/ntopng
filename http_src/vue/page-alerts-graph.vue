<template>
    <div class="dashboard-container bg-light">
        <!-- Filter Controls Panel -->
        <div class="card shadow-sm mb-4">
            <div class="card-body">
                <div class="row align-items-center">
                    <div class="col-md-3">
                        <label for="alertCategory" class="form-label fw-semibold">{{
                            _i18n("alert.graph.alert_categories") }}</label>
                        <div class="dropdown" ref="dropdownRef">
                            <input type="text" id="alertCategory" v-model="selectedAlertCategory" class="form-control"
                                placeholder="Select or search categories" @input="filterCategories"
                                @focus="showAlertCategoriesDropdown = true" />
                            <ul class="dropdown-menu w-100 shadow-sm position-absolute"
                                :class="{ show: showAlertCategoriesDropdown }">
                                <li v-for="category in filteredAlertCategories" :key="category.category_id">
                                    <a class="dropdown-item" href="#" @click.prevent="selectAlertCategory(category)">
                                        {{ category.alert_category }} ({{ category.alerts_count }})
                                    </a>
                                </li>
                            </ul>
                        </div>
                    </div>

                    <div class="col-md-4">
                        <label class="form-label fw-semibold">{{ _i18n("alert.graph.minimum_score") }}{{ minScore
                        }}</label>
                        <input type="range" class="form-range" min="0" max="350" v-model="minScore" />
                    </div>

                    <div class="col-md-3">
                        <label class="form-label fw-semibold">{{ _i18n("alert.graph.maximum_alerts") }} {{ maxAlerts
                        }}</label>
                        <input type="range" class="form-range" min="10" max="2000" v-model="maxAlerts" />
                    </div>

                    <div class="col-md-2 d-flex align-items-end justify-content-end mt-3">
                        <button class="btn btn-outline-secondary me-2" @click="reset_filters">
                            <i class="fa-solid fa-clock-rotate-left"></i> {{ _i18n("alert.graph.reset") }}
                        </button>
                        <button class="btn btn-primary" @click="applyFilters">
                            <i class="fa-solid fa-magnifying-glass"></i> {{ _i18n("alert.graph.apply") }}
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Main Content -->
        <div class="row g-4">
            <!-- Graph Visualization Section -->
            <div class="col-lg-8">
                <div class="card shadow-sm h-100">
                    <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0 fw-bold">{{ _i18n("alert.graph.alerts_topology") }}</h5>
                        <button class="btn btn-sm btn-outline-secondary" @click="resetGraph">
                            <i class="fa-solid fa-rotate-right"></i>
                        </button>
                    </div>
                    <div class="card-body p-0">
                        <div ref="alerts_graph" class="graph-content">
                            <div v-if="no_data" class="d-flex justify-content-center align-items-center h-100">
                                <p class="text-center text-muted">{{ _i18n("alert.graph.no_data") }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Node Details Section -->
            <div class="col-lg-4">
                <div class="card shadow-sm h-100">
                    <div class="card-header bg-white py-3">
                        <h5 class="card-title mb-0 fw-bold">{{ _i18n("alert.graph.node_details") }}</h5>
                    </div>
                    <div class="card-body" v-if="selectedNode">
                        <div class="node-details">
                            <div class="mb-4">
                                <h6 class="fw-bold fs-5">
                                    <i class='fas fa-laptop'></i> {{ selectedNodeData?.host_info?.info?.ip || 'N/A' }}
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
                                        <a v-if="selectedNodeData?.host_info?.info?.asn_name !== selectedNode"
                                            :href="asnPageUrl" target="_blank" class="fw-bold text-primary">
                                            {{ selectedNodeData?.host_info?.info?.asn_name }}
                                        </a>
                                    </div>

                                    <div class="col-12">
                                        <span class="detail-label">{{ _i18n("alert.graph.live_flows") }}</span>
                                        <a :href="activeFlows.live_flows_url" target="_blank"
                                            class="fw-bold text-primary">
                                            {{ activeFlows.recordsTotal }}
                                        </a>
                                    </div>
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
                                <button class="nav-link" data-bs-toggle="tab" data-bs-target="#server" type="button">
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
                                            <span class="detail-label">{{ _i18n("alert.graph.first_seen") }}</span>
                                            <span class="detail-value">{{ selectedNodeData.host_info[role]?.first_seen
                                                || '-' }}</span>
                                        </div>
                                        <div class="detail-row">
                                            <span class="detail-label">{{ _i18n("alert.graph.last_seen") }}</span>
                                            <span class="detail-value">{{ selectedNodeData.host_info[role]?.last_seen ||
                                                '-' }}</span>
                                        </div>
                                        <div class="detail-row">
                                            <span class="detail-label">{{ _i18n("alert.graph.alerts_count") }}</span>
                                            <span class="detail-value">{{
                                                formatterUtils.getFormatter("number")(selectedNodeData.host_info[role]?.alerts_count)
                                                || '-' }}</span>
                                        </div>
                                        <div class="detail-row">
                                            <span class="detail-label">{{ _i18n("alert.graph.total_score") }}</span>
                                            <span class="detail-value">{{
                                                formatterUtils.getFormatter("number")(selectedNodeData.host_info[role]?.total_score)
                                                || '-' }}</span>
                                        </div>
                                        <div class="detail-row">
                                            <span class="detail-label">{{ _i18n("alert.graph.total_score") }}</span>
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
                                            <div class="progress mb-3" style="height: 8px;" data-bs-toggle="tooltip" data-bs-placement="top">
                                                <div v-for="(item, index) in selectedNodeData.severity_info?.[role]"
                                                    :key="index" class="progress-bar"
                                                    :style="{ width: item.percentage + '%', backgroundColor: item.severity_color }"
                                                    role="progressbar"
                                                    :title="`${item.percentage.toFixed(2)}% ${item.severity}`"
                                                    >
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </template>
                        </div>
                    </div>
                    <div v-else class="d-flex justify-content-center align-items-center h-100">
                        <p class="text-center text-muted"><i class="fa-solid fa-circle-info"></i> Select a node to view
                            details.</p>
                    </div>
                </div>
            </div>
        </div>
    </div>

</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch, computed } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import formatterUtils from "../utilities/formatter-utils";
const _i18n = (t) => i18n(t);
const d3 = d3v7;

const props = defineProps({
    context: Object,
});

// State data
const ifid = String(props.context.ifid);
const now = Math.round(new Date().getTime() / 1000)
const no_data = ref(false);
const alerts_graph = ref(null);
const dropdownRef = ref(null);
const maxAlerts = ref(10000);
const minScore = ref(0);

// Selected node information (right div next to graph)
const selectedAlertCategory = ref(null);
const selectedNodeData = ref({});
const isNodeLoading = ref(false);
const selectedNode = ref(false);
const activeFlows = ref({ recordsTotal: 0, url: "#" });

const asnPageUrl = computed(() => {
    return `${http_prefix}/lua/hosts_stats.lua?asn=${selectedNodeData.value?.host_info?.info?.asn || ''}&version=&network=&traffic_type=&mode=&pool=`;
});

const live_flows_url = computed(() => {
    return `${http_prefix}/lua/flows_stats.lua?flowhosts_type=${selectedNode.value}%400&l4proto=&application=&alert_type=&qoe=&tcp_flow_state=&dscp=&traffic_type=&host_pool_id=&network=#`;
});

const active_list_url = computed(() => {
    return `${http_prefix}/lua/rest/v2/get/flow/active_list.lua?start=0&length=10&map_search=&visible_columns=actions%2Clast_seen%2Cfirst_seen%2Cprotocol%2Cscore%2Cqoe%2Cflow%2Cthroughput%2Cbytes%2Cinfo&flowhosts_type=${selectedNode.value}%400&l4proto=&application=&alert_type=&qoe=&tcp_flow_state=&dscp=&traffic_type=&host_pool_id=&network=`;
});

// Dropdown state
const showAlertCategoriesDropdown = ref(false);
const filteredAlertCategories = ref([]);
const alertCategories = ref([]);

// D3 Graph data
let links = [];
let nodes = [];
let simulation = null;
let resizeTimeout;

let clickTimer = null;
let lastClickedNode = null;


// Cache D3 data
const sourceNodes = ref([]);
const destNodes = ref([]);

/**********************************************/

const handleClickOutside = (event) => {
    if (!event.target.closest('#alertCategory') &&
        !event.target.closest('.dropdown-menu') &&
        !event.target.closest('.dropdown-item')) {
        showAlertCategoriesDropdown.value = false;
    }
};


const applyFilters = async () => {
    let center_graph_on_ip = null;

    // Empty links and nodes to make request to backend
    links = [];
    nodes = [];

    // Draw graph with new filters
    await draw_graph(true, center_graph_on_ip);
};

const selectAlertCategory = (category) => {
    selectedAlertCategory.value = `${category.alert_category} (${category.alerts_count})`;
    console.log("Selected Category ID:", category.category_id);
    showAlertCategoriesDropdown.value = false;
};


// **Filtering function**
const filterCategories = (event) => {
    const searchText = event.target.value.toLowerCase();
    filteredAlertCategories.value = alertCategories.value.filter(category =>
        category.alert_category.toLowerCase().includes(searchText)
    );
};

/******************************************************************************/
/**************************** GRAPH FUNCTIONS ******************************* */

async function draw_graph(redraw = false, centerIP = null) {
    // remove old tooltips
    $('.tooltip').remove();
    $('[data-toggle="tooltip"]').tooltip('dispose');

    if (redraw && links.length === 0 && nodes.length === 0) {

        const data = await get_links_and_nodes();
        links = data.links;
        nodes = data.nodes;
    }

    if (nodes.length === 0) {
        no_data.value = true;
        return;
    } else {
        no_data.value = false;
    }

    d3.select(alerts_graph.value).select("svg").remove();

    const width = alerts_graph.value.clientWidth || alerts_graph.value.offsetWidth || alerts_graph.value.getBoundingClientRect().width;
    const height = alerts_graph.value.clientHeight || 500;

    // Create SVG with zoom behavior
    const svg = d3.select(alerts_graph.value)
        .append("svg")
        .attr("width", width)
        .attr("height", height);

    // Store the zoom behavior to access it later for centering
    const zoom = d3.zoom()
        .scaleExtent([0.1, 4])
        .on("zoom", zoomed)
        .filter(event => {
            // Prevent zooming on double-click
            return event.type !== 'dblclick';
        });

    // Apply zoom to SVG
    svg.call(zoom);

    // Create main group for zoom transformations
    const mainGroup = svg.append("g");

    function zoomed(event) {
        mainGroup.attr("transform", event.transform);
    }


    // Calculate alert counts for each node
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

    // Node color scale based on alert count
    const nodeColorScale = d3.scaleSequential()
        .domain([0, d3.max(nodes, d => d.alert_count) || 1])
        .interpolator(d3.interpolateYlOrRd);

    // Link color scale
    const linkColorScale = d3.scaleThreshold()
        .domain([1, 50, 100])
        .range(["#E0E0E0", "#FFB74D", "#FF9800", "#FF8F00"]);

    simulation = d3.forceSimulation(nodes)
        .force("link", d3.forceLink(links).id(d => d.id).distance(150))
        .force("charge", d3.forceManyBody().strength(-500))
        .force("center", d3.forceCenter(width / 2, height / 2));

    const link = mainGroup.append("g")
        .selectAll("line")
        .data(links)
        .enter().append("line")
        .attr("class", "link")
        .attr("style", d => {
            return `stroke: ${linkColorScale(d.weight)} !important`
        })
        .attr("stroke-opacity", 0.8)
        .attr("stroke-width", d => Math.sqrt(d.weight) / 4)
        .attr("stroke-dasharray", null)  // No initial dash pattern
        .attr("marker-end", "url(#arrow)");

    // Add Bootstrap tooltips to links
    link.each(function (d) {
        let tooltipContent = `<strong>${d.label.alert}</strong><br>`;

        if (d.label.avg_score) tooltipContent += `Avg Score: ${d.label.avg_score}<br>`;
        if (d.label.src_asn) tooltipContent += `Source ASN: ${d.label.src_asn}<br>`;
        if (d.label.dst_asn) tooltipContent += `Destination ASN: ${d.label.dst_asn}<br>`;

        if (d.label.src_country) {
            tooltipContent += `Source Country: ${d.label.src_country} <img src='/dist/images/blank.gif' class='flag flag-${d.label.src_country.toLowerCase()}'><br>`;
        }
        if (d.label.dst_country) {
            tooltipContent += `Destination Country: ${d.label.dst_country} <img src='/dist/images/blank.gif' class='flag flag-${d.label.dst_country.toLowerCase()}'><br>`;
        }

        tooltipContent += `L4 Protocol: ${d.label.protocol}<br>L7 Application: ${d.label.l7}`;

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

    // Create a group for each node
    const nodeGroup = mainGroup.append("g")
        .selectAll("g")
        .data(nodes)
        .enter().append("g")
        .attr("class", "node-group")
        .call(drag(simulation))
        // Handle clicks with a delay to distinguish single vs double clicks
        .on("click", (event, clicked_node) => {
            // Clear any existing timeout

            if (clickTimer) {
                clearTimeout(clickTimer);
                clickTimer = null;

                // If we click the same node twice quickly, it's a double-click

                if (lastClickedNode === clicked_node.id) {
                    lastClickedNode = null;
                    return; // Don't process as a single click
                }
            }

            // Save the clicked node ID
            lastClickedNode = clicked_node.id;

            // Set a timeout to process this as a single click after a delay
            clickTimer = setTimeout(() => {
                clickTimer = null;

                // This is the single-click handler logic
                // Reset all node styles
                d3.selectAll(".node-group circle")
                    .attr("stroke", "#212121")
                    .attr("stroke-width", 1);

                // Highlight the selected node
                d3.select(event.currentTarget).select("circle")
                    .attr("stroke", "#FFC107") // Amber highlight
                    .attr("stroke-width", 2);

                // Update all edges - dashed for outgoing, solid for incoming
                d3.selectAll(".link")
                    .attr("stroke-dasharray", link =>

                        (link.source.id === clicked_node.id || link.source === clicked_node.id) ? "5,5" : null);

                selectedNode.value = clicked_node.id;

                // add filter to url
                add_filter('ip', clicked_node.id);

                await get_host_info();
            }, 200);
        })
        .on("dblclick", async function (event, clicked_node) {
            // Clear the single-click timer since this is a double-click

            if (clickTimer) {
                clearTimeout(clickTimer);
                clickTimer = null;
            }
            lastClickedNode = null;

            selectedNode.value = clicked_node.id;


            // Filter links where the clicked node's ID appears as either source or destination
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

    // Add Bootstrap tooltips to nodes
    nodeGroup.each(function (d) {
        $(this).tooltip({
            title: `<strong>${d.id}</strong><br>Alert Count: ${d.alert_count}`,
            html: true,
            container: 'body',
            placement: 'top'
        });
    });

    const label = mainGroup.append("g")
        .selectAll("text")
        .data(nodes)
        .enter().append("text")
        .attr("dy", -15)
        .attr("text-anchor", "middle")
        .text(d => d.id)
        .attr("font-size", "10px");

    simulation.on("tick", () => {
        link
            .attr("x1", d => d.source.x)
            .attr("y1", d => d.source.y)
            .attr("x2", d => d.target.x)
            .attr("y2", d => d.target.y);

        nodeGroup
            .attr("transform", d => `translate(${d.x}, ${d.y})`);

        label
            .attr("x", d => d.x)
            .attr("y", d => d.y);
    });

    // If centerIP is provided, center the graph on that node after simulation stabilizes
    if (centerIP) {
        // Wait for the simulation to stabilize
        simulation.on("end", () => {
            centerOnNode(centerIP, svg, zoom, width, height);
        });
    }
}

// Function to center the graph on a specific node
function centerOnNode(nodeId, svg, zoom, width, height) {
    const targetNode = nodes.find(node => node.id === nodeId);

    if (targetNode) {
        // Calculate the transform to center on the node
        const scale = 1.5; // Zoom level
        const x = width / 2 - targetNode.x * scale;
        const y = height / 2 - targetNode.y * scale;

        // Apply the transform
        svg.transition()
            .duration(750)
            .call(zoom.transform, d3.zoomIdentity
                .translate(x, y)
                .scale(scale));

        // Highlight the centered node
        d3.selectAll(".node-group circle")
            .attr("stroke", "#212121")
            .attr("stroke-width", 1);

        // Find and highlight the specific node
        d3.selectAll(".node-group")
            .filter(d => d.id === nodeId)
            .select("circle")
            .attr("stroke", "#FFC107")
            .attr("stroke-width", 2);

        // Update edges to show connections from this node
        d3.selectAll(".link")
            .attr("stroke-dasharray", link =>
                (link.source.id === nodeId || link.source === nodeId) ? "5,5" : null);

        // Set as selected node
        const node = nodes.find(n => n.id === nodeId);
        if (node) {
            selectedNode.value = node;
        }
    }
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

        if (rsp) {
            no_data.value = false;
            return rsp;
        }

        return [];
    } catch (err) {
        console.error(err);
    }
};

const get_alert_categories = async function () {

    // Create url filters
    let url = `${http_prefix}/lua/pro/rest/v2/get/alert/categories.lua?`;
    url = create_url(url);

    try {
        let headers = {
            "Content-Type": "application/json",
        };
        const rsp = await ntopng_utility.http_request(url, { method: "get", headers });

        if (rsp) {
            //rsp = [{"alerts_count":"102","alert_category":"Cybersecurity","category_id":1}
            alertCategories.value = rsp;
            filteredAlertCategories.value = [...alertCategories.value];
        }

        return [];
    } catch (err) {
        console.error(err);
    }
};

const get_host_info = async function () {
    // Create url filters
    let url = `${http_prefix}/lua/pro/rest/v2/get/alert/graph/host_info.lua?`;
    url = create_url(url);

    try {
        let headers = {
            "Content-Type": "application/json",
        };
        const rsp = await ntopng_utility.http_request(url, { method: "get", headers });

        if (rsp) {
            selectedNodeData.value = rsp
        }

        return [];
    } catch (err) {
        console.error(err);
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

    // Clear existing arrays
    sourceNodes.value = [];
    destNodes.value = [];

    for (let alert of data) {
        let link = {
            source: alert.src_ip,
            target: alert.dst_ip,
            weight: parseInt(alert.avg_alert_score),
            label: { alert: alert.alert, avg_score: alert.avg_alert_score, src_asn: alert.src_asn, dst_asn: alert.dst_asn, src_country: alert.src_country, dst_country: alert.dst_country, protocol: alert.l4_proto, l7: alert.l7_app },
            alert_info: alert.info
        };

        links.push(link);

        // prepare node data
        if (!nodesDict.has(alert.src_ip))
            nodesDict.set(alert.src_ip, { id: alert.src_ip, name: alert.src_ip, src_asn: alert.src_asn, src_country: alert.src_country });

        if (!nodesDict.has(alert.dst_ip))
            nodesDict.set(alert.dst_ip, { id: alert.dst_ip, name: alert.dst_ip, dst_asn: alert.dst_asn, dst_country: alert.dst_country });

        // Track unique source IPs
        if (!sourceNodes.value.includes(alert.src_ip)) {
            sourceNodes.value.push(alert.src_ip);
        }

        // Track unique destination IPs
        if (!destNodes.value.includes(alert.dst_ip)) {
            destNodes.value.push(alert.dst_ip);
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

// Helper function for node dragging
function drag(simulation) {
    function dragstarted(event) {
        if (!event.active) simulation.alphaTarget(0.3).restart();
        event.subject.fx = event.subject.x;
        event.subject.fy = event.subject.y;
    }

    function dragged(event) {
        event.subject.fx = event.x;
        event.subject.fy = event.y;
    }

    function dragended(event) {
        if (!event.active) simulation.alphaTarget(0);
        event.subject.fx = null;
        event.subject.fy = null;
    }

    return d3.drag()
        .on("start", dragstarted)
        .on("drag", dragged)
        .on("end", dragended);
}

onMounted(async () => {

    init_url_params();
    await get_alert_categories();
    // Initially draw the graph
    await draw_graph(true);
    // get host info and active flows value
    await get_host_info();
    activeFlows.value = await get_active_flows();

    // Add resize event listener to handle dynamic resizing
    window.addEventListener("resize", resize);

    // Close pickers when clicking outside
    document.addEventListener('click', handleClickOutside);

    // get host info and active flows value
    await get_host_info();
    activeFlows.value = await get_active_flows();

    document.addEventListener("click", (event) => {
        if (dropdownRef.value && !dropdownRef.value.contains(event.target)) {
            showAlertCategoriesDropdown.value = false;
        }
    });

    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
        tooltipTriggerList.forEach((tooltipTriggerEl) => {
          new bootstrap.Tooltip(tooltipTriggerEl);
        });

});

onBeforeUnmount(() => {
    document.removeEventListener('click', () => { });
    document.removeEventListener('click', handleClickOutside);

});

watch(minScore, (newValue) => {
    add_filter('score', newValue);
});

watch(maxAlerts, (newValue) => {
    add_filter('limit', newValue);
});

watch(alertCategories, (newCategories) => {
    filteredAlertCategories.value = [...newCategories];
}, { immediate: true });

function init_url_params() {
    ntopng_url_manager.set_key_to_url("ifid", ifid);

    if (ntopng_url_manager.get_url_entry("epoch_begin") == null
        || ntopng_url_manager.get_url_entry("epoch_end") == null) {
        let now = Date.now();
        let default_epoch_begin = Number.parseInt((now - 1000 * 30 * 60) / 1000);
        let default_epoch_end = Number.parseInt(now / 1000);
        ntopng_url_manager.set_key_to_url("epoch_begin", default_epoch_begin);
        ntopng_url_manager.set_key_to_url("epoch_end", default_epoch_end);
    }

    // initial filters
    ntopng_url_manager.set_key_to_url("score", minScore.value);
    ntopng_url_manager.set_key_to_url("limit", maxAlerts.value);
    ntopng_url_manager.set_key_to_url("severity", "");

}

function add_filter(filter, value) {
    ntopng_url_manager.set_key_to_url(filter, value);
}

function reset_filters() {
    minScore.value = 0;
    maxAlerts.value = 10000;
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

function resetGraph() {
    // Check if we have the original data cached
    if (sourceNodes.value.length === 0 || destNodes.value.length === 0) {
        // If we don't have cached data, we'll need to fetch it again
        draw_graph(true);
        return;
    }

    // Restore original nodes and links from cache
    nodes = [...sourceNodes.value];
    links = [...destNodes.value];

    // Redraw the graph with the full dataset
    // false parameter means don't fetch new data
    draw_graph(true);

    // Reset any filters or selections
    selectedNode.value = "";

    reset_filters();
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
    width: 100ch;
    height: 60vh;
    min-height: 700px;
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
    font-weight: 500;
}

.detail-value {
    color: #212529;
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

/* Tab styling */
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