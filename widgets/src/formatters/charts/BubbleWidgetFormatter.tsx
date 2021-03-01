/**
* (C) 2021 - ntop.org
*/

import { h } from "@stencil/core";
import { BubbleDataPoint, Chart, ChartConfiguration } from "chart.js";
import { NtopWidget } from "../../components/ntop-widget/ntop-widget";
import { DisplayFormatter } from "../../types/DisplayFormatter";
import { ChartFormatter } from "../../types/Formatter";
import { normalizeDatasets, COLOR_PALETTE, formatDataByDisplay } from "../../utils/utils";

/**
* Define a new chart formatter for Bubble Charts.
* See: https://www.chartjs.org/docs/latest/charts/bubble.html
*/
export default class BubbleWidgetFormatter implements ChartFormatter {

    private _parentWidget: NtopWidget;
    private _chart: Chart<'bubble'>;
    private _shadowRoot: ShadowRoot;

    constructor(widget: NtopWidget) {
        this._parentWidget = widget;
    } 
    
    public chart(): Chart<'bubble'> {
        return this._chart;
    }

    init(shadowRoot: ShadowRoot) {
        
        this._shadowRoot = shadowRoot;

        const bubbleContainer: HTMLDivElement = shadowRoot.querySelector('.bubble-container');
        bubbleContainer.style.width = this._parentWidget.width;
        bubbleContainer.style.height = this._parentWidget.height;

        const canvas: HTMLCanvasElement = shadowRoot.getElementById('chart') as HTMLCanvasElement;
        const ctx = canvas.getContext('2d');

        const {datasets, labels} = this.buildDatasets();
        console.log(datasets)

        const config = this.loadConfig(datasets, labels);

        this._chart = new Chart<'bubble'>(ctx, config as ChartConfiguration<'bubble'>); 
    }

    update() {
        
        if (this._chart === undefined) {
            throw new Error("The chart has not been initialized!");
        }

        const {datasets, labels} = this.buildDatasets();

        this._chart.data.datasets = datasets;
        this._chart.data.labels = labels;

        this._chart.update();
    }

    private buildDatasets() {
        
        const datasources = this._parentWidget._fetchedData.rsp.datasources;
        const firstDatasource = datasources[0];

        let index = 0;

        const datasets = datasources.map(payload => {

            const total = payload.data.values.reduce((prev, curr) => prev + curr);
            
            // TODO: remove current fake data
            return { label: payload.data.label, backgroundColor: COLOR_PALETTE[index++], data: [
                {x: 1, y: 1, r: 10},
                {x: 2, y: 2, r: 10},
                {x: 3, y: 3, r: 10},
            ]}
        });

        return {datasets: datasets, labels: firstDatasource.data.keys};
    }

    protected loadConfig(datasets: Array<any>, labels: Array<string>): ChartConfiguration {

        const formattedDatasets = formatDataByDisplay(this._parentWidget.displayFormatter, datasets);
        const response = this._parentWidget._fetchedData.rsp;

        return {
            type: 'bubble',
            data: {
                datasets: formattedDatasets,
                labels: labels,
            },
            options: {
                maintainAspectRatio: false,
                animations: {
                },
                scales: {
                    x: {
                        scaleLabel: {
                            display: (response.axes.x != null),
                            labelString: response.axes.x
                        }
                    },
                    y: {
                        scaleLabel: {
                            display: (response.axes.y != null),
                            labelString: response.axes.y
                        }
                    }
                }
            }
        }
    }

    staticRender() {
        return [<div class='bubble-container'><canvas id='chart'></canvas></div>]
    }
}
