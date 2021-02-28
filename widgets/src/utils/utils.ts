/**
 * (C) 2021 - ntop.org
*/

import { DisplayFormatter } from "../types/DisplayFormatter";
import { VERSION } from "../version";

/**
 * Standard Color Palette used when the colors array is not provided by the backend.
 */
export const COLOR_PALETTE = ["#a6cee3","#1f78b4","#b2df8a","#33a02c","#fb9a99","#e31a1c","#fdbf6f","#ff7f00","#cab2d6","#6a3d9a","#ffff99","#b15928"];

/**
 * Format a number as ntopng. Return a dash when the number is undefined.
 * @param val The number to format
 */
export function formatInt(val: number): string {    
    if (val === undefined) return '-';
    return Math.round(val).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/**
 * Log a message into the console.
 * @param message Message to show inside the console
 */
export function log(message: string) { 
    console.info(`[%cntop-widgets v.${VERSION}%c] :: ${message}`, 'color: #4989ff; font-weight: 800', 'color: white');
}

export function formatLabel(displayFormatter: DisplayFormatter, currentValue: number, total: number) {
    switch (displayFormatter) {
        case DisplayFormatter.NONE:
            return "";
        case DisplayFormatter.PERCENTAGE:
            return ': ' + ((currentValue / total) * 100).toFixed(2) + '%';
        default:
        case DisplayFormatter.RAW:
            return ': ' + currentValue;
    }
}