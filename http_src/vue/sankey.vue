<template>
    <div v-if="no_data" class="alert alert-info" id="empty-message">
        {{ no_data_message || _i18n('flows_page.no_data') }}
    </div>

    <div class="sankey-visualization">
        <div class="zoom-controls-container mb-3">
            <div class="zoom-controls bg-light p-2 rounded shadow-sm">
                <div class="d-flex align-items-center gap-2">
                    <!-- zoom value -->
                    <div class="d-flex align-items-center gap-2">
                        <span class="fw-bold">Zoom</span>
                        <span class="badge zoom-badge px-2 py-1">{{ Math.round(currentScale * 100) }}%</span>
                    </div>
                    <div class="btn-group btn-group-sm" role="group" aria-label="Zoom controls">
                        <!-- Zoom In -->
                        <button type="button" class="btn zoom-btn" @click="zoomChart(0.5)">
                            <i class="fa-solid fa-magnifying-glass-plus"></i>
                        </button>
                        <!-- Zoom Out -->
                        <button type="button" class="btn zoom-btn" @click="zoomChart(-0.5)">
                            <i class="fa-solid fa-magnifying-glass-minus"></i>
                        </button>
                    </div>
                    <!-- Reset Zoom -->
                    <div class="text-muted small d-flex align-items-center gap-1">
                        <i class="bi bi-mouse2"></i>
                        <span>Double-click to reset</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Sankey Diagram -->
        <svg ref="sankey_chart_ref" :width="sankey_size.width" :height="sankey_size.height" class="sankey-svg"
            v-bind:style="{ cursor: cursorIcon }">
            <g class="zoom-group">
                <g class="nodes" style="stroke: #000;strokeOpacity: 0.5;" />
                <g class="links" style="stroke: #000;strokeOpacity: 0.3;fill:none;" />
            </g>
        </svg>
    </div>
</template>


<script setup>
import { ref, onMounted, onBeforeMount, onBeforeUnmount, watch } from "vue";
const d3 = d3v7;
const emit = defineEmits(['node_click', 'update_width', 'update_height'])
const _i18n = (t) => i18n(t);

function set_no_data_flag(set_no_data) {
    no_data.value = set_no_data
}

const props = defineProps({
    no_data_message: String,
    width: Number,
    height: Number,
    sankey_data: Object,
});

// Zoom cursor icon
let cursorIcon = ref(`url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512' width='18px' height='18px'%3E%3Cpath d='M416 208c0 45.9-14.9 88.3-40 122.7L502.6 457.4c12.5 12.5 12.5 32.8 0 45.3s-32.8 12.5-45.3 0L330.7 376c-34.4 25.2-76.8 40-122.7 40C93.1 416 0 322.9 0 208S93.1 0 208 0S416 93.1 416 208zM184 296c0 13.3 10.7 24 24 24s24-10.7 24-24l0-64 64 0c13.3 0 24-10.7 24-24s-10.7-24-24-24l-64 0 0-64c0-13.3-10.7-24-24-24s-24 10.7-24 24l0 64-64 0c-13.3 0-24 10.7-24 24s10.7 24 24 24l64 0 0 64z'/%3E%3C/svg%3E"), pointer`);
const sankey_chart_ref = ref(null);
const sankey_size = ref({});
const no_data = ref(false)

let zoomGroup = null;
let sankey = null;
let sankeyData = null;
let isZoomed = ref(false);
const currentScale = ref(1); // keep track of zzom

let zoom = null;

onBeforeMount(async () => { });

onMounted(async () => {
    set_sankey_data();
    attach_events();
    initializeZoom();
});

onBeforeUnmount(() => {
    const svg = d3.select(sankey_chart_ref.value);
    if (svg) {
        svg.on('dblclick', null);
        svg.on('mousemove', null);
    }
});

watch(() => props.sankey_data, (cur_value, old_value) => {
    set_sankey_data(true);
});

/* ZOOM FUNCTIONS */

