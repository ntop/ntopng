/**
 * (C) 2021 - ntop.org
*/

import { DisplayFormatter } from "../types/DisplayFormatter";
import { WidgetResponsePayload } from "../types/WidgetRestResponse";
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

export function formatDataByDisplay(displayFormatter: DisplayFormatter, datasets: Array<any>): Array<any> {

    for (const dataset of datasets) {

        const total = dataset.data.reduce((prev, curr) => prev + curr);
        switch (displayFormatter) {
            case DisplayFormatter.NONE:
            case DisplayFormatter.RAW: {
                break;
            }
            case DisplayFormatter.PERCENTAGE: {
                dataset.data = dataset.data.map(value => ((100 * value) / total));
                break;
            }
        }

    }

    return datasets;
}

export function formatDataByFormatter(displayFormatter: DisplayFormatter, value: number, total: number) {
    if (displayFormatter === DisplayFormatter.PERCENTAGE) {
        return (value / total) * 100;
    }
    return value;
}

export function normalizeDatasets(datasources: WidgetResponsePayload[], displayFormatter: DisplayFormatter) {

    const firstDatasource = datasources[0];

    let index = 0;

    const datasets = datasources.map(payload => {

        const total = payload.data.values.reduce((prev, curr) => prev + curr);
        
        return {label: payload.data.label, backgroundColor: COLOR_PALETTE[index++], data: payload.data.values.map(value => {
            if (displayFormatter === DisplayFormatter.PERCENTAGE) {
                return (value / total) * 100;
            }
            return value;
        })}
    });

    return {datasets: datasets, labels: firstDatasource.data.keys};
}