/**
    (C) 2026 - ntop.org
*/

/* ***************************************** */

const defaultColors = [
    // Group 1: Blues (6 colors)
    "#001F3F", // Navy
    "#0074D9", // Blue
    "#7FDBFF", // Aqua
    "#39CCCC", // Teal
    "#3D9970", // Olive
    "#2ECC40", // Green

    // Group 2: Purples/Pinks (6 colors)
    "#B10DC9", // Purple
    "#FF4136", // Red
    "#FF851B", // Orange
    "#FFDC00", // Yellow
    "#F012BE", // Fuchsia
    "#85144B", // Maroon

    // Group 3: Earth tones (6 colors)
    "#FF6B6B", // Coral Red
    "#4ECDC4", // Turquoise
    "#45B7D1", // Sky Blue
    "#96CEB4", // Sage Green
    "#FFEAA7", // Pale Yellow
    "#DDA0DD", // Plum

    // Group 4: Additional distinct colors (6 colors)
    "#98D8C8", // Mint
    "#F7DC6F", // Golden Yellow
    "#BB8FCE", // Lavender
    "#82E0AA", // Light Green
    "#F8C471", // Peach
    "#5DADE2", // Light Blue
];

/* ***************************************** */

/**
 * A perceptually distinct palette optimized for side-by-side pie/donut charts.
 * Colors are ordered so that adjacent entries are maximally distinguishable,
 * avoiding similar hues next to each other in round-robin assignment.
 *
 * Unlike defaultColors (which is grouped by hue family), this palette
 * interleaves hues so that the first N colors used across multiple charts
 * on the same page are always visually distinct from one another.
 */
const roundRobinColors = [
    "#E63946", // Vivid Red
    "#2196F3", // Strong Blue
    "#4CAF50", // Medium Green
    "#FF9800", // Amber Orange
    "#9C27B0", // Purple
    "#00BCD4", // Cyan
    "#FF5722", // Deep Orange
    "#3F51B5", // Indigo
    "#8BC34A", // Light Green
    "#F06292", // Pink
    "#009688", // Teal
    "#FFC107", // Yellow
    "#673AB7", // Deep Purple
    "#03A9F4", // Light Blue
    "#CDDC39", // Lime
    "#795548", // Brown
    "#607D8B", // Blue Grey
    "#E91E63", // Hot Pink
    "#00E676", // Bright Green
    "#FF6D00", // Burnt Orange
];

/* ***************************************** */

/**
 * Assigns colors to chart series in a round-robin style, always starting
 * from index 0 of the palette regardless of call order or label names.
 *
 * Key properties:
 *  - Starts from palette index 0 on every call (no global state).
 *  - Within a single call, the same label always gets the same color
 *    (first-seen order determines the index).
 *  - Each unique label consumes the next slot; duplicates reuse their slot.
 *
 * @param {Array<string|{name:string}>} labels - The series labels to color.
 *   Each element is either a plain string or an object with a `.name` property.
 * @param {string[]} [palette=roundRobinColors] - Optional override palette.
 * @returns {string[]} Array of hex color strings, one per label.
 *
 * @example
 * assignRoundRobinColors(["Local->Local", "Remote->Local", "Other"]);
 * // → ["#E63946", "#2196F3", "#4CAF50"]
 *
 * assignRoundRobinColors(["IPv4", "ARP", "Other"]);
 * // → ["#E63946", "#2196F3", "#4CAF50"]  ← always starts at index 0
 *
 * assignRoundRobinColors(["IPv4", "ARP", "IPv4"]);
 * // → ["#E63946", "#2196F3", "#E63946"]  ← duplicate reuses its color
 */
function assignRoundRobinColors(labels, palette = roundRobinColors) {
    const localRegistry = new Map();
    let counter = 0;

    return labels.map((item) => {
        const key = (typeof item === "object" && item !== null) ? (item.name || JSON.stringify(item)) : String(item);

        if (!localRegistry.has(key)) {
            localRegistry.set(key, counter % palette.length);
            counter += 1;
        }

        return palette[localRegistry.get(key)];
    });
}

/* ***************************************** */

/**
 * Assigns consistent colors to items in a list.
 * This function mutates the input array by replacing palette objects with actual color strings.
 * Items with the same identity will receive the same color across calls.
 *
 * @param {Array} palette_list - Array of objects with {palette: 0|1} or items to color
 * @param {Function} getKey - Optional function to extract unique key from item (for stable color assignment)
 * @returns {Array} The same array with colors assigned
 */
function formatSerieColors(palette_list, getKey = null) {
    let colors_list = palette_list;
    let count0 = 0, count1 = 0;
    let colors0 = defaultColors;
    let colors1 = d3v7.schemeCategory10;

    colors_list.forEach((s, index) => {
        if (s.palette == 0) {
            palette_list[index] = colors0[count0 % colors0.length];
            count0 += 1;
        } else if (s.palette == 1) {
            palette_list[index] = colors1[count1 % colors1.length];
            count1 += 1;
        }
    });
}

/* ***************************************** */

/**
 * Assigns consistent colors to chart nodes based on their names.
 * Uses a hash function to ensure the same name always gets the same color.
 *
 * @param {Array} names - Array of node objects with {name, url} properties
 * @returns {Array} Array of color strings corresponding to each node
 */
function assignColors(names) {
    const colors = defaultColors;
    const colorMap = new Map();
    const result = [];

    names.forEach((node, index) => {
        const key = node.name || node;

        // Use simple hash to get consistent color index for each unique name
        if (!colorMap.has(key)) {
            // Simple string hash function
            let hash = 0;
            for (let i = 0; i < key.length; i++) {
                hash = ((hash << 5) - hash) + key.charCodeAt(i);
                hash = hash & hash; // Convert to 32bit integer
            }
            const colorIndex = Math.abs(hash) % colors.length;
            colorMap.set(key, colors[colorIndex]);
        }

        result.push(colorMap.get(key));
    });

    return result;
}

/* ***************************************** */

const colorUtils = function () {
    return {
        formatSerieColors,
        assignColors,
        assignRoundRobinColors,
        defaultColors,
        roundRobinColors,
    };
}();

export default colorUtils;