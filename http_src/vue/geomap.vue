<template>
    <div class="geomap-container" ref="mapContainer">
        <Loading v-if="isLoading"></Loading>

        <!-- Tooltip -->
        <div v-if="tooltip.show" ref="tooltipRef" class="static-tooltip" :style="{
            left: tooltip.x + 'px',
            top: tooltip.y + 'px'
        }">
            <div class="static-tooltip-content">
                <div class="tooltip-header">
                    <button @click="closeTooltip" class="close-btn" type="button" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div v-html="tooltip.content"></div>
            </div>
        </div>

        <svg ref="svgElement" width="100%" height="100vh"></svg>
    </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
import { default as Loading } from "./loading.vue";
const d3 = d3v7;
const topoData = ref(null);
const countryMapping = ref(null);
const dotSize = 1.8;

const props = defineProps({
    tooltipFormatter: Function,
    geomapDataArray: Array,
    getGeomapData: Function,
    glowDots: Boolean
});

const geomapDataArray = ref(props.geomapDataArray);
// Refs
const mapContainer = ref(null);
const svgElement = ref(null);
const tooltipRef = ref(null);
const isLoading = ref(true);

// tooltip state
const tooltip = ref({
    show: false,
    x: 0,
    y: 0,
    content: '',
    targetElement: null
});

// D3 fata
let svg = null;
let projection = null;
let path = null;
let g = null;
let zoomGroup = null;
let width = 0;
let height = 0;
let resizeObserver = null;
let worldData = null;


let highlightedCountry = null;

const closeTooltip = () => {
    tooltip.value.show = false;

    // reset highlited dot
    if (tooltip.value.targetElement) {
        const dotElement = d3.select(tooltip.value.targetElement).select('.alert-dot');
        if (!dotElement.empty()) {
            const originalRadius = parseFloat(dotElement.attr('data-original-radius')) || 2;
            const originalColor = dotElement.attr('data-original-color') || '#ff0000';

            dotElement
                .transition()
                .duration(200)
                .attr('r', originalRadius)
                .attr('fill', originalColor);
        }
    }

    // reset highlighted country
    if (highlightedCountry) {
        d3.select(highlightedCountry).attr('fill', '#1e293b');
        highlightedCountry = null;
    }

    tooltip.value.targetElement = null;
    tooltip.value.content = '';
};


const initializeMap = async () => {
    if (!mapContainer.value || !svgElement.value) return;

    isLoading.value = true;

    if (!topoData.value || !topoData.value.objects || !topoData.value.objects.countries) {
        isLoading.value = false;
        return;
    }

    // set dimensions
    const containerRect = mapContainer.value.getBoundingClientRect();
    width = containerRect.width;
    height = containerRect.height;

    // clear previous SVG content
    d3.select(svgElement.value).selectAll('*').remove();

    // initialize SVG and groups
    svg = d3.select(svgElement.value)
        .attr('width', width)
        .attr('height', height)
        .attr('viewBox', [0, 0, width, height]);

    zoomGroup = svg.append('g');

    projection = d3.geoEquirectangular()
        .scale((width) / (2 * Math.PI) * 0.9)
        .translate([width / 2, height / 2]);

    path = d3.geoPath().projection(projection);

    // Add grid/graticule with cybersecurity theme
    const graticule = d3.geoGraticule().step([15, 15]);
    zoomGroup.append('path')
        .attr('class', 'graticule')
        .attr('d', path(graticule()))
        .attr('fill', 'none')
        .attr('stroke', '#1e293b')
        .attr('stroke-width', 0.3)
        .attr('stroke-opacity', 0.7);

    g = zoomGroup.append('g');

    // zoom behaviour
    const zoom = d3.zoom()
        .scaleExtent([1, 8])
        .on('zoom', (event) => {
            zoomGroup.attr('transform', event.transform);
        });

    svg.call(zoom);

    // load world data if not already loaded
    if (!worldData) {
        try {
            // Convert TopoJSON to GeoJSON using topojson-client
            const countries = topojson.feature(topoData.value, topoData.value.objects.countries);
            worldData = countries;
        } catch (error) {
            console.error('Error loading world map data:', error);
            isLoading.value = false;
            return;
        }
    }

    // draw countries
    const countryPaths = g.selectAll('path.country')
        .data(worldData.features)
        .enter()
        .append('path')
        .attr('class', 'country')
        .attr('id', d => `country-${d.id || 'unknown'}`)
        .attr('d', path)
        .attr('fill', '#1e293b')
        .attr('stroke', '#334155')
        .attr('stroke-width', 0.5)
        .attr('stroke-opacity', 0.7)
        .attr('data-country-id', d => d.id)
        .attr('data-country-name', d => getCountryNameFromTopoData(d))
        .style('cursor', 'pointer');

    // add mouse event handlers
    countryPaths
        .on('mouseover', function (event, d) {
            if (highlightedCountry !== this) {
                d3.select(this).attr('fill', '#334155');
            }
        })
        .on('mouseout', function (event, d) {
            if (highlightedCountry !== this) {
                d3.select(this).attr('fill', '#1e293b');
            }
        })
        .on('click', function (event, d) {
            // stop event propagation first
            event.stopPropagation();

            // reset previous highlighted country
            if (highlightedCountry) {
                d3.select(highlightedCountry).attr('fill', '#1e293b');
            }

            // highlight this country
            d3.select(this).attr('fill', '#475569');
            highlightedCountry = this;
        });

    // draw country shape
    const borders = topojson.mesh(topoData.value, topoData.value.objects.countries, (a, b) => a !== b);

    g.append('path')
        .attr('class', 'country-borders')
        .attr('d', path(borders))
        .attr('fill', 'none')
        .attr('stroke', '#475569')
        .attr('stroke-width', 0.7)
        .attr('stroke-opacity', 0.7);

    // close tooltip on svg click
    svg.on('click', function (event) {
        // Close tooltip if open
        if (tooltip.value.show) {
            closeTooltip();
        }

        // eeset previous highlighted country if exists
        if (highlightedCountry) {
            d3.select(highlightedCountry).attr('fill', '#1e293b');
            highlightedCountry = null;
        }
    });

    isLoading.value = false;
};


