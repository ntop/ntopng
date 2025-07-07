# GeoMap Component Documentation

## Overview
The GeoMap component is a Vue.js interactive world map visualization built with D3.js. It displays geographical data as dots on a world map, supporting both coordinate-based and country-based positioning with tooltips and interactive features.

## Features
- Interactive world map with zoom and pan capabilities
- Two data visualization modes: coordinate-based (lat/lng) and country-centroid based
- Clickable dots with customizable tooltips
- Country highlighting on hover and click
- Pulse animations for high-severity alerts
- Optional glow effects for critical alerts
- Responsive design with automatic resize handling
- Loading states and error handling

## Props

### Required Props
- **`geomapDataArray`** (Array): Array of data objects to display on the map
- **`getGeomapData`** (Function): Async function to fetch/load map data
- **`tooltipFormatter`** (Function): Function to format tooltip content

### Optional Props
- **`glowDots`** (Boolean): Enable glow effects for high-severity alerts (Critical, Emergency, Warning)

## Data Format

### Coordinate-based Data Format
When your data contains `lat` and `lng` properties, the component will render dots at specific coordinates:

```javascript
const coordinateBasedData = [
    {
        lat: 40.7128,           // Latitude (required)
        lng: -74.0060,          // Longitude (required)
        severity: "Critical",    // Severity level (optional)
        color: "#ff0000",       // Dot color (optional, defaults to "#FF8F00")
        // ... any other custom properties for tooltip
    }
]
```

### Country-centroid Data Format
When your data contains `country_id` but no coordinates, dots will be placed at country centroids:

```javascript
const countryBasedData = [
    {
        country_id: 840,        // Numeric country ID (required)
        severity: "Warning",    // Severity level (optional)
        color: "#ffaa00",       // Dot color (optional, defaults to "#ff0000")
        alerts_count: 15,       // Number of alerts (optional)
        country_code: "us",     // Country code for flags (optional)
        // ... any other custom properties for tooltip
    }
]
```

## Severity Levels
The component recognizes the following severity levels for special effects:
- **Critical**: Gets glow effect (if enabled) and pulse animation
- **Emergency**: Gets glow effect (if enabled) and pulse animation
- **Warning**: Gets glow effect (if enabled) and pulse animation
- **Error**: Gets pulse animation only
- **Info**: Standard dot display

## Functions

### tooltipFormatter(dataItem, countryName?)
Function to format tooltip content. Receives the data item and optionally the country name.

**Parameters:**
- `dataItem` (Object): The data object for the clicked dot
- `countryName` (String, optional): Country name (only provided for country-centroid mode)

**Returns:** String (HTML content for tooltip)

**Example:**
```javascript
const formatTooltip = (item, countryName) => {
    return `
        <div class="tooltip-content">
            <h6>${countryName || 'Location'}</h6>
            <p>Alerts: ${item.alerts_count || 1}</p>
            <p>Severity: ${item.severity || 'Info'}</p>
        </div>
    `;
};
```

### getGeomapData()
Async function to fetch or prepare map data. Should populate the `geomapDataArray`.

**Example:**
```javascript
const fetchMapData = async () => {
    try {
        const response = await fetch('/api/map-data');
        const data = await response.json();
        geomapDataArray.value = data;
    } catch (error) {
        console.error('Failed to load map data:', error);
    }
};
```

## Usage Example

```vue
<template>
    <GeoMap
        :geomapDataArray="mapData"
        :getGeomapData="fetchMapData"
        :tooltipFormatter="formatTooltip"
        :glowDots="true"
    />
</template>

<script setup>
import { ref } from 'vue';
import GeoMap from './components/GeoMap.vue';

const mapData = ref([]);

// Fetch data function
const fetchMapData = async () => {
    try {
        const response = await fetch('/api/security-alerts');
        const data = await response.json();
        mapData.value = data;
    } catch (error) {
        console.error('Error fetching map data:', error);
    }
};

// Tooltip formatter function
const formatTooltip = (alert, countryName) => {
    const severityColor = {
        'Critical': 'danger',
        'Warning': 'warning',
        'Info': 'info'
    }[alert.severity] || 'secondary';
    
    return `
        <div class="p-2">
            <h6 class="fw-bold">${countryName || 'Alert Location'}</h6>
            <hr>
            <div class="d-flex justify-content-between">
                <strong>Alerts:</strong>
                <span>${alert.alerts_count || 1}</span>
            </div>
            <div class="d-flex justify-content-between">
                <strong>Severity:</strong>
                <span class="badge bg-${severityColor}">${alert.severity}</span>
            </div>
        </div>
    `;
};
</script>
```

## Notes
- The component automatically loads world map data from `https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json`
- Map supports zoom (1x to 8x) and pan interactions
- Tooltips are positioned at mouse click location
- Multiple dots per country are automatically offset to prevent overlap
- The component is responsive and handles window resize events
- Country IDs should match the TopoJSON country identifiers (numeric)