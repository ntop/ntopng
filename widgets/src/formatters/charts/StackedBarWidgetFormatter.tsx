/**
* (C) 2021 - ntop.org
*/

import { h } from "@stencil/core";
import { Chart, ChartConfiguration } from "chart.js";
import { NtopWidget } from "../../components/ntop-widget/ntop-widget";
import { ChartFormatter } from "../../types/Formatter";
import { normalizeDatasets, COLOR_PALETTE, formatDataByDisplay } from "../../utils/utils";

/**
* Define a new chart formatter for Bar Charts.
* See: https://www.chartjs.org/docs/latest/charts/bar.html
*/
export default class StackedBarWidgetFormatter implements ChartFormatter {

    private _parentWidget: NtopWidget;
    private _chart: Chart<'bar'>;
    private _shadowRoot: ShadowRoot;

    constructor(widget: NtopWidget) {
        this._parentWidget = widget;
    } 
    
    public chart(): Chart<'bar'> {
        return this._chart;
    }

    init(shadowRoot: ShadowRoot) {
        
        this._shadowRoot = shadowRoot;

        const barContainer: HTMLDivElement = shadowRoot.querySelector('.bar-container');
        barContainer.style.width = this._parentWidget.width;
        barContainer.style.height = this._parentWidget.height;

        const canvas: HTMLCanvasElement = shadowRoot.getElementById('chart') as HTMLCanvasElement;
        const ctx = canvas.getContext('2d');

        const {datasets, labels} = normalizeDatasets(this._parentWidget._fetchedData.rsp.datasources, this._parentWidget.displayFormatter);
        const config: ChartConfiguration<'bar'> = this.loadConfig(datasets, labels);

        this._chart = new Chart<'bar'>(ctx, config); 
    }


    update() {
        
        if (this._chart === undefined) {
            throw new Error("The chart has not been initialized!");
        }

        const {datasets, labels} = normalizeDatasets(this._parentWidget._fetchedData.rsp.datasources, this._parentWidget.displayFormatter);
        this._chart.data.datasets = datasets;
        this._chart.data.labels = labels;

        this._chart.update();
    }

    protected loadConfig(datasets: Array<any>, labels: Array<string>): ChartConfiguration<'bar'> {

        const formattedDatasets = formatDataByDisplay(this._parentWidget.displayFormatter, datasets);

        return {
            type: 'bar',
            data: {
                datasets: formattedDatasets,
                labels: labels
            },
            options: {
                maintainAspectRatio: false,
                scales: {
                    x: {
                        stacked: true
                    },
                    y: {
                        stacked: true
                    }
                }
            }
        }
    }

    staticRender() {
        return [<div class='bar-container'><canvas id='chart'></canvas></div>]
    }
}
