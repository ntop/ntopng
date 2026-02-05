<!--
  (C) 2026 - ntop.org
-->

<template>
    <div ref="chord_div" class="chord-container">
        <Loading :isLoading="loading"></Loading>

        <!-- no data -->
        <div v-if="no_data && !loading" class="alert alert-info" id="empty-message">
            {{ no_data_message || _i18n('flows_page.no_data') }}
        </div>
        <div ref="chord_wrapper" class="chord-wrapper"></div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, onBeforeUnmount, watch, computed } from "vue";
import { default as Loading } from "./loading.vue"

const d3 = d3v7;
const emit = defineEmits(['update_width', 'update_height', 'autorefresh_toggle'])

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
    chord_data: Object
});

const chord_size = ref({});
const no_data = ref(false);
const loading = ref(false);
const chord_wrapper = ref(null);
const chord_div = ref(null);

let svg = null;

// Ribbon = connection between outer arcs
// Outer arc = groups

/* ******************************************** */

onBeforeMount(async () => { });

/* ******************************************** */

onMounted(async () => {
    await set_chord_data();
});

/* ******************************************** */

onBeforeUnmount(() => {
    if (svg) {
        svg.selectAll('*').remove();
        svg.on('dblclick', null);
    }

    if (resizeTimeout) {
        clearTimeout(resizeTimeout);
    }

    window.removeEventListener('resize', handleResize);
    eventsAttached = false;
});

/* ******************************************** */

watch(() => props.chord_data, () => {
    set_chord_data(true);
});

/* ******************************************** */

async function set_chord_data(reset) {
    loading.value = true;

    if (reset && svg) {
        chord_wrapper.value.replaceChildren();
    }

    if (!props.chord_data || !props.chord_data.matrix || props.chord_data.matrix.length == 0) {
        setNoDataFlag(true);
        loading.value = false;
        return;
    }

    setNoDataFlag(false)
    await draw_chord();
    // add resize event
    attach_events();

    loading.value = false;
}

/* ******************************************** */

const handleResize = () => {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(async () => {
        await set_chord_data(true);
        initializeZoom();
    }, 150);
};

function attach_events() {
    if (eventsAttached) return;

    window.addEventListener('resize', handleResize);
    eventsAttached = true;
}

/* ******************************************** */
// get parent size container
function get_size() {
    emit('update_width');
    let width = props.width
    if (width == undefined || width == null) {
        width = $(chord_div.value).width()
    }

    emit('update_height');
    let height = props.height
    if (height == undefined || height == null) {
        height = $(chord_div.value).height()
    }

    // check if valid dimension else fallback to default
    if (!width || isNaN(width)) {
        width = 800;
    }
    if (!height || isNaN(height)) {
        height = 600;
    }

    return { width, height };
}


/* ******************************************** */

