<template>
    <div class="geomap-container" ref="mapContainer">
        <div v-if="loading" class="loading-overlay">
            <div class="loading-spinner"></div>
            <div class="loading-text">Loading Threat Intelligence...</div>
        </div>
        <div ref="tooltipElement" class="tooltip">
            <div class="tooltip-content">
                <div class="tooltip-title"></div>
                <div class="tooltip-details"></div>
            </div>
        </div>
        <div class="map-controls">
            <button @click="resetZoom" class="control-button">
                <span class="button-icon">⟲</span> Reset View
            </button>
            <div class="legend">
                <div class="legend-title">Alert Severity</div>
                <div class="legend-item">
                    <span class="severity-dot critical"></span>Critical
                </div>
                <div class="legend-item">
                    <span class="severity-dot high"></span>High
                </div>
                <div class="legend-item">
                    <span class="severity-dot medium"></span>Medium
                </div>
                <div class="legend-item">
                    <span class="severity-dot low"></span>Notice
                </div>
            </div>
        </div>
        <svg ref="svgElement" width="100%" height="100vh"></svg>
    </div>
</template>

<script setup>
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
const _i18n = (t) => i18n(t);
const d3 = d3v7;
const topoData = ref(null);
const countryMapping = ref(null);

const props = defineProps({
    context: Object,
});

const ifid = String(props.context.ifid);

// Refs
const mapContainer = ref(null);
const svgElement = ref(null);
const tooltipElement = ref(null);
const loading = ref(true);

// D3 selections and data
let svg = null;
let tooltip = null;
let projection = null;
let path = null;
let g = null;
let zoomGroup = null;
let width = 0;
let height = 0;
let resizeObserver = null;
let worldData = null;

// Track currently highlighted country
let highlightedCountry = null;


