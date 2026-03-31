<template>
    <div class="d-flex flex-column flex-grow-1 position-relative" ref="chartParent">
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>
        <div v-if="chart_data_available" :id="id" class="d3-chart-container" ref="chartContainer">
            <h3 v-if="i18n_title">{{ _i18n(i18n_title) }}</h3>
        </div>
        <div v-else
            style="position: relative; display: flex; flex-direction: column; justify-content: center; align-items: center; width: 100%; height: 100%; min-height: 250px; padding: 5% 20px; color: #666;">
            <div style="font-size: clamp(16px, 2vw, 18px); margin-bottom: 2vh;"><i class="fas fa-search"></i>
                {{ _i18n("dashboard.no_assets_discovered") }}</div>
            <div style="font-size: clamp(14px, 1.5vw, 16px);"> {{ _i18n("dashboard.waiting_assets_discovery") }} </div>
        </div>
    </div>
</template>

<script setup>

import { ref, onMounted, onBeforeUnmount, watch, computed, nextTick } from "vue";
const d3 = d3v7;
import dataUtils from "../utilities/data-utils";
import Loading from "./loading.vue";

const _i18n = (t) => i18n(t);

const chart_data_available = ref(true);
const chartContainer = ref(null);
const chartParent = ref(null);
const url_list = ref(null);
const chartData = ref(null);
let resizeObserver = null;
const maxPieSectors = 5;
const isLoading = ref(true);
const firstLoading = ref(true);

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Height (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    filters: Object,
    hideLoading: Boolean, /* If false, no Loading animation is shown */
    showOnlyFirstLoading: Boolean, /* If true, shows only the first loading of the component, not the updates */
});

const base_url = computed(() => {
    return `${http_prefix}${props.params.url}`;
});

const get_url_params = () => {
    const url_params = {
        ifid: props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
        new_charts: true,
        ...props.params.url_params,
        ...props.filters
    }
    return url_params;
}

async function get_chart_data() {
    const url = base_url.value;
    const url_params = get_url_params();
    const options = props.get_component_data(url, url_params, undefined, props.epoch_begin);

    return Promise.resolve(options).then(response => {
        url_list.value = response.urls || [];
        return response;
    });
}

