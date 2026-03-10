<template>
    <div ref="sankey_div"
        class="d-flex align-items-center justify-content-center flex-column flex-grow-1 position-relative">
        <!-- Zoom button group -->
        <div v-if="!no_data" class="mb-2">
            <div class="btn-group btn-ontop" role="group">
                <button type="button" class="btn zoom-btn" @click="zoomChart(0.5)">
                    <i class="fa-solid fa-magnifying-glass-plus" data-bs-toggle="tooltip" data-bs-placement="top" :title="_i18n('date_time_range_picker.btn_zoom_in')"></i>
                </button>
                <button type="button" class="btn zoom-btn" @click="zoomChart(-0.5)">
                    <i class="fa-solid fa-magnifying-glass-minus" data-bs-toggle="tooltip" data-bs-placement="top" :title="_i18n('date_time_range_picker.btn_zoom_out')"></i>
                </button>
                <button v-if="showAutoRefresh" button type="button" data-bs-toggle="tooltip" data-bs-placement="top" class="btn refresh-btn" @click="toggleAutoRefresh"
                    :class="{ 'active': autoRefreshEnabled }"
                    :title="autoRefreshEnabled ? 'Auto-refresh enabled' : 'Auto-refresh disabled'">
                    <i class="fa-solid fa-arrows-rotate" :class="{ 'fa-spin': autoRefreshEnabled }"></i>
                </button>
            </div>
        </div>

        <!-- no data -->
        <NoData :show="no_data"></NoData>
        
        <div ref="sankey_wrapper"></div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, onBeforeUnmount, watch, computed } from "vue";
import { sankey, sankeyLinkHorizontal } from "d3-sankey";
import NoData from './components/no-data.vue'

const d3 = d3v7;
const emit = defineEmits(['node_click', 'update_width', 'update_height', 'autorefresh_toggle'])
const _i18n = (t) => i18n(t);
let eventsAttached = false;
let resizeTimeout = null;

function setNoDataFlag(set_no_data) {
    no_data.value = set_no_data
}

const props = defineProps({
    no_data_message: String,
    width: Number,
    height: Number,
    sankey_data: Object,
    autorefresh: { type: Boolean, default: null }
});

const autoRefreshEnabled = ref(props.autorefresh ?? true);
const showAutoRefresh = computed(() => props.autorefresh !== null);

const sankey_size = ref({});
const no_data = ref(false);
const sankey_wrapper = ref(null);
const sankey_div = ref(null);

let svg = null;
let zoomGroup = null;
let sankeyRef = null;
let sankeyData = null;
let isZoomed = ref(false);
const currentScale = ref(1); // keep track of zzom
let nodeDrag = null;
let isDraggingNode = false;

let zoom = null;

function toggleAutoRefresh() {
    autoRefreshEnabled.value = !autoRefreshEnabled.value;
    emit('autorefresh_toggle', autoRefreshEnabled.value);
}

/* ******************************************** */

onBeforeMount(async () => { });

/* ******************************************** */

onMounted(async () => {
    await set_sankey_data();
});

/* ******************************************** */

onBeforeUnmount(() => {
    if (svg) {
        // clean up all D3 elements
        svg.selectAll('*').remove();
        svg.on('dblclick', null);
        svg.on('mousemove', null);
        svg.on('mouseleave', null);
    }
    
    eventsAttached = false;
});

/* ******************************************** */

watch(() => props.sankey_data, (cur_value, old_value) => {
    set_sankey_data(true);
});

/* ******************************************** */

/* ZOOM FUNCTIONS */

// zoomValue must be float, 1.0 is 100% zoom, 1.5 is 150% and so on
function zoomChart(zoomValue) {
    if (!zoom) return;
    if (!svg) return; /* Check if the svg is defined */
    let newZoomValue = Math.max(currentScale.value + zoomValue, 1); // minimum 1x zoom
    currentScale.value = Math.min(newZoomValue, 3); // maximum 3x zoom

    // get svg center
    const width = sankey_size.value.width;
    const height = sankey_size.value.height;
    const centerX = width / 2;
    const centerY = height / 2;

    // compute transformation
    const transform = d3.zoomIdentity
        .translate(centerX, centerY)
        .scale(currentScale.value)
        .translate(-centerX, -centerY);

    // apply transformation to D3 zoom behavior and zoom group
    svg.transition()
        .duration(300)
        .call(zoom.transform, transform);

    zoomGroup.transition()
        .duration(300)
        .attr("transform", `translate(${transform.x}, ${transform.y}) scale(${transform.k})`);

    isZoomed.value = currentScale.value > 1;
}

