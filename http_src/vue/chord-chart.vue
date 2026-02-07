<!--
  (C) 2026 - ntop.org
-->

<template>
    <div ref="chord_div" class="chord-container">
        <Loading :isLoading="loading"></Loading>

        <!-- no data -->
        <div v-if="no_data && !loading" class="alert alert-info no-data-message" id="empty-message">
            {{ no_data_message || _i18n('flows_page.no_data') }}
        </div>
        <div ref="chord_wrapper" class="chord-wrapper"></div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, onBeforeUnmount, watch, computed } from "vue";
import { default as Loading } from "./loading.vue"
import colorUtils from "../utilities/color-utils.js";

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

    const { names, matrix } = data;

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

    // Use color utility to assign consistent colors based on node names
    const nodeColors = colorUtils.assignChordColors(names);
    const color = d3.scaleOrdinal(nodeColors);

    // take 100% size and colors
    svg = d3.select(chord_wrapper.value)
        .append("svg")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("viewBox", [-dimension / 2, -dimension / 2, dimension, dimension])
        .attr("style", "font: 10px 'Inter', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;")
        .style("background", "transparent");

    const chords = chord(matrix);

    // Detect theme for styling
    const isDarkMode = document.documentElement.getAttribute('data-theme') === 'dark';

    //  draw svg
    const group = svg.append("g")
        .selectAll()
        .data(chords.groups)
        .join("g");

    group.append("path")
        .attr("class", "chord-group")
        .attr("fill", d => {
            const baseColor = color(d.index);
            // Brighten colors slightly in dark mode for better visibility
            return isDarkMode ? d3.color(baseColor).brighter(0.3) : baseColor;
        })
        .attr("d", arc)
        .attr("fill-opacity", isDarkMode ? 0.95 : 0.9)
        .style("filter", isDarkMode ?
            "drop-shadow(0px 2px 6px rgba(0, 0, 0, 0.4))" :
            "drop-shadow(0px 2px 4px rgba(0, 0, 0, 0.15))")
        .style("stroke", d => {
            const fillColor = color(d.index);
            return isDarkMode ?
                d3.color(fillColor).brighter(0.5) :
                d3.color(fillColor).darker(0.5);
        })
        .style("stroke-width", "1px")
        .style("cursor", "pointer")
        .on("click", function (event, d) {
            // on node click redirect to URL
            const nodeData = names[d.index];
            const nodeUrl = nodeData.url;
            window.location.href = nodeUrl;
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
        .attr("font-size", "14px")
        .attr("opacity", 0.95)
        .attr("dy", "0.35em")
        .attr("fill", isDarkMode ? "#e2e2e2" : "#1a1a1a")
        .attr("transform", d => {
            const angle = (d.startAngle + d.endAngle) / 2;
            return angle > Math.PI ? "rotate(180)" : null;
        })
        .attr("text-anchor", d => {
            const angle = (d.startAngle + d.endAngle) / 2;
            return angle > Math.PI ? "end" : "start";
        })
        .style("letter-spacing", "0.3px")
        .style("text-shadow", isDarkMode ? "0 1px 3px rgba(0, 0, 0, 0.8)" : "none")
        .text(d => names[d.index].name || names[d.index]);

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
    }

    // highlight ribbon
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
    }

    // draw ribbon with hover
    const ribbonGroup = svg.append("g")
        .attr("fill-opacity", 0.8);

    // Tooltip for ribbons
    let tooltip = null;

    ribbonGroup.selectAll("path")
        .data(chords)
        .join("path")
        .attr("class", "chord-ribbon")
        .style("mix-blend-mode", isDarkMode ? "normal" : "multiply")
        .attr("fill", d => {
            // Use source color for ribbon
            const sourceColor = color(d.source.index);
            return d3.color(sourceColor);
        })
        .attr("d", ribbon)
        .attr("fill-opacity", isDarkMode ? 0.75 : 0.65)
        .style("stroke", d => {
            const sourceColor = color(d.source.index);
            return isDarkMode ? d3.color(sourceColor).brighter(0.3) : d3.color(sourceColor).darker(0.3);
        })
        .style("stroke-width", isDarkMode ? "1px" : "0.5px")
        .style("cursor", "pointer")
        .on("mouseover", function (event, d) {
            // smooth transition for hovered ribbon
            d3.select(this)
                .transition()
                .duration(90)
                .style("stroke-width", "1.5px")
                .attr("fill-opacity", 0.9);

            highlightRibbon(d);

            // Remove existing tooltip
            if (tooltip) tooltip.remove();

            const sourceName = names[d.source.index].name || names[d.source.index];
            const targetName = names[d.target.index].name || names[d.target.index];
            const sourceToTargetPercent = d3.format(".1~%")(d.source.value / chords.groups[d.source.index].value);
            const targetToSourcePercent = d3.format(".1~%")(d.target.value / chords.groups[d.target.index].value);

            // Create tooltip using theme-aware class
            tooltip = d3.select("body")
                .append("div")
                .attr("class", "chord-ribbon-tooltip")
                .html(`${sourceName} -> ${targetName}: ${sourceToTargetPercent} of ${sourceName}'s traffic<br/>${targetName} -> ${sourceName}: ${targetToSourcePercent} of ${targetName}'s traffic`)
                .style("left", (event.pageX + 10) + "px")
                .style("top", (event.pageY - 10) + "px")
                .style("opacity", 0);

            // Fade in
            tooltip.transition().duration(150).style("opacity", 1);
        })
        .on("mousemove", function(event) {
            if (tooltip) {
                tooltip
                    .style("left", (event.pageX + 10) + "px")
                    .style("top", (event.pageY - 10) + "px");
            }
        })
        .on("mouseout", function () {
            // smooth transition to normal highlight
            d3.select(this)
                .transition()
                .duration(90)
                .style("stroke-width", "0.5px")
                .attr("fill-opacity", 0.65);

            resetHighlight();

            // Remove tooltip
            if (tooltip) {
                tooltip.transition().duration(150).style("opacity", 0).remove();
                tooltip = null;
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
/* Light mode */
:root[data-theme='light'] .chord-container {
    background: linear-gradient(135deg, #fafbfc 0%, #f5f7fa 100%);
}

/* Dark mode */
:root[data-theme='dark'] .chord-container {
    background: linear-gradient(135deg, #1a1d23 0%, #0d1117 100%);
}

.chord-container {
    width: 100%;
    height: 100%;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
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

/* Light mode alert */
:root[data-theme='light'] .alert-info {
    background-color: #f8f9fa;
    border: 1px solid #dee2e6;
    color: #0c5460;
}

/* Dark mode alert */
:root[data-theme='dark'] .alert-info {
    background-color: #1e2936;
    border: 1px solid #2d3748;
    color: #9ca3af;
}

.no-data-message {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    margin: 0;
    text-align: center;
    min-width: 200px;
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
</style>

<style>
/* Chord ribbon tooltip - Light mode */
:root[data-theme='light'] .chord-ribbon-tooltip {
    position: absolute;
    background-color: rgba(0, 0, 0, 0.85);
    color: white;
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    pointer-events: none;
    z-index: 10000;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    font-family: 'Inter', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
}

/* Chord ribbon tooltip - Dark mode */
:root[data-theme='dark'] .chord-ribbon-tooltip {
    position: absolute;
    background-color: #2D3748;
    color: var(--ntop-text-color);
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    pointer-events: none;
    z-index: 10000;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.1);
    font-family: 'Inter', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
}
</style>