function drawChart(data) {
    const container = chartContainer.value;

    // Check that container exists before proceeding
    if (!container) {
        chart_data_available.value = false;
        return;
    }

    if (!data || !data.series || !data.labels || data.series.length === 0) {
        chart_data_available.value = false;
        return;
    }

    // Clear previous content
    container.innerHTML = '';

    // get container dimension
    const containerWidth = Math.max(container.offsetWidth || 300, 300);
    const containerHeight = Math.max(container.offsetHeight || 300, 300);

    // make space for title, chart and legend
    const titleHeight = container.querySelector('h3') ?
        container.querySelector('h3').offsetHeight : 0;

    // Legend space is 20% of height
    const legendHeight = containerHeight * 0.2;
    const chartHeight = containerHeight - titleHeight - legendHeight;

    // margins
    const margin = {
        top: 5,
        right: 5,
        bottom: 5,
        left: 5
    };

    // chart dimensions
    const width = containerWidth - margin.left - margin.right;
    const height = chartHeight - margin.top - margin.bottom;

    // chart radius
    const radius = Math.min(width, height) / 2 * 0.9;

    // Pie chart
    const svg = d3.select(container)
        .append("svg")
        .attr("width", "100%")
        .attr("height", `${chartHeight}px`)
        .attr("viewBox", `0 0 ${containerWidth} ${chartHeight}`)
        .append("g")
        .attr("class", "chart-group")
        .attr("transform", `translate(${width / 2 + margin.left}, ${height / 2 + margin.top})`);

    const sanitizedSeries = data.series.map(val => {
        const numVal = Number(val);
        return isNaN(numVal) ? 0 : numVal;
    });

    // Process data
    const chartPairs = data.labels.map((label, i) => ({
        label: label || "Unnamed",
        value: sanitizedSeries[i] || 0,
        color: (data.colors && data.colors[i]) || d3.schemeCategory10[i % 10],
        url: (url_list.value && url_list.value[i]) || ''
    }));

    // show first maxPieSectors sectors, group the remaining in others
    const topItems = [...chartPairs].slice(0, maxPieSectors);
    const otherItems = [...chartPairs].slice(maxPieSectors);

    const othersSum = otherItems.reduce((sum, item) => sum + item.value, 0);

    let finalChartItems = [...topItems];

    // add others to the chart if there is at least an element
    if (otherItems.length > 0 && othersSum > 0) {
        finalChartItems.push({
            label: `Others (${othersSum})`, // othersSum is the total of devices count
            value: othersSum,
            color: "#999999", // gray for others
            url: ''
        });
    }

    if (finalChartItems.length === 0 || finalChartItems.every(item => item.value <= 0)) {
        chart_data_available.value = false;
        return;
    }

    // if label is empty add Unknown
    const chartLabels = finalChartItems.map((item) => {
        if (item.label.startsWith(" ")) {
            return "Unknown" + item.label;
        }
        return item.label;
    });

    const chartValues = finalChartItems.map(item => item.value);
    const chartColors = finalChartItems.map(item => item.color);
    const chartUrls = finalChartItems.map(item => item.url);


    let legendItems = [...finalChartItems];

    // Prepare legend labels adding unknown to not known manufacturers
    const legendLabels = legendItems.map((item) => {
        if (item.label.startsWith(" ")) {
            return "Unknown" + item.label;
        }
        return item.label;
    });
    const legendColors = legendItems.map(item => item.color);
    const legendUrls = legendItems.map(item => item.url);

    const pie = d3.pie()
        .value(d => d)
        .sort(null);

    const pieData = pie(chartValues);

    const arc = d3.arc()
        .innerRadius(radius * 0.5) // For donut chart
        .outerRadius(radius * 0.8);

    const outerArc = d3.arc()
        .innerRadius(radius * 0.5)
        .outerRadius(radius * 0.85);

    // Add tooltip
    const tooltip = d3.select("body")
        .append("div")
        .attr("class", "d3-tooltip")
        .style("opacity", 0)
        .style("position", "absolute")
        .style("background-color", "white")
        .style("border", "1px solid #ddd")
        .style("border-radius", "3px")
        .style("padding", "5px")
        .style("pointer-events", "none")
        .style("z-index", "100");

    // Generate pie slices
    const slices = svg.selectAll(".arc")
        .data(pieData)
        .enter()
        .append("g")
        .attr("class", "arc");

    // Draw paths
    slices.append("path")
        .attr("d", arc)
        .attr("fill", (d, i) => chartColors[i])
        .attr("stroke", "white")
        .style("stroke-width", "2px")
        .style("cursor", (d, i) => chartUrls[i] && !dataUtils.isEmptyString(chartUrls[i]) ? "pointer" : "default")
        .on("mouseover", function (event, d) {
            d3.select(this)
                .transition()
                .duration(100)
                .attr("d", outerArc);

            tooltip.transition()
                .duration(200)
                .style("opacity", 0.9);

            tooltip.html(`${chartLabels[d.index]}`)
                .style("left", (event.pageX) + "px")
                .style("top", (event.pageY - 28) + "px");
        })
        .on("mouseout", function () {
            d3.select(this)
                .transition()
                .duration(100)
                .attr("d", arc);

            tooltip.transition()
                .duration(500)
                .style("opacity", 0);
        })
        .on("click", function (event, d) {
            if (chartUrls[d.index] && !dataUtils.isEmptyString(chartUrls[d.index])) {
                window.location.href = chartUrls[d.index];
            }
        });

    // Create the legend container
    const legendContainer = d3.select(container)
        .append("div")
        .attr("class", "d3-legend-container")
        .style("margin-top", "2px")
        .style("width", "100%")
        .style("max-height", `${legendHeight}px`)
        .style("overflow", "hidden")
        .style("display", "flex")
        .style("flex-wrap", "wrap")
        .style("justify-content", "center");

    // Add legend items
    legendLabels.forEach((label, i) => {
        const legendItem = legendContainer
            .append("div")
            .style("display", "inline-flex")
            .style("align-items", "center")
            .style("margin", "1px 4px")
            .style("max-width", `${containerWidth / 3 - 10}px`)
            .style("cursor", legendUrls[i] && !dataUtils.isEmptyString(legendUrls[i]) ? "pointer" : "default")
            .on("click", function () {
                if (legendUrls[i] && !dataUtils.isEmptyString(legendUrls[i])) {
                    window.location.href = legendUrls[i];
                }
            });

        legendItem.append("div")
            .style("width", "10px")
            .style("height", "10px")
            .style("background-color", legendColors[i])
            .style("margin-right", "3px")
            .style("flex-shrink", "0");

        legendItem.append("div")
            .attr("class", "legend-text")
            .text(label)
            .style("font-size", "12px")
            .style("white-space", "nowrap")
            .style("overflow", "hidden")
            .style("text-overflow", "ellipsis");
    });

    // Return tooltip cleanup function
    return () => {
        tooltip.remove();
    };
}

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], () => {
    refresh_chart();
}, { flush: 'pre', deep: true });