/* ******************************************** */
function initializeZoom() {
    if (!svg) return;
    zoomGroup = svg.select('.zoom-group');
    zoom = d3.zoom()
        .scaleExtent([1, 5]) // Max 500% zoom
        .on("zoom", (event) => {
            currentScale.value = event.transform.k;
            isZoomed.value = currentScale.value > 1;
            zoomGroup.attr("transform", event.transform);
        })
        .filter(event => {
            if (event.type === 'dblclick') {
                event.preventDefault();
                return false;
            }
            if (event.type === 'mousedown' && event.button !== 0) {
                return false;
            }

            // don't pan if clicking on a draggable node
            if (event.type === 'mousedown' && event.target.closest('.sankey-node, .label')) {
                return false;
            }

            // disable panning if not zoomed
            if (event.type === 'mousedown' && currentScale.value <= 1) {
                return false;
            }

            return !event.ctrlKey && event.type !== 'dblclick';
        });

    // update cursor style based on zoom
    svg.on('mousedown', (event) => {

        if (event.button === 0 && currentScale.value > 1) { // left click and zoomed
            svg.style("cursor", `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512' width='18px' height='18px'%3E%3Cpath d='M278.6 9.4c-12.5-12.5-32.8-12.5-45.3 0l-64 64c-9.2 9.2-11.9 22.9-6.9 34.9s16.6 19.8 29.6 19.8l32 0 0 96-96 0 0-32c0-12.9-7.8-24.6-19.8-29.6s-25.7-2.2-34.9 6.9l-64 64c-12.5 12.5-12.5 32.8 0 45.3l64 64c9.2 9.2 22.9 11.9 34.9 6.9s19.8-16.6 19.8-29.6l0-32 96 0 0 96-32 0c-12.9 0-24.6 7.8-29.6 19.8s-2.2 25.7 6.9 34.9l64 64c12.5 12.5 32.8 12.5 45.3 0l64-64c9.2-9.2 11.9-22.9 6.9-34.9s-16.6-19.8-29.6-19.8l-32 0 0-96 96 0 0 32c0 12.9 7.8 24.6 19.8 29.6s25.7 2.2 34.9-6.9l64-64c12.5-12.5 12.5-32.8 0-45.3l-64-64c-9.2-9.2-22.9-11.9-34.9-6.9s-19.8 16.6-19.8 29.6l0 32-96 0 0-96 32 0c12.9 0 24.6-7.8 29.6-19.8s2.2-25.7-6.9-34.9l-64-64z'/%3E%3C/svg%3E"), move`);
        } else {
            svg.style("cursor", "default");
        }
    });

    // reset cursor on mouse up
    svg.on('mouseup', () => {
        if (currentScale.value > 1) {
            svg.style("cursor", "grab");
        } else {
            svg.style("cursor", "default");
        }
    });

    // add double click handler to reset zoom
    svg.on('dblclick', (event) => {
        event.preventDefault();
        resetZoom();
    });

    // init zoom
    svg.call(zoom)
        .call(zoom.transform, d3.zoomIdentity);
}

/* ******************************************** */

function resetZoom() {
    if (!zoom) return;
    if (!svg) return; /* Check if the svg is created or not */
    svg.transition()
        .duration(750)
        .call(zoom.transform, d3.zoomIdentity);

    currentScale.value = 1;
    isZoomed.value = false;

    zoomGroup.attr("transform", "translate(0,0) scale(1)");
}

/* ******************************************** */

async function set_sankey_data(reset) {
    if (reset && svg) {
        sankey_wrapper.value.replaceChildren();
    }
    if (props.sankey_data.nodes == null || props.sankey_data.links == null
        || props.sankey_data.length == 0 || props.sankey_data.links.length == 0) {
        setNoDataFlag(true); /* No data */
        return;
    }

    setNoDataFlag(false) /* There is some data */
    await draw_sankey();
    attach_events();
    initializeZoom();
}

/* ******************************************** */
// attach resize event listener
function attach_events() {
    if (eventsAttached) return;
    
    const handleResize = () => {
        clearTimeout(resizeTimeout);
        resizeTimeout = setTimeout(async () => {
            await set_sankey_data(true);
            initializeZoom();
        }, 150);
    };
    
    window.addEventListener('resize', handleResize);
    eventsAttached = true;
}

