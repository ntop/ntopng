<template>
    <div ref="sankey_div" class="d-flex flex-column flex-grow-1 position-relative">
        <!-- Zoom button group -->
        <div class="mb-2">
            <div class="btn-group btn-ontop" role="group">
                <button type="button" class="btn zoom-btn" @click="zoomChart(0.5)">
                    <i class="fa-solid fa-magnifying-glass-plus"></i>
                </button>
                <button type="button" class="btn zoom-btn" @click="zoomChart(-0.5)">
                    <i class="fa-solid fa-magnifying-glass-minus"></i>
                </button>
                <button v-if="showAutoRefresh" button type="button" class="btn refresh-btn" @click="toggleAutoRefresh"
                    :class="{ 'active': autoRefreshEnabled }"
                    :title="autoRefreshEnabled ? 'Auto-refresh enabled' : 'Auto-refresh disabled'">
                    <i class="fa-solid fa-arrows-rotate"></i>
                </button>
            </div>
        </div>

        <!-- no data -->
        <div v-if="no_data" class="alert alert-info" id="empty-message">
            {{ no_data_message || _i18n('flows_page.no_data') }}
        </div>
        <div ref="sankey_wrapper"></div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, onBeforeUnmount, watch, computed } from "vue";

const d3 = d3v7;
const emit = defineEmits(['node_click', 'update_width', 'update_height', 'autorefresh_toggle'])
const _i18n = (t) => i18n(t);

function set_no_data_flag(set_no_data) {
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
let sankey = null;
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
    await draw_sankey();
});

/* ******************************************** */

onBeforeUnmount(() => {
    if (svg) {
        svg.on('dblclick', null);
        svg.on('mousemove', null);
    }
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

            // disable panning if not zoomed
            if (event.type === 'mousedown' && currentScale.value <= 1) {
                return false;
            }

            return !event.ctrlKey && event.type !== 'dblclick';
        });

    // update cursor style based on zoom
    svg.on('mousedown', (event) => {
        console.log("Mousedown" + event);
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
        return;
    }
    await draw_sankey();
    attach_events();
    initializeZoom();
}

/* ******************************************** */

function attach_events() {
    window.addEventListener('resize', async () => {
        set_sankey_data(true);
        initializeZoom();
    });
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

function create_sankey(width, height) {
    return d3.sankey()
        .nodeWidth(15)
        .nodePadding(10)
        .extent([[0, 0], [width, height]])
        .nodeAlign(d3.sankeyJustify);
}

/* ******************************************** */

async function draw_sankey() {
    const colors = d3.scaleOrdinal(d3.schemeCategory10);
    let data = props.sankey_data;
    const size = get_size();
    sankey_size.value = size;

    sankey = d3.sankey()
        .nodeWidth(15)
        .nodePadding(10)
        .extent([[0, 0], [size.width, size.height]]);

    // Sort nodes descending by value property
    sankey.nodeSort((a, b) => d3.descending(a.value, b.value));

    let links, nodes;
    if (Object.keys(data).length !== 0) {
        sankeyData = sankey(data);
        ({ links, nodes } = sankeyData);
    }

    svg = d3.select(sankey_wrapper.value)
        .append("svg")
        .attr("height", size.height)
        .attr("width", size.width)

    if (!links || !nodes) return;

    svg.style("cursor", "move");

    const zoomGroup = svg.append("g")
        .attr("class", "zoom-group");

    zoomGroup.append("g")
        .attr("class", "nodes")
        .style("stroke", "#000")
        .style("stroke-opacity", 0.5);

    zoomGroup.append("g")
        .attr("class", "links")
        .style("stroke", "#000")
        .style("stroke-opacity", 0.3)
        .style("fill", "none");

    const d3_nodes = svg.select("g.nodes")
        .selectAll("g")
        .data(nodes)
        .join((enter) => enter.append("g"))
        .attr("transform", (d) => `translate(${d.x0}, ${d.y0})`);

    d3_nodes.append("rect")
        .attr("height", (d) => d.y1 - d.y0)
        .attr("width", (d) => d.x1 - d.x0)
        .attr("dataIndex", (d) => d.index)
        .attr("fill", (d) => colors(d.index / nodes.length))
        .attr("class", "sankey-node")
        .attr("style", "cursor:move;");

    d3.selectAll("rect").append("title").text((d) => `${d?.label}`);

    d3_nodes.data(nodes)
        .append("text")
        .attr('class', 'label')
        .style('pointer-events', 'auto')
        .attr("style", "cursor:pointer;")
        .style('fill-opacity', 1)
        .attr("fill", "#000")
        .attr("x", (d) => (d.x0 < size.width / 2 ? 6 + (d.x1 - d.x0) : -6))
        .attr("y", (d) => (d.y1 - d.y0) / 2)
        .attr("alignment-baseline", "middle")
        .attr("text-anchor", (d) => d.x0 < size.width / 2 ? "start" : "end")
        .attr("font-size", 12)
        .text((d) => d.label)
        .on("click", function (event, data_obj) {
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
        .attr("stop-color", (d) => colors(d.source.index / nodes.length));

    lg_d3.append("stop")
        .attr("offset", "100%")
        .attr("stop-color", (d) => colors(d.target.index / nodes.length));

    links_d3
        .append("path")
        .attr("class", "sankey-link")
        .attr("d", d3.sankeyLinkHorizontal())
        .attr("stroke-width", (d) => Math.max(1, d.width))
        .attr("stroke", (d) => `url(#gradient-${d.index}`)
        .attr("data-bs-toggle", "tooltip")
        .attr("data-bs-placement", "top")
        .attr("title", (d) => `${d.label}`)
        .text((d) => `${d.label}`);

}

defineExpose({ draw_sankey, set_no_data_flag });

</script>

<style scoped>
.btn-ontop {
    position: absolute;
    right: 0;
    top: 0;
    z-index: 10;
}

.alert {
    margin: 20px;
    padding: 15px;
    border-radius: 4px;
}

.alert-info {
    background-color: #f8f9fa;
    border: 1px solid #dee2e6;
    color: #0c5460;
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

/* Refresh button style, green if autorefresh enabled, grey otherwise */
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
    background-color: #28a745 !important;
}

.refresh-btn.active:hover {
    background-color: #218838 !important;
}
</style>