// zoomValue must be float, 1.0 is 100% zoom, 1.5 is 150% and so on
function zoomChart(zoomValue) {
    if (!zoom) return;
    const svg = d3.select(sankey_chart_ref.value);
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

function initializeZoom() {
    const svg = d3.select(sankey_chart_ref.value);
    zoomGroup = svg.select('.zoom-group');

    zoom = d3.zoom()
        .scaleExtent([1, 3]) // Max 300% zoom
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
            return !event.ctrlKey && event.type !== 'dblclick';
        });

    // change cursor to move icon if left button is pressed
    svg.on('mousedown', (event) => {
        console.log("Mousedown" + event);
        if (event.button === 0) { // left click
            cursorIcon.value = `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512' width='18px' height='18px'%3E%3Cpath d='M278.6 9.4c-12.5-12.5-32.8-12.5-45.3 0l-64 64c-9.2 9.2-11.9 22.9-6.9 34.9s16.6 19.8 29.6 19.8l32 0 0 96-96 0 0-32c0-12.9-7.8-24.6-19.8-29.6s-25.7-2.2-34.9 6.9l-64 64c-12.5 12.5-12.5 32.8 0 45.3l64 64c9.2 9.2 22.9 11.9 34.9 6.9s19.8-16.6 19.8-29.6l0-32 96 0 0 96-32 0c-12.9 0-24.6 7.8-29.6 19.8s-2.2 25.7 6.9 34.9l64 64c12.5 12.5 32.8 12.5 45.3 0l64-64c9.2-9.2 11.9-22.9 6.9-34.9s-16.6-19.8-29.6-19.8l-32 0 0-96 96 0 0 32c0 12.9 7.8 24.6 19.8 29.6s25.7 2.2 34.9-6.9l64-64c12.5-12.5 12.5-32.8 0-45.3l-64-64c-9.2-9.2-22.9-11.9-34.9-6.9s-19.8 16.6-19.8 29.6l0 32-96 0 0-96 32 0c12.9 0 24.6-7.8 29.6-19.8s2.2-25.7-6.9-34.9l-64-64z'/%3E%3C/svg%3E"), move`;
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

function resetZoom() {
    if (!zoom) return;

    const svg = d3.select(sankey_chart_ref.value);

    svg.transition()
        .duration(750)
        .call(zoom.transform, d3.zoomIdentity);

    currentScale.value = 1;
    isZoomed.value = false;

    zoomGroup.attr("transform", "translate(0,0) scale(1)");
}

/********************************************************************************/

function set_sankey_data(reset) {
    if (reset) {
        $(".nodes", sankey_chart_ref.value).empty();
        $(".links", sankey_chart_ref.value).empty();
    }
    if (props.sankey_data.nodes == null || props.sankey_data.links == null
        || props.sankey_data.length == 0 || props.sankey_data.links.length == 0) {
        return;
    }
    draw_sankey();
}

function attach_events() {
    window.addEventListener('resize', () => {
        set_sankey_data(true);
        initializeZoom();
    });
}


async function draw_sankey() {
    const colors = d3.scaleOrdinal(d3.schemeCategory10);
    let data = props.sankey_data;
    const size = get_size();
    sankey_size.value = size;
    sankey = create_sankey(size.width - 10, size.height - 5);

    sankeyData = sankey(data);
    const { links, nodes } = sankeyData;

    const nodes1 = sankeyData.nodes.map((node, index) => {
        // Calculate vertical spacing
        console.log(size)
        const totalHeight = size.height - 40; // Leave some padding
        const spacing = totalHeight / (sankeyData.nodes.length + 1);

        // Force new y coordinates
        const y0 = spacing * (index + 1);
        const y1 = y0 + (spacing * 0.8); // Make height 80% of spacing
        let res = {
            ...node,
            x0: node.x0,
            x1: node.x1,
            y0: y0,
            y1: y1,
            label: node.label
        };

        console.log(totalHeight, spacing, index)

        return res;
    });

    // Verify the fix worked
    console.log('Fixed nodes:', nodes1.map(n => ({
        label: n.label,
        x0: n.x0,
        y0: n.y0,
        x1: n.x1,
        y1: n.y1,
        isY0NaN: Number.isNaN(n.y0),
        isY1NaN: Number.isNaN(n.y1)
    })));


    let d3_nodes = d3.select(sankey_chart_ref.value)
        .select("g.nodes")
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
    const links_d3 = d3.select(sankey_chart_ref.value)
        .select("g.links")
        .selectAll("g")
        .data(links)
        .join((enter) => enter.append("g"));

    let lg_d3 = links_d3.append("linearGradient");
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


function get_size() {
    emit('update_width');
    let width = props.width
    if (width == undefined) { width = $(sankey_chart_ref.value).parent().parent().width() * 0.95; }

    emit('update_height');
    let height = props.height
    if (height == undefined) { height = $(sankey_chart_ref.value).parent().parent().height() * 0.75; }

    return { width, height };
}

function create_sankey(width, height) {
    return d3.sankey()
        .nodeWidth(15)
        .nodePadding(10)
        .extent([[0, 0], [width, height]])
        .nodeAlign(d3.sankeyJustify);
}

defineExpose({ draw_sankey, set_no_data_flag });

</script>

<style scoped>
.sankey-visualization {
    position: relative;
}

.zoom-controls-container {
    display: flex;
    justify-content: flex-end;
}

.zoom-controls {
    width: 300px;
}

.sankey-svg {
    margin: 10px;
}

.zoom-badge {
    background-color: #fd7e14 !important;
    height: 24px;
    display: flex;
    align-items: center;
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

.btn-group-sm {
    height: 24px;
}

.progress-bar {
    width: 20ch;
    transition: width 0.01s ease-in-out;
    background-color: #fd7e14 !important;
}
</style>