/* ******************************************** */

function get_size() {
    emit('update_width');
    let width = props.width
    if (width == undefined) { width = $(sankey_div.value).width() }
    
    emit('update_height');
    let height = props.height
    if (height == undefined) { height = $(sankey_div.value).height() }

    return { width, height };
}


/* ******************************************** */
function createNodeDrag(links, svg) {
    return d3.drag()
        .on("start", function(event, d) {
            d3.select(this).select("rect").style("fill-opacity", 1.0);

            // Store initial relative positions ONLY ONCE (on first drag)
            // These offsets should remain constant based on the original layout
            links.forEach(link => {
                if (link.source === d && link.sourceY0Offset === undefined) {
                    // Store the relative offset from the top of the source node
                    link.sourceY0Offset = link.y0 - d.y0;
                }
                if (link.target === d && link.targetY1Offset === undefined) {
                    // Store the relative offset from the top of the target node
                    link.targetY1Offset = link.y1 - d.y0;
                }
            });
        })
        .on("drag", function(event, d) {
            const nodeWidth = d.x1 - d.x0;
            const nodeHeight = d.y1 - d.y0;

            // get current zoom
            const transform = d3.zoomTransform(svg.node());
            const scale = transform.k;

            // get svg dimensions
            const svgRect = svg.node().getBoundingClientRect();
            const margin = { top: 8, right: 8, bottom: 8, left: 8 };

            // calculate visible bounds in the sankey coordinate space
            // The sankey extent is [0, 0] to [width - margins, height - margins]
            const sankeyWidth = sankey_size.value.width - margin.left - margin.right;
            const sankeyHeight = sankey_size.value.height - margin.top - margin.bottom;

            const visibleLeft = Math.max(0, -transform.x / scale);
            const visibleTop = Math.max(0, -transform.y / scale);
            const visibleRight = Math.min(sankeyWidth, visibleLeft + svgRect.width / scale);
            const visibleBottom = Math.min(sankeyHeight, visibleTop + svgRect.height / scale);

            // do not let the node be dragged out of view
            let constrainedX = Math.max(visibleLeft, Math.min(visibleRight - nodeWidth, event.x));
            let constrainedY = Math.max(visibleTop, Math.min(visibleBottom - nodeHeight, event.y));
            
            // update node bounds with constrained positions
            d.x0 = constrainedX;
            d.x1 = constrainedX + nodeWidth;
            d.y0 = constrainedY;
            d.y1 = constrainedY + nodeHeight;
            
            // Move the node group
            d3.select(this).attr("transform", `translate(${d.x0}, ${d.y0})`);

            // update links connected to dragged node, preserving relative positions
            links.forEach(link => {
                if (link.source === d) {
                    // Update source link position preserving relative offset
                    link.y0 = d.y0 + (link.sourceY0Offset !== undefined ? link.sourceY0Offset : 0);
                }
                if (link.target === d) {
                    // Update target link position preserving relative offset
                    link.y1 = d.y0 + (link.targetY1Offset !== undefined ? link.targetY1Offset : 0);
                }
            });
            
            // redraw all links
            svg.select("g.links").selectAll("path.sankey-link")
                .attr("d", sankeyLinkHorizontal());
            
            // update gradients for affected links only
            svg.select("g.links").selectAll("linearGradient")
                .attr("x1", link => link.source.x1)
                .attr("y1", link => link.y0)
                .attr("x2", link => link.target.x0)
                .attr("y2", link => link.y1);
        })
        .on("end", function(event, d) {
            d3.select(this).select("rect").style("fill-opacity", 0.9);
        });
}
/* ******************************************** */
async function draw_sankey() {
    const colors = d3.scaleOrdinal(d3.schemeCategory10);
    let data = props.sankey_data;
    const size = get_size();
    /* Add a margin of 8 px (1 rem) on every side */
    const margin = { top: 8, right: 8, bottom: 8, left: 8 };
    sankey_size.value = size;
    //console.log(`New width: ${sankey_size.value.width} New height: ${sankey_size.value.height}`)

    svg = d3.select(sankey_wrapper.value)
        .append("svg")
        .attr("height", sankey_size.value.height)
        .attr("width", sankey_size.value.width)
        .append("g")
        .attr("transform", `translate(${margin.left},${margin.top})`);

    sankeyRef = sankey()
        .nodeWidth(15)
        .nodePadding(10)
        .extent([[0, 0], [sankey_size.value.width - margin.right - margin.left, sankey_size.value.height - margin.top - margin.bottom]]);

    // Sort nodes descending by value property
    sankeyRef.nodeSort((a, b) => d3.descending(a.value, b.value));

    let links, nodes;
    if (Object.keys(data).length !== 0) {
        sankeyData = sankeyRef(data);
        ({ links, nodes } = sankeyData);
    }

    if (!links || !nodes) return;

    svg.style("cursor", "default");

    const zoomGroup = svg.append("g")
        .attr("class", "zoom-group");

    zoomGroup.append("g")
        .attr("class", "links")
        .style("stroke", "#000")
        .style("stroke-opacity", 0.3)
        .style("fill", "none");

    zoomGroup.append("g")
        .attr("class", "nodes")

    // Helper function to find all nodes in the backward path (left side)
    function findBackwardPath(targetNode, links) {
        const pathNodes = new Set();
        const queue = [targetNode];
        const visited = new Set();

        while (queue.length > 0) {
            const current = queue.shift();
            if (visited.has(current)) continue;
            visited.add(current);
            pathNodes.add(current);

            // Find all links where current node is the target (incoming links)
            const incomingLinks = links.filter(link => link.target === current);

            incomingLinks.forEach(link => {
                const source = link.source;
                // Only nodes to the left
                if (!visited.has(source) && source.x0 < current.x0) {
                    queue.push(source);
                }
            });
        }

        return pathNodes;
    }

    // Helper function to find all nodes in the forward path (right side)
    function findForwardPath(sourceNode, links) {
        const pathNodes = new Set();
        const queue = [sourceNode];
        const visited = new Set();

        while (queue.length > 0) {
            const current = queue.shift();
            if (visited.has(current)) continue;
            visited.add(current);
            pathNodes.add(current);

            // Find all links where current node is the source (outgoing links)
            const outgoingLinks = links.filter(link => link.source === current);

            outgoingLinks.forEach(link => {
                const target = link.target;
                if (!visited.has(target) && target.x0 > current.x0) { // Only nodes to the right
                    queue.push(target);
                }
            });
        }

        return pathNodes;
    }

    // Helper function to find all links in the full path
    function findFullPathLinks(pathNodes, links) {
        const pathLinks = new Set();

        links.forEach(link => {
            if (pathNodes.has(link.source) && pathNodes.has(link.target)) {
                pathLinks.add(link);
            }
        });

        return pathLinks;
    }

    // Reset function to restore original styling
    function resetHighlight() {
        svg.selectAll(".sankey-link")
            .style("stroke-opacity", 0.4)
            .style("stroke", (d) => `url(#gradient-${d.index})`);

        svg.selectAll(".sankey-node")
            .style("fill-opacity", 0.9)
            .style("fill", (d) => colors(d.index % 10)); // Fixed color calculation

        svg.selectAll(".label")
            .style("fill-opacity", 0.85);
    }

    // Highlight function for full path
    function highlightFullPath(hoveredLink) {
        const sourceNode = hoveredLink.source;
        const targetNode = hoveredLink.target;

        // Find all nodes in the backward path (from source to leftmost nodes)
        const backwardNodes = findBackwardPath(sourceNode, links);

        // Find all nodes in the forward path (from target to rightmost nodes)
        const forwardNodes = findForwardPath(targetNode, links);

        // Combine all path nodes
        const allPathNodes = new Set([...backwardNodes, ...forwardNodes]);

        // Find all links in the full path
        const pathLinks = findFullPathLinks(allPathNodes, links);

        // Dim all links first
        svg.selectAll(".sankey-link")
            .style("stroke-opacity", 0.15);

        // Highlight path links with moderate opacity
        svg.selectAll(".sankey-link")
            .filter(d => pathLinks.has(d))
            .style("stroke-opacity", 0.7);

        // Dim all nodes first
        svg.selectAll(".sankey-node")
            .style("fill-opacity", 0.2);

        // Highlight path nodes with high opacity
        svg.selectAll(".sankey-node")
            .filter(d => allPathNodes.has(d))
            .style("fill-opacity", 1.0);

        // Dim all labels first
        svg.selectAll(".label")
            .style("fill-opacity", 0.25);

        // Highlight labels for path nodes
        svg.selectAll(".label")
            .filter(d => allPathNodes.has(d))
            .style("fill-opacity", 1.0);
    }


    const d3_nodes = svg.select("g.nodes")
        .selectAll("g")
        .data(nodes)
        .join((enter) => enter.append("g"))
        .attr("transform", (d) => `translate(${d.x0}, ${d.y0})`)
        .call(createNodeDrag(links, svg));

    d3_nodes.append("rect")
        .attr("height", (d) => Math.max(3, d.y1 - d.y0)) // Ensure minimum height of 3px
        .attr("width", (d) => Math.max(15, d.x1 - d.x0)) // Ensure minimum width of 15px
        .attr("dataIndex", (d) => d.index)
        .attr("fill", (d) => colors(d.index % 10)) // Fixed: use modulo to ensure proper color cycling
        .attr("fill-opacity", 0.9)
        .attr("class", "sankey-node")
        .attr("style", "cursor:move;")
        .style("stroke", "none")


    d3.selectAll("rect").append("title").text((d) => `${d?.label}`);

    d3_nodes.append("text")
        .attr('class', 'label')
        .style('pointer-events', 'auto')
        .attr("style", "cursor:pointer;")
        .style('fill-opacity', 0.85)
        .attr("fill", "#000")
        .attr("x", (d) => (d.x0 < sankey_size.value.width / 2 ? 6 + Math.max(15, d.x1 - d.x0) : -6)) // Adjusted for minimum width
        .attr("y", (d) => Math.max(3, d.y1 - d.y0) / 2) // Adjusted for minimum height
        .attr("alignment-baseline", "middle")
        .attr("text-anchor", (d) => d.x0 < sankey_size.value.width / 2 ? "start" : "end")
        .attr("font-size", 12)
        .text((d) => d.label)
        .on("click", function (event, data_obj) {
            event.stopPropagation();
            // emit node click event to parent component
            emit('node_click', data_obj.data, data_obj);
        });

    // Draw links
    const links_d3 = svg.select("g.links")
        .selectAll("g")
        .data(links)
        .join((enter) => enter.append("g"));

    const lg_d3 = links_d3.append("linearGradient");
    lg_d3.attr("id", (d) => `gradient-${d.index}`)
        .attr("gradientUnits", "userSpaceOnUse")
        .attr("x1", (d) => d.source.x1)
        .attr("x2", (d) => d.target.x0);

    lg_d3.append("stop")
        .attr("offset", "0")
        .attr("stop-color", (d) => colors(d.source.index % 10)); // Fixed color calculation

    lg_d3.append("stop")
        .attr("offset", "100%")
        .attr("stop-color", (d) => colors(d.target.index % 10)); // Fixed color calculation

    links_d3
        .append("path")
        .attr("class", "sankey-link")
        .attr("d", sankeyLinkHorizontal())
        .attr("stroke-width", (d) => Math.max(1, d.width))
        .attr("stroke", (d) => `url(#gradient-${d.index})`)
        .attr("stroke-opacity", 0.4)
        .attr("data-bs-toggle", "tooltip")
        .attr("data-bs-placement", "top")
        .attr("title", (d) => `${d.label}`)
        .text((d) => `${d.label}`)
        .on("mouseover", function (event, d) {
            highlightFullPath(d);
        })
        .on("mouseout", function (event, d) {
            resetHighlight();
        });


    svg.on("mouseleave", function () {
        resetHighlight();
    });
}

defineExpose({ draw_sankey, setNoDataFlag });

</script>

<style scoped>
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

.sankey-wrapper-container {
    display: flex;
    align-items: flex-start;
    gap: 1rem;
}

.btn-group-container {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 1rem;
}

.zoom-controls {
    position: absolute;
    top: 10px;
    right: 10px;
    z-index: 10;
}

.refresh-btn {
    background-color: #6c757d !important;
    color: white !important;
    border: none !important;
    height: 24px;
    display: flex;
    align-items: center;
    padding: 0 8px;
}

.refresh-btn:hover {
    background-color: #5a6268 !important;
}

.refresh-btn.active {
    background-color: #007bff !important;
}

.refresh-btn.active:hover {
    background-color: #0056b3 !important;
}

.sankey-container svg {
    overflow: visible;
}

.sankey-container {
  overflow: hidden;
}
</style>