// display data on map, 
// check data format, if lat and lng are present use renderDotsByCoordinates
// else render in the centroid of the country given in the json
const displayData = () => {
    if (!worldData || !worldData.features) {
        console.log('Missing required data for displaying events');
        return;
    }

    // Clear existing dots on map
    g.selectAll('.alert-dot').remove();
    g.selectAll('.pulse-circle').remove();
    g.selectAll('.alert-label').remove();

    // Decide format type
    const sample = geomapDataArray.value[0];
    const isCoordinateBased = sample && 'lat' in sample && 'lng' in sample;

    if (isCoordinateBased) {
        renderDotsByCoordinates();
    } else {
        renderDotsByCountryCentroid();
    }
};

///////////////////////////////
const renderDotsByCoordinates = () => {
    geomapDataArray.value.forEach(alert => {
        const latitude = alert.lat;
        const longitude = alert.lng;
        const color = '#FF8F00';

        if (latitude == null || longitude == null) return;

        const coordinates = projection([longitude, latitude]);
        if (!coordinates || isNaN(coordinates[0]) || isNaN(coordinates[1])) return;

        const [x, y] = coordinates;

        const nodeGroup = g.append('g')
            .attr('class', 'alert-group')
            .attr('transform', `translate(${x}, ${y})`)
            .style('cursor', 'pointer');

        const alertDot = nodeGroup.append('circle')
            .attr('class', 'alert-dot')
            .attr('r', dotSize)
            .attr('fill', color)
            .attr('stroke', '#ffffff')
            .attr('stroke-width', 0.5)
            .attr('data-original-radius', dotSize)
            .attr('data-original-color', color);

        nodeGroup.on('click', function (event) {
            // prevent map click handler from firing
            event.stopPropagation();
            const tooltipContent = props.tooltipFormatter(alert);

            // get mouse position to put tooltip
            const [mouseX, mouseY] = d3.pointer(event, mapContainer.value);

            // show tooltip
            tooltip.value = {
                show: true,
                x: mouseX,
                y: mouseY,
                content: tooltipContent,
                targetElement: this
            };
        });
    });
};

///////////////////////////////
const renderDotsByCountryCentroid = () => {
    const alertsByCountry = {};

    geomapDataArray.value.forEach(alert => {
        const countryId = alert.country_id;
        if (!alertsByCountry[countryId]) alertsByCountry[countryId] = [];
        alertsByCountry[countryId].push(alert);
    });

    Object.keys(alertsByCountry).forEach(countryId => {
        const feature = worldData.features.find(f => Number(f.id) === Number(countryId));
        if (!feature) return;

        const centroid = path.centroid(feature);
        const offsetBase = 10;
        const offsets = [
            [0, 0], [offsetBase, 0], [-offsetBase, 0],
            [0, offsetBase], [0, -offsetBase],
            [offsetBase, offsetBase], [-offsetBase, offsetBase],
            [offsetBase, -offsetBase], [-offsetBase, -offsetBase]
        ];

        alertsByCountry[countryId].forEach((alert, index) => {
            const color = alert.color || '#ff0000';
            const severity = alert.severity || 'Info';
            const offset = offsets[index % offsets.length];
            const [x, y] = [centroid[0] + offset[0], centroid[1] + offset[1]];

            const nodeGroup = g.append('g')
                .attr('class', 'alert-group')
                .attr('transform', `translate(${x}, ${y})`)
                .style('cursor', 'pointer');

            const alertDot = nodeGroup.append('circle')
                .attr('class', 'alert-dot')
                .attr('r', dotSize)
                .attr('fill', color)
                .attr('stroke', '#ffffff')
                .attr('stroke-width', 0.5)
                .attr('data-original-radius', dotSize)
                .attr('data-original-color', color);

            nodeGroup.on('click', function (event) {
                event.stopPropagation();
                const countryName = getCountryNameFromTopoData(feature);

                // get tooltip content
                const tooltipContent = props.tooltipFormatter(alert, countryName);

                // get mouse position to show tooltup
                const [mouseX, mouseY] = d3.pointer(event, mapContainer.value);

                // show tooltip
                tooltip.value = {
                    show: true,
                    x: mouseX,
                    y: mouseY,
                    content: tooltipContent,
                    targetElement: this
                };

            });

            if (props.glowDots && ['Critical', 'Emergency', 'Warning'].includes(severity)) {
                const glowId = `glow-${alert.country_id}-${severity}`;
                if (!document.getElementById(glowId)) {
                    const glowFilter = svg.append('defs')
                        .append('filter')
                        .attr('id', glowId)
                        .attr('x', '-50%')
                        .attr('y', '-50%')
                        .attr('width', '200%')
                        .attr('height', '200%');

                    glowFilter.append('feGaussianBlur')
                        .attr('stdDeviation', severity === 'Warning' ? '1' : '2')
                        .attr('result', 'coloredBlur');

                    const feMerge = glowFilter.append('feMerge');
                    feMerge.append('feMergeNode').attr('in', 'coloredBlur');
                    feMerge.append('feMergeNode').attr('in', 'SourceGraphic');
                }

                alertDot.attr('filter', `url(#${glowId})`);
            }

            if (['Critical', 'Emergency', 'Warning', 'Error'].includes(severity)) {
                nodeGroup.append('circle')
                    .attr('class', 'pulse-circle')
                    .attr('r', dotSize)
                    .attr('fill', 'none')
                    .attr('stroke', color)
                    .attr('stroke-width', 1)
                    .attr('opacity', 0.8)
                    .call(animatePulseElement);
            }

        });
    });
};

///////////////////////////////

// get country name from topodata feature
const getCountryNameFromTopoData = (feature) => {
    if (!feature) return 'Unknown';

    if (feature.properties) {
        return feature.properties.NAME ||
            feature.properties.name ||
            feature.properties.ADMIN ||
            feature.properties.admin ||
            `Country #${feature.id || 'unknown'}`;
    }

    return `Country #${feature.id || 'unknown'}`;
};

// pulse nodes
function animatePulseElement(element) {
    let baseRadius = parseFloat(element.attr('r')) * 1.2;

    if (baseRadius >= 2) baseRadius = 2;

    element
        .attr('r', baseRadius)
        .attr('opacity', 0.8)
        .transition()
        .duration(1500)
        .attr('r', baseRadius)
        .attr('opacity', 0)
        .ease(d3.easeQuadOut)
        .on('end', function () {
            d3.select(this).call(animatePulseElement);
        });
}

// Handle window resize
const handleResize = () => {
    nextTick(() => {
        // Close tooltip on resize
        if (tooltip.value.show) {
            closeTooltip();
        }
        initializeMap();
    });
};

function buildCountryNameToIdMap() {

    if (!topoData.value || !topoData.value.objects || !topoData.value.objects.countries) {
        console.warn('TopoJSON data not loaded yet');
        return {};
    }

    const geometries = topoData.value.objects.countries.geometries;
    const map = {};

    geometries.forEach(geom => {
        const name = geom.properties.name;
        const id = parseInt(geom.id, 10);
        if (name && id) {
            map[name] = id;
        }
    });

    return map;
}

onMounted(async () => {
    try {
        // Load TopoJSON data
        topoData.value = await d3.json('https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json');

        // Build country mapping after data is loaded
        countryMapping.value = buildCountryNameToIdMap();

    } catch (error) {
        console.error('Error loading map data:', error);
        isLoading.value = false;
    }
});

onUnmounted(() => {
    // clean up resources
    if (resizeObserver) {
        resizeObserver.disconnect();
    }

    // clear all transitions and intervals
    d3.selectAll('.pulse-circle').interrupt();
});

// watch to render data only after topojson is ready
watch(topoData, async (newData) => {
    if (newData && mapContainer.value) {
        await initializeMap();
        displayData();
        // set up resize observer
        resizeObserver = new ResizeObserver(handleResize);
        resizeObserver.observe(mapContainer.value);
    }
}, { immediate: true });

// watch data props change and re-render
watch(() => props.geomapDataArray, async (newData) => {
    geomapDataArray.value = newData;

    if (g && worldData) {
        displayData();
    } else {
        await initializeMap();
    }
}, { immediate: true, deep: true });

</script>

<style scoped>
.geomap-container {
    position: relative;
    width: 100%;
    height: 100%;
    min-height: 500px;
    background-color: #0f172a;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.5);
    font-family: 'Inter', 'Segoe UI', sans-serif;
}

.loading-overlay {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(15, 23, 42, 0.9);
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    z-index: 10;
}

.loading-spinner {
    width: 40px;
    height: 40px;
    border: 3px solid rgba(59, 130, 246, 0.3);
    border-radius: 50%;
    border-top-color: #3b82f6;
    animation: spin 1s ease-in-out infinite;
    margin-bottom: 12px;
}

.loading-text {
    color: #e2e8f0;
    font-size: 14px;
    letter-spacing: 1px;
}

@keyframes spin {
    to {
        transform: rotate(360deg);
    }
}

.static-tooltip {
    position: absolute;
    z-index: 1000;
    pointer-events: auto;
    background-color: rgba(15, 23, 42, 0.95);
    border: 1px solid #334155;
    border-radius: 8px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(10px);
    min-width: 200px;
    max-width: 300px;
    color: #e2e8f0;
}

.static-tooltip-content {
    position: relative;
    padding: 12px;
}

.tooltip-header {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 8px;
}

.close-btn {
    background: none;
    border: none;
    color: #e2e8f0;
    font-size: 18px;
    font-weight: bold;
    cursor: pointer;
    padding: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: all 0.2s ease;
}

.close-btn:hover {
    background-color: rgba(255, 255, 255, 0.1);
    color: #ffffff;
}

.close-btn:focus {
    outline: none;
    box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
}

:deep(.custom-tooltip-content) {
    color: #e2e8f0;
}

:deep(.custom-tooltip-content h6) {
    color: #ffffff;
    margin-bottom: 8px;
}

:deep(.custom-tooltip-content hr) {
    border-color: rgba(148, 163, 184, 0.3);
}

:deep(.custom-tooltip-content .flag) {
    width: 16px;
    height: 12px;
    margin-right: 8px;
}

:deep(.custom-tooltip-content .badge) {
    font-size: 0.75rem;
}

.map-controls {
    position: absolute;
    top: 15px;
    right: 15px;
    z-index: 5;
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.control-button {
    background-color: rgba(15, 23, 42, 0.8);
    color: #e2e8f0;
    border: 1px solid rgba(148, 163, 184, 0.3);
    border-radius: 4px;
    padding: 8px 12px;
    font-size: 12px;
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    transition: all 0.2s;
}

.control-button:hover {
    background-color: rgba(30, 41, 59, 0.9);
    border-color: rgba(148, 163, 184, 0.5);
}

.button-icon {
    font-size: 14px;
}

.legend {
    background-color: rgba(15, 23, 42, 0.8);
    border-radius: 4px;
    padding: 10px;
    border: 1px solid rgba(148, 163, 184, 0.3);
}

.legend-title {
    color: #e2e8f0;
    font-size: 12px;
    font-weight: 600;
    margin-bottom: 8px;
    border-bottom: 1px solid rgba(148, 163, 184, 0.2);
    padding-bottom: 4px;
}

.legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #e2e8f0;
    font-size: 11px;
    margin-bottom: 5px;
}

.severity-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
}

.severity-dot.critical {
    background-color: #ff2d55;
    box-shadow: 0 0 5px rgba(255, 45, 85, 0.7);
}

.severity-dot.high {
    background-color: #ff9500;
    box-shadow: 0 0 5px rgba(255, 149, 0, 0.7);
}

.severity-dot.medium {
    background-color: #ffcc00;
    box-shadow: 0 0 5px rgba(255, 204, 0, 0.7);
}

.severity-dot.low {
    background-color: #5cd65c;
    box-shadow: 0 0 5px rgba(92, 214, 92, 0.7);
}

/* Basic styling for map elements */
:deep(.country) {
    transition: fill 0.3s ease;
}

:deep(.alert-dot) {
    transition: r 0.2s ease;
}

/* Pulse animation */
@keyframes pulse {
    0% {
        transform: scale(1);
        opacity: 0.8;
    }

    100% {
        transform: scale(3);
        opacity: 0;
    }
}

:deep(.pulse-circle) {
    animation: pulse 1.5s infinite ease-out;
}
</style>