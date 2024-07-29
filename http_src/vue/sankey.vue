<!-- (C) 2022 - ntop.org     -->
<template>
    <div v-if="no_data" class="alert alert-info" id="empty-message">{{ no_data_message || _i18n('flows_page.no_data') }}
    </div>
    <div>
        <svg ref="sankey_chart_ref" :width="sankey_size.width" :height="sankey_size.height" style="margin:10px;">
            <g class="nodes" style="stroke: #000;strokeOpacity: 0.5;" />
            <g class="links" style="stroke: #000;strokeOpacity: 0.3;fill:none;" />
        </svg>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch } from "vue";

const d3 = d3v7;

const emit = defineEmits(['node_click', 'update_width', 'update_height'])

const margin = {
    top: 2.5,
    right: 5,
    bottom: 2.5,
    left: 5
};

const node_width = 10;
const no_data = ref(false)

const props = defineProps({
    no_data_message: String,
    width: Number,
    height: Number,
    sankey_data: Object,
});

const sankey_chart_ref = ref(null);
const sankey_size = ref({});

onBeforeMount(async () => { });

onMounted(async () => {
    set_sankey_data();
    attach_events();
});

watch(() => props.sankey_data, (cur_value, old_value) => {
    set_sankey_data(true);
});

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
    window.addEventListener('resize', () => set_sankey_data(true));
}

let sankey = null;
let sankeyData = null;
async function draw_sankey() {
    const colors = d3.scaleOrdinal(d3.schemeCategory10);
    let data = props.sankey_data;//await get_sankey_data();
    const size = get_size();
    sankey_size.value = size;
    sankey = create_sankey(size.width - 10, size.height - 5);
    sankeyData = sankey(data);
    const { links, nodes } = sankeyData;
    const Lt = d3.map(links, (d) => `${d.label}`);
    console.log(Lt)

    let d3_nodes = d3.select(sankey_chart_ref.value)
        .select("g.nodes")
        .selectAll("g")
        .data(nodes)
        .join((enter) => enter.append("g"))
        .attr("transform", (d) => `translate(${d.x0}, ${d.y0})`)

    const zoom = d3.zoom()
        .scaleExtent([1, 40])
        .on("zoom", zoomed);

    d3_nodes.append("rect")
        // .transition(d3.easeLinear)
        // .delay(1000)
        // .duration(500)
        .attr("height", (d) => d.y1 - d.y0)
        .attr("width", (d) => d.x1 - d.x0)
        .attr("dataIndex", (d) => d.index)
        .attr("fill", (d) => colors(d.index / nodes.length))
        .attr("class", "sankey-node")
        .attr("style", "cursor:move;");
    d3.selectAll("rect").append("title").text((d) => `${d?.label}`);

    // Relative to container/ node rect    
    d3_nodes.data(nodes)
        .append("text")
        // .transition(d3.easeLinear)
        // .delay(1000)
        // .duration(500)
        .attr('class', 'label')
        .style('pointer-events', 'auto')
        .attr("style", "cursor:pointer;")
        .style('fill-opacity', function (d) { return 1; })
        .attr("fill", (d) => "#000")
        // .attr("fill", (d) => d3.rgb(colors(d.index / nodes.length)).darker())
        .attr("x", (d) => (d.x0 < size.width / 2 ? 6 + (d.x1 - d.x0) : -6))
        .attr("y", (d) => (d.y1 - d.y0) / 2)
        .attr("alignment-baseline", "middle")
        .attr("text-anchor", (d) =>
            d.x0 < size.width / 2 ? "start" : "end"
        )
        .attr("font-size", 12)
        .text((d) => d.label)
        .on("click", function (event, data_obj) { emit('node_click', data_obj.data, data_obj); });
    d3_nodes
        .call(d3.drag().subject(d => d).on("start", dragStart).on("drag", dragMove));

    const links_d3 = d3.select(sankey_chart_ref.value)
        .select("g.links")
        .selectAll("g")
        .data(links)
        .join((enter) => enter.append("g"))

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
        .style('pointer-events', 'none')
        .attr("class", "sankey-link")
        .attr("d", d3.sankeyLinkHorizontal())
        .attr("stroke-width", (d) => {
            return Math.max(1, d.width);
        })
        .attr("stroke", (d) => `url(#gradient-${d.index}`)
        .append("title")
        .attr("data-bs-toggle", "tooltip")
        
    d3.selectAll("linearGradient").append("title").text((d) => `${d.label}`);
}

function dragStart(event, d) {
    d.__x = event.x;
    d.__y = event.y;
    d.__x0 = d.x0;
    d.__y0 = d.y0;
    d.__x1 = d.x1;
    d.__y1 = d.y1;
} //dragStart

function dragMove(event, d) {
    d3.select(this).attr("transform", function (d) {
        const dx = event.x - d.__x;
        const dy = event.y - d.__y;
        const width = sankey_size.value.width;
        const height = sankey_size.value.width;
        d.x0 = d.__x0 + dx;
        d.x1 = d.__x1 + dx;
        d.y0 = d.__y0 + dy;
        d.y1 = d.__y1 + dy;

        if (d.x0 < 0) {
            d.x0 = 0;
            d.x1 = node_width;
        } // if

        if (d.x1 > width) {
            d.x0 = width - node_width;
            d.x1 = width;
        } // if

        if (d.y0 < 0) {
            d.y0 = 0;
            d.y1 = d.__y1 - d.__y0;
        } // if

        if (d.y1 > height) {
            d.y0 = height - (d.__y1 - d.__y0);
            d.y1 = height;
        } // if
        sankey.update(sankeyData);
        d3.selectAll(".sankey-link").attr("d", d3.sankeyLinkHorizontal());
        return `translate(${d.x0}, ${d.y0})`;
    });
}

function zoomed({ transform }) {
    g.attr("transform", transform);
}
function get_size() {
    emit('update_width');
    let width = props.width;
    if (width == undefined) { width = $(sankey_chart_ref.value).parent().parent().width() - 10 }

    emit('update_height');
    let height = props.height
    if (height == undefined) { height = $(sankey_chart_ref.value).parent().parent().height() - 80; }

    return { width, height };
}

function create_sankey(width, height) {
    const _sankey = d3.sankey()
        .nodeAlign(d3.sankeyCenter)
        .nodeWidth(10)
        .nodePadding(node_width)
        .extent([
            [0, 5],
            [width, height]
        ]);
    return _sankey;
}

/* Set to true, to show the 'No Data' message */
function set_no_data_flag(set_no_data) {
    no_data.value = set_no_data
}

const _i18n = (t) => i18n(t);

defineExpose({ draw_sankey, set_no_data_flag });

</script>
