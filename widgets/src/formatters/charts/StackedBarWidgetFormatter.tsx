/**
* (C) 2021 - ntop.org
*/

import { h } from "@stencil/core";
import { Chart, ChartConfiguration } from "chart.js";
import { NtopWidget } from "../../components/ntop-widget/ntop-widget";
import { DisplayFormatter } from "../../types/DisplayFormatter";
import { ChartFormatter } from "../../types/Formatter";
import { COLOR_PALETTE } from "../../utils/utils";

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

        const {datasets, labels} = this.buildDatasets();
        const config: ChartConfiguration<'bar'> = this.loadConfig(datasets, labels);

        this._chart = new Chart<'bar'>(ctx, config); 
    }

    private buildDatasets() {
        
        const datasources = this._parentWidget._fetchedData.rsp;
        const firstDatasource = datasources[0];

        let index = 0;

        const datasets = datasources.map(payload => {
            const total = payload.data.values.reduce((prev, curr) => prev + curr);
            return {label: payload.data.label, backgroundColor: COLOR_PALETTE[index++], data: payload.data.values.map(value => {
                if (this._parentWidget.displayFormatter === DisplayFormatter.PERCENTAGE) {
                    return (value / total) * 100;
                }
                return value;
            })}
        });

        return {datasets: datasets, labels: firstDatasource.data.keys};
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

    protected loadConfig(datasets: Array<any>, labels: Array<string>): ChartConfiguration<'bar'> {

        const formattedDatasets = this.formatDataByDisplay(datasets);

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

    private formatDataByDisplay(datasets: Array<any>): Array<any> {

        for (let dataset of datasets) {

            const total = dataset.data.reduce((prev, curr) => prev + curr);
            switch (this._parentWidget.displayFormatter) {
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

}