async function draw_chord() {
    const data = props.chord_data;
    const size = get_size();
    chord_size.value = size;

    const width = chord_size.value.width;
    const height = chord_size.value.height;

    const { names, matrix, colors } = data;

    // get min between height and width, else default to 600px
    const dimension = Math.max(Math.min(width, height), 600);

    // Formula for chord: https://observablehq.com/@d3/chord-diagram
    // margin of 100 to prevent labels from getting outside the panel
    const outerRadius = dimension * 0.5 - 100;
    const innerRadius = outerRadius - 10;

    // compute total for percentage calculation
    const totalValue = d3.sum(matrix.flat());
    const formatValue = (value) => d3.format(".1~%")(value / totalValue);

    const chord = d3.chord()
        .padAngle(10 / innerRadius)
        .sortSubgroups(d3.descending)
        .sortChords(d3.descending);

    const arc = d3.arc()
        .innerRadius(innerRadius)
        .outerRadius(outerRadius)
        .cornerRadius(4); // round corner

    const ribbon = d3.ribbon()
        .radius(innerRadius - 1)
        .padAngle(1 / innerRadius);

    // use colors from API if provided, else default scheme
    const color = colors && colors.length > 0
        ? d3.scaleOrdinal(colors)
        : d3.scaleOrdinal(d3.schemeSet1);

    // take 100% size and colors
    svg = d3.select(chord_wrapper.value)
        .append("svg")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("viewBox", [-dimension / 2, -dimension / 2, dimension, dimension])
        .attr("style", "font: 10px 'Inter', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;")
        .style("background", "transparent");

    const chords = chord(matrix);

    //  draw svg
    const group = svg.append("g")
        .selectAll()
        .data(chords.groups)
        .join("g");

    group.append("path")
        .attr("class", "chord-group")
        .attr("fill", d => color(names[d.index]))
        .attr("d", arc)
        .attr("fill-opacity", 0.9)
        .style("filter", "drop-shadow(0px 2px 4px rgba(0, 0, 0, 0.15))")
        .style("stroke", d => d3.color(color(names[d.index])).darker(0.5))
        .style("stroke-width", "1px")
        .style("cursor", "pointer")
        .on("click", function (event, d) {
            // on node click go to exporter_interfaces.lua page for the clciked node
            const nodeName = names[d.index];
            console.log(`clicked node: ${nodeName}`)
            window.location.href = `${http_prefix}/lua/pro/enterprise/exporter_interfaces.lua?ip=${encodeURIComponent(nodeName)}`;
        })
        .on("mouseover", function (event, d) {
            d3.select(this)
                .transition()
                .duration(80)
                .attr("fill-opacity", 1.0)
                .style("filter", "drop-shadow(0px 3px 6px rgba(0, 0, 0, 0.25))")
                .style("stroke-width", "1.5px");
        })
        .on("mouseout", function () {
            d3.select(this)
                .transition()
                .duration(80)
                .attr("fill-opacity", 0.9)
                .style("filter", "drop-shadow(0px 2px 4px rgba(0, 0, 0, 0.15))")
                .style("stroke-width", "1px");
        });

    group.append("title")
        .text(d => `${names[d.index]}\n${formatValue(d.value)}`);

    // add labels percentage outer circle
    group.append("g")
        .attr("transform", d => {
            const angle = (d.startAngle + d.endAngle) / 2;
            const rotate = (angle * 180 / Math.PI - 90);
            return `rotate(${rotate}) translate(${outerRadius + 20},0)`;
        })
        .append("text")
        .attr("class", "group-label")
        .attr("font-weight", "600")
        .attr("font-size", "11px")
        .attr("opacity", 0.95)
        .attr("dy", "0.35em")
        .attr("fill", "#1a1a1a")
        .attr("transform", d => {
            const angle = (d.startAngle + d.endAngle) / 2;
            return angle > Math.PI ? "rotate(180)" : null;
        })
        .attr("text-anchor", d => {
            const angle = (d.startAngle + d.endAngle) / 2;
            return angle > Math.PI ? "end" : "start";
        })
        .style("letter-spacing", "0.3px")
        .text(d => names[d.index]);

    // reset to original style 
    function resetHighlight() {
        svg.selectAll(".chord-ribbon")
            .transition()
            .duration(90)
            .attr("fill-opacity", 0.65);

        svg.selectAll(".chord-group")
            .transition()
            .duration(90)
            .attr("fill-opacity", 0.9);

        svg.selectAll(".group-label")
            .transition()
            .duration(90)
            .attr("opacity", 0.95);

        svg.selectAll(".ribbon-label")
            .transition()
            .duration(90)
            .attr("opacity", 0.95);
    }

    // highlihgt ribbon
    function highlightRibbon(hoveredChord) {
        // dim all ribbons
        svg.selectAll(".chord-ribbon")
            .transition()
            .duration(90)
            .attr("fill-opacity", 0.08);

        // highlight hovered ribbon
        svg.selectAll(".chord-ribbon")
            .filter(d => d === hoveredChord)
            .transition()
            .duration(90)
            .attr("fill-opacity", 0.95);

        // dim all groups
        svg.selectAll(".chord-group")
            .transition()
            .duration(90)
            .attr("fill-opacity", 0.25);

        // highlight source and target group
        svg.selectAll(".chord-group")
            .filter(d => d.index === hoveredChord.source.index || d.index === hoveredChord.target.index)
            .transition()
            .duration(90)
            .attr("fill-opacity", 0.95);

        // dim all labels
        svg.selectAll(".group-label")
            .transition()
            .duration(90)
            .attr("opacity", 0.25);

        // highlight source and target labels
        svg.selectAll(".group-label")
            .filter(d => d.index === hoveredChord.source.index || d.index === hoveredChord.target.index)
            .transition()
            .duration(90)
            .attr("opacity", 1.0);

        // dim all ribbon labels
        svg.selectAll(".ribbon-label")
            .transition()
            .duration(90)
            .attr("opacity", 0.15);

        // highlight the hovered ribbon labels
        svg.selectAll(".ribbon-label")
            .filter(d => d === hoveredChord)
            .transition()
            .duration(90)
            .attr("opacity", 1.0);
    }

    // draw ribbon with hover
    const ribbonGroup = svg.append("g")
        .attr("fill-opacity", 0.8);

    ribbonGroup.selectAll("path")
        .data(chords)
        .join("path")
        .attr("class", "chord-ribbon")
        .style("mix-blend-mode", "multiply")
        .attr("fill", d => {
            // create gradient from src to target
            const sourceColor = d3.color(color(names[d.source.index]));
            return sourceColor;
        })
        .attr("d", ribbon)
        .attr("fill-opacity", 0.65)
        .style("stroke", d => d3.color(color(names[d.source.index])).darker(0.3))
        .style("stroke-width", "0.5px")
        .style("cursor", "pointer")
        .on("mouseover", function (event, d) {
            // smooth transition for hovered ribbon
            d3.select(this)
                .transition()
                .duration(90)
                .style("stroke-width", "1.5px")
                .attr("fill-opacity", 0.9);

            highlightRibbon(d);
        })
        .on("mouseout", function () {
            // smooth transition to normal highlight
            d3.select(this)
                .transition()
                .duration(90)
                .style("stroke-width", "0.5px")
                .attr("fill-opacity", 0.65);

            resetHighlight();
        });

    // add percentage label
    ribbonGroup.selectAll("text")
        .data(chords)
        .join("text")
        .attr("class", "ribbon-label")
        .style("cursor", "pointer")
        .on("mouseover", function (event, d) {
            // highlight ribbon when hovering
            highlightRibbon(d);

            ribbonGroup.selectAll("path")
                .filter(chord => chord === d)
                .transition()
                .duration(90)
                .style("stroke-width", "1.5px")
                .attr("fill-opacity", 0.9);
        })
        .on("mouseout", function (event, d) {
            resetHighlight();

            ribbonGroup.selectAll("path")
                .filter(chord => chord === d)
                .transition()
                .duration(90)
                .style("stroke-width", "0.5px")
                .attr("fill-opacity", 0.65);
        })
        .each(function (d) {
            const elem = d3.select(this);

            // compute percentage relative to source total
            const sourcePercent = d3.format(".1~%")(d.source.value / chords.groups[d.source.index].value);
            // compute percentage relative to target total
            const targetPercent = d3.format(".1~%")(d.target.value / chords.groups[d.target.index].value);

            // position at source arc center
            const sourceAngle = (d.source.startAngle + d.source.endAngle) / 2;
            const sourceLabelRadius = outerRadius + 25;
            const sourceX = sourceLabelRadius * Math.cos(sourceAngle - Math.PI / 2);
            const sourceY = sourceLabelRadius * Math.sin(sourceAngle - Math.PI / 2);

            // position at target arc center
            const targetAngle = (d.target.startAngle + d.target.endAngle) / 2;
            const targetLabelRadius = outerRadius + 25;
            const targetX = targetLabelRadius * Math.cos(targetAngle - Math.PI / 2);
            const targetY = targetLabelRadius * Math.sin(targetAngle - Math.PI / 2);

            // add source label
            elem.append("tspan")
                .attr("x", sourceX)
                .attr("y", sourceY)
                .attr("dy", "0.35em")
                .attr("text-anchor", "middle")
                .attr("font-size", "11px")
                .attr("font-weight", "700")
                .attr("fill", d3.color(color(names[d.source.index])).darker(1.5))
                .attr("opacity", 0.95)
                .style("paint-order", "stroke")
                .style("stroke", "rgba(255, 255, 255, 0.95)")
                .style("stroke-width", "3px")
                .text(sourcePercent);

            // add target label
            if (d.source.index !== d.target.index) {
                elem.append("tspan")
                    .attr("x", targetX)
                    .attr("y", targetY)
                    .attr("dy", "0.35em")
                    .attr("text-anchor", "middle")
                    .attr("font-size", "11px")
                    .attr("font-weight", "700")
                    .attr("fill", d3.color(color(names[d.target.index])).darker(1.5))
                    .attr("opacity", 0.95)
                    .style("paint-order", "stroke")
                    .style("stroke", "rgba(255, 255, 255, 0.95)")
                    .style("stroke-width", "3px")
                    .text(targetPercent);
            }
        });

    // reset highlight when leaving svg
    svg.on("mouseleave", function () {
        resetHighlight();
    });
}

defineExpose({ draw_chord, setNoDataFlag });

</script>

<style scoped>
.chord-container {
    width: 100%;
    height: 100%;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #fafbfc 0%, #f5f7fa 100%);
}

.chord-wrapper {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
}

.alert {
    margin: 20px;
    padding: 15px;
    border-radius: 6px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.alert-info {
    background-color: #f8f9fa;
    border: 1px solid #dee2e6;
    color: #0c5460;
}

:deep(.chord-ribbon) {
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
}

:deep(.chord-group) {
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
}

:deep(.group-label) {
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
    font-family: 'Inter', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
}

:deep(.ribbon-label) {
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
    font-family: 'Inter', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
}
</style>