onMounted(() => {
    // set initial dimension
    if (chartContainer.value && chartParent.value) {

        chartContainer.value.style.width = '100%';
        chartContainer.value.style.height = '100%';
        chartContainer.value.style.minHeight = '300px';


        resizeObserver = new ResizeObserver(() => {
            if (chartData.value) {
                // redraw pie chart if resize happens
                nextTick(() => {
                    redraw_chart();
                });
            }
        });
        resizeObserver.observe(chartParent.value);

        setTimeout(() => {
            refresh_chart();
        }, 100);
    }
});

onBeforeUnmount(() => {
    // Clean up resize observer
    if (resizeObserver) {
        resizeObserver.disconnect();
        resizeObserver = null;
    }
});

async function refresh_chart() {
    try {
        // First ensure chartContainer exists
        if (!chartContainer.value) {
            return;
        }
        isLoading.value = (props?.showOnlyFirstLoading === true) ? (firstLoading.value && true) : true;

        const data = await get_chart_data();
        if (!data) {
            chart_data_available.value = false;
            isLoading.value = false
            return;
        }

        chartData.value = data;

        // Use await with nextTick to ensure DOM is updated
        await nextTick();

        // Only proceed if chartContainer still exists
        if (chartContainer.value) {
            chartContainer.value.innerHTML = '';
            drawChart(data);
            isLoading.value = false;
        }
    } catch (error) {
        console.error("Error fetching chart data:", error);
        chart_data_available.value = false;
    }
}

// for external usage
function redraw_chart() {
    if (chartData.value) {

        if (chartContainer.value) {
            chartContainer.value.innerHTML = '';
        }
        drawChart(chartData.value);
    }
}

const mountComponent = () => {
    // set initial dimension
    if (chartContainer.value && chartParent.value) {
        chartContainer.value.style.width = '100%';
        chartContainer.value.style.height = '100%';
        chartContainer.value.style.minHeight = '300px';

        resizeObserver = new ResizeObserver(() => {
            if (chartData.value) {
                // Use nextTick with error handling
                nextTick().then(() => {
                    if (chartContainer.value) {
                        redraw_chart();
                    }
                }).catch(err => {
                    console.error("Error in resize redraw:", err);
                });
            }
        });

        resizeObserver.observe(chartParent.value);

        // Use a slightly longer timeout to ensure DOM is fully rendered
        setTimeout(() => {
            refresh_chart().catch(err => {
                console.error("Error during initial chart refresh:", err);
            });
        }, 200);
    } else {
        console.warn("Chart container or parent not available on mount");
        // Try again in a moment
        setTimeout(mountComponent, 100);
    }
};


onMounted(() => {
    mountComponent();
});


// Expose methods for external use (Match the Sankey component's approach)
defineExpose({
    update_chart: refresh_chart,
    redraw_chart: redraw_chart
});
</script>

<style scoped>
/* Using scoped style like in the Sankey component */
.d3-chart-container {
    position: relative;
    width: 100%;
    height: 100%;
    min-height: 300px;
    display: block;
}

/* Use a flex container approach like in Sankey */
.d-flex {
    display: flex;
}

.flex-column {
    flex-direction: column;
}

.flex-grow-1 {
    flex-grow: 1;
}

.position-relative {
    position: relative;
}

.d3-legend-container {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    margin-top: 10px;
}

.legend-text {
    font-size: 12px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 150px;
}

.d3-tooltip {
    position: absolute;
    z-index: 1070;
    font-size: 12px;
    background-color: white;
    border: 1px solid #ddd;
    border-radius: 3px;
    padding: 5px;
    pointer-events: none;
}
</style>
