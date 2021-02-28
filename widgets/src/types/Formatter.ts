/**
 * (C) 2021 - ntop.org
*/

import { Chart } from "chart.js";

export interface Formatter { 

    staticRender: () => HTMLElement | Array<HTMLElement>; 

    /**
     * Initialize the formatter with the data provided.
     */
    init: (shadowRoot: ShadowRoot) => void;

    /**
     * Update the formatter with the data provided.
     */
    update: () => void;
}

export interface ChartFormatter extends Formatter {

    chart: () => Chart;

}