// Initialize the map
const initializeMap = async () => {
    if (!mapContainer.value || !svgElement.value) return;

    loading.value = true;

    // Set dimensions
    const containerRect = mapContainer.value.getBoundingClientRect();
    width = containerRect.width;
    height = containerRect.height;

    // Clear previous SVG content
    d3.select(svgElement.value).selectAll('*').remove();

    // Initialize tooltip with cybersecurity styling
    tooltip = d3.select(tooltipElement.value)
        .style('opacity', 0)
        .style('background-color', 'rgba(15, 23, 42, 0.95)')
        .style('color', '#e2e8f0')
        .style('border-radius', '4px')
        .style('padding', '10px')
        .style('box-shadow', '0 4px 20px rgba(0, 0, 0, 0.5)');

    // Initialize SVG and groups
    svg = d3.select(svgElement.value)
        .attr('width', width)
        .attr('height', height)
        .attr('viewBox', [0, 0, width, height]);

    // Add a background rect for zoom reset - cybersecurity theme background
    svg.append('rect')
        .attr('width', width)
        .attr('height', height)
        .attr('fill', '#0f172a')  // Dark blue background
        .style('cursor', 'pointer')
        .on('dblclick', resetZoom);

    // Create a group for zoom/pan behavior
    zoomGroup = svg.append('g');

    // Initialize projection and path
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
        .attr('stroke', '#1e293b')  // Dark blue grid
        .attr('stroke-width', 0.3)
        .attr('stroke-opacity', 0.7);

    g = zoomGroup.append('g');

    // Implement zoom behavior
    const zoom = d3.zoom()
        .scaleExtent([1, 8])
        .on('zoom', (event) => {
            zoomGroup.attr('transform', event.transform);
        });

    svg.call(zoom);

    // Load world map data if not already loaded
    if (!worldData) {
        try {
            // Convert TopoJSON to GeoJSON using topojson-client
            const countries = topojson.feature(topoData.value, topoData.value.objects.countries);
            worldData = countries;

            // Draw countries with cybersecurity theme
            g.selectAll('path.country')
                .data(countries.features)
                .enter()
                .append('path')
                .attr('class', 'country')
                .attr('id', d => `country-${d.id || 'unknown'}`)
                .attr('d', path)
                .attr('fill', '#1e293b')  // Dark blue fill
                .attr('stroke', '#334155')  // Slightly lighter border
                .attr('stroke-width', 0.5)
                .attr('stroke-opacity', 0.7)
                .attr('data-country-id', d => d.id)
                .attr('data-country-name', d => getCountryNameFromTopoData(d))
                .style('cursor', 'pointer')
                .on('mouseover', function (event, d) {
                    if (highlightedCountry !== this) {
                        d3.select(this).attr('fill', '#334155');  // Highlight color
                    }
                })
                .on('mouseout', function (event, d) {
                    if (highlightedCountry !== this) {
                        d3.select(this).attr('fill', '#1e293b');  // Base color
                    }
                })
                .on('click', function (event, d) {
                    // Reset previous highlighted country
                    if (highlightedCountry) {
                        d3.select(highlightedCountry).attr('fill', '#1e293b');
                    }

                    // Highlight this country
                    d3.select(this).attr('fill', '#475569');
                    highlightedCountry = this;

                    // Get country name and log it
                    const countryName = getCountryNameFromTopoData(d);
                    console.log(`Clicked on country: ${countryName} (ID: ${d.id})`);

                    // Show tooltip
                    tooltip
                        .style('opacity', 1)
                        .style('left', `${event.pageX + 10}px`)
                        .style('top', `${event.pageY - 10}px`);

                    d3.select(tooltipElement.value).select('.tooltip-title')
                        .html(`<strong>${countryName}</strong>`);

                    d3.select(tooltipElement.value).select('.tooltip-details')
                        .html(`<div>Country ID: ${d.id}</div>`);

                    // Prevent event propagation to avoid reset zoom
                    event.stopPropagation();
                });

            // Draw country boundaries
            const borders = topojson.mesh(topoData.value, topoData.value.objects.countries, (a, b) => a !== b);
            g.append('path')
                .attr('class', 'country-borders')
                .attr('d', path(borders))
                .attr('fill', 'none')
                .attr('stroke', '#475569')  // Border color
                .attr('stroke-width', 0.7)
                .attr('stroke-opacity', 0.7);

        } catch (error) {
            console.error('Error loading world map data:', error);
        }
    } else {
        // Re-draw countries with cybersecurity styling if data is already loaded
        g.selectAll('path.country')
            .data(worldData.features)
            .enter()
            .append('path')
            .attr('class', 'country')
            .attr('id', d => `country-${d.id || 'unknown'}`)
            .attr('d', path)
            .attr('fill', '#1e293b')  // Dark blue fill
            .attr('stroke', '#334155')  // Slightly lighter border
            .attr('stroke-width', 0.5)
            .attr('data-country-id', d => d.id)
            .attr('data-country-name', d => getCountryNameFromTopoData(d))
            .style('cursor', 'pointer')
            .on('mouseover', function (event, d) {
                if (highlightedCountry !== this) {
                    d3.select(this).attr('fill', '#334155');  // Highlight on hover
                }
            })
            .on('mouseout', function (event, d) {
                if (highlightedCountry !== this) {
                    d3.select(this).attr('fill', '#1e293b');  // Return to base
                }
            })
            .on('click', function (event, d) {
                // Reset previous highlighted country
                if (highlightedCountry) {
                    d3.select(highlightedCountry).attr('fill', '#1e293b');
                }

                // Highlight this country
                d3.select(this).attr('fill', '#475569');
                highlightedCountry = this;

                // Get country name and log it
                const countryName = getCountryNameFromTopoData(d);
                console.log(`Clicked on country: ${countryName} (ID: ${d.id})`);

                // Show tooltip
                tooltip
                    .style('opacity', 1)
                    .style('left', `${event.pageX + 10}px`)
                    .style('top', `${event.pageY - 10}px`);

                d3.select(tooltipElement.value).select('.tooltip-title')
                    .html(`<strong>${countryName}</strong>`);

                d3.select(tooltipElement.value).select('.tooltip-details')
                    .html(`<div>Country ID: ${d.id}</div>`);

                // Prevent event propagation
                event.stopPropagation();
            });
    }

    // Add click handler to background to reset highlights
    svg.on('click', function () {
        if (highlightedCountry) {
            d3.select(highlightedCountry).attr('fill', '#1e293b');
            highlightedCountry = null;

            // Hide tooltip
            tooltip.style('opacity', 0);
        }
    });

    // Fetch and display alert data
    await getAlertsData();

    loading.value = false;
};

// Reset zoom function
const resetZoom = () => {
    svg.transition().duration(750).call(
        d3.zoom().transform,
        d3.zoomIdentity,
        d3.zoomTransform(svg.node()).invert([width / 2, height / 2])
    );
};

// Fetch and process alert data
const getAlertsData = async () => {
    try {
        let url = `${http_prefix}/lua/pro/rest/v2/get/alert/geomap/alerts.lua?`;
        url = create_url(url);

        let headers = {
            "Content-Type": "application/json",
        };
        const rsp = await ntopng_utility.http_request(url, { method: "get", headers });

        if (rsp) {
            if (rsp.length > 0) {
                displayAlertData(rsp);
            }
        }

    } catch (error) {
        console.error('Error fetching or processing data:', error);
    }
};

// Display alert data on the map with enhanced visuals
const displayAlertData = (alertData) => {
    if (!g || !worldData || !worldData.features) return;

    // Remove existing alert dots
    g.selectAll('.alert-dot').remove();
    g.selectAll('.pulse-circle').remove();
    g.selectAll('.alert-label').remove();

    // Group alerts by country_id to handle multiple alerts per country
    const alertsByCountry = {};
    alertData.forEach(alert => {
        if (!alertsByCountry[alert.country_id]) {
            alertsByCountry[alert.country_id] = [];
        }
        alertsByCountry[alert.country_id].push(alert);
    });

    // Process each country's alerts
    Object.keys(alertsByCountry).forEach(countryId => {
        const countryAlerts = alertsByCountry[countryId];
        const countryId_num = Number(countryId);
        
        // Find the feature for this country using country_id
        const feature = worldData.features.find(f => Number(f.id) === countryId_num);
        if (!feature) return;

        // Get the country centroid and bounds
        const centroid = path.centroid(feature);
        const bounds = path.bounds(feature);
        
        // Calculate available space
        const width = bounds[1][0] - bounds[0][0];
        const height = bounds[1][1] - bounds[0][1];
        
        // Calculate offset for multiple dots (arrange in a small grid or circle)
        const offsetBase = 10; // Base offset distance between dots
        const offsets = [
            [0, 0],                          // center
            [offsetBase, 0],                 // right
            [-offsetBase, 0],                // left
            [0, offsetBase],                 // bottom
            [0, -offsetBase],                // top
            [offsetBase, offsetBase],        // bottom-right
            [-offsetBase, offsetBase],       // bottom-left
            [offsetBase, -offsetBase],       // top-right
            [-offsetBase, -offsetBase]       // top-left
        ];

        // Process each alert for this country
        countryAlerts.forEach((alert, index) => {
            const iso3Code = alert.country;
            const alertColor = alert.color;
            
            // Calculate dot size based on relative alert count
            // Normalize between 2-8 pixels based on alert count
            const dotSize = 2;
            
            // Calculate position with offset to avoid overlapping
            // Use modulo to cycle through offsets if there are more alerts than offsets
            const offset = offsets[index % offsets.length];
            const posX = centroid[0] + offset[0];
            const posY = centroid[1] + offset[1];
            
            // Create alert dot group
            const alertGroup = g.append('g')
                .attr('class', 'alert-group')
                .attr('transform', `translate(${posX}, ${posY})`)
                .style('cursor', 'pointer');
            
            // Add glowing effect for higher severity
            if (alert.severity === 'Critical' || alert.severity === 'Emergency' || alert.severity === 'Warning') {
                const glowId = `glow-${alert.country_id}-${alert.severity}`;
                
                // Check if filter already exists
                if (!document.getElementById(glowId)) {
                    const glowFilter = svg.append('defs')
                        .append('filter')
                        .attr('id', glowId)
                        .attr('x', '-50%')
                        .attr('y', '-50%')
                        .attr('width', '200%')
                        .attr('height', '200%');
                    
                    glowFilter.append('feGaussianBlur')
                        .attr('stdDeviation', alert.severity === 'Warning' ? '1' : '2')
                        .attr('result', 'coloredBlur');
                    
                    const feMerge = glowFilter.append('feMerge');
                    feMerge.append('feMergeNode')
                        .attr('in', 'coloredBlur');
                    feMerge.append('feMergeNode')
                        .attr('in', 'SourceGraphic');
                }
                
                alertGroup.select('.alert-dot')
                    .attr('filter', `url(#${glowId})`);
            }

            // Draw the main alert dot
            alertGroup.append('circle')
                .attr('class', 'alert-dot')
                .attr('r', dotSize)
                .attr('fill', alertColor)
                .attr('stroke', '#ffffff')
                .attr('stroke-width', 0.5)
                .attr('data-country', iso3Code)
                .attr('data-severity', alert.severity)
                .attr('data-count', alert.alerts_count);
            
            // Add pulsing effect but only for Critical, Emergency, or Warning alerts
            if (alert.severity === 'Critical' || alert.severity === 'Emergency' || alert.severity === 'Warning' || alert.severity === 'Error') {
                alertGroup.append('circle')
                    .attr('class', 'pulse-circle')
                    .attr('r', dotSize)
                    .attr('fill', 'none')
                    .attr('stroke', alertColor)
                    .attr('stroke-width', 1)
                    .attr('opacity', 0.8)
                    .call(animatePulseElement);
            }
            
            // Add event handlers
            alertGroup
                .on('mouseover', function(event) {
                    // Enlarge the dot slightly
                    d3.select(this).select('.alert-dot')
                        .transition()
                        .duration(200)
                        .attr('r', dotSize * 1.5);
                    
                    // Show tooltip with detailed information
                    tooltip
                        .style('opacity', 1)
                        .style('left', `${event.pageX + 10}px`)
                        .style('top', `${event.pageY - 10}px`);
                    
                    const countryName = getCountryNameFromTopoData(feature);
                    
                    d3.select(tooltipElement.value).select('.tooltip-title')
                        .html(`<strong>${countryName}</strong> <span class="severity-badge" style="background-color:${alertColor}"></span>`);
                    
                    d3.select(tooltipElement.value).select('.tooltip-details')
                        .html(`
                            <div class="tooltip-row"><span class="tooltip-label">Severity:</span> <span class="tooltip-value">${alert.severity}</span></div>
                            <div class="tooltip-row"><span class="tooltip-label">Total Alerts:</span> <span class="tooltip-value">${alert.alerts_count}</span></div>
                            <div class="tooltip-row"><span class="tooltip-label">Country:</span> <span class="tooltip-value">${iso3Code}</span></div>
                        `);
                })
                .on('mouseout', function() {
                    // Return to normal size
                    d3.select(this).select('.alert-dot')
                        .transition()
                        .duration(200)
                        .attr('r', dotSize);
                    
                    // Hide tooltip unless clicking on country
                    if (!highlightedCountry) {
                        tooltip.style('opacity', 0);
                    }
                })
                .on('click', function(event) {
                    // Print alert information to console
                    console.log({
                        country: iso3Code,
                        countryId: alert.country_id,
                        severity: alert.severity,
                        alertsCount: alert.alerts_count,
                        color: alertColor
                    });
                    
                    // Stop propagation to prevent country highlighting
                    event.stopPropagation();
                });
        });
    });
};

// Get country name directly from topodata feature
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


// Helper function to continue pulse animation
function animatePulseElement(element) {

    let baseRadius = parseFloat(element.attr('r')) * 1.2;

    if (baseRadius >= 2.3) baseRadius = 2.3;

    element
        .attr('r', baseRadius)
        .attr('opacity', 0.8)
        .transition()
        .duration(1500)
        .attr('r', baseRadius)
        .attr('opacity', 0)
        .ease(d3.easeQuadOut)
        .on('end', function() {
            d3.select(this).call(animatePulseElement);
        });
}

// Handle window resize
const handleResize = () => {
    nextTick(() => {
        initializeMap();
    });
};

function buildCountryNameToIdMap() {
    const geometries = topoData.value.objects.countries.geometries;
    const map = {};

    geometries.forEach(geom => {
        const name = geom.properties.name;
        const id = parseInt(geom.id, 10); // Convert string to number
        if (name && id) {
            map[name] = id;
        }
    });

    return map;
}

// Lifecycle hooks
onMounted(async () => {
    topoData.value = await d3.json('https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json');
    countryMapping.value = buildCountryNameToIdMap();
    init_url_params();
    await initializeMap();

    // Set up resize observer
    resizeObserver = new ResizeObserver(handleResize);
    resizeObserver.observe(mapContainer.value);
});

onUnmounted(() => {
    // Clean up resources
    if (resizeObserver) {
        resizeObserver.disconnect();
    }

    // Clear all transitions and intervals
    d3.selectAll('.pulse-circle').interrupt();
});

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
}

function add_filter(filter, value) {
    ntopng_url_manager.set_key_to_url(filter, value);
}

function reset_filters() {
    init_url_params();
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
</script>

<style scoped>
.geomap-container {
    position: relative;
    width: 100%;
    height: 100%;
    min-height: 500px;
    background-color: #0f172a; /* Dark blue cybersecurity theme */
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

.tooltip {
    position: absolute;
    pointer-events: none;
    opacity: 0;
    z-index: 1070;
    min-width: 180px;
    transition: opacity 0.2s;
    border-left: 3px solid #3b82f6;
}

.tooltip-content {
    text-align: left;
    font-size: 0.875rem;
    line-height: 1.4;
}

.tooltip-title {
    margin-bottom: 8px;
    font-weight: bold;
    font-size: 1rem;
    border-bottom: 1px solid rgba(148, 163, 184, 0.2);
    padding-bottom: 5px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.tooltip-details {
    font-size: 0.8rem;
}

.tooltip-row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 4px;
}

.tooltip-label {
    color: #94a3b8;
}

.tooltip-value {
    font-weight: 600;
}

.severity-badge {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin-left: 6px;
}

/* Map controls */
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