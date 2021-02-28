/**
 * (C) 2021 - ntop.org
*/

import { h } from '@stencil/core';
import { Chart, ChartConfiguration, TooltipItem, TooltipModel } from 'chart.js';
import { ChartFormatter, Formatter } from "../../types/Formatter";
import { NtopWidget } from '../../components/ntop-widget/ntop-widget';
import { COLOR_PALETTE } from '../../utils/utils';

/**
 * Define a new chart formatter for Matrix Charts.
 * TODO: to finish.
 * See: https://www.npmjs.com/package/chartjs-chart-matrix
 * https://www.chartjs.org/docs/next/configuration/legend
 */
export default class MatrixWidgetFormatter implements ChartFormatter {
    
    private _chart: Chart<'matrix'>;
    private _parentWidget: NtopWidget;
    private _shadowRoot: ShadowRoot;

    constructor(widget: NtopWidget) {
        this._parentWidget = widget;
    } 

    public init(shadowRoot: ShadowRoot) { 

        this._shadowRoot = shadowRoot;

        const canvas: HTMLCanvasElement = shadowRoot.getElementById('chart') as HTMLCanvasElement;    
        const ctx = canvas.getContext('2d');
        
        const pieContainer: HTMLDivElement = shadowRoot.querySelector('.matrix-container');
        pieContainer.style.width = this._parentWidget.width;
        pieContainer.style.height = this._parentWidget.height;
  
        const {datasets, labels} = this.buildDatasets();

        const config: ChartConfiguration<'matrix'> = this.loadConfig(datasets, labels);
        this._chart = new Chart<'matrix'>(ctx, config); 
    }

    private buildDatasets() {

        const restResponse = this._parentWidget._fetchedData.rsp;
        const firstDatasource = restResponse[0];

        const labels = firstDatasource.data.keys;
        const datasets = [{
            data: firstDatasource.data.values,
            label: firstDatasource.data.label,
            backgroundColor: COLOR_PALETTE
        }];

        return {datasets: datasets, labels: labels};
    }

    public update() {

        if (this._chart === undefined) {
            throw new Error("The chart has not been initialized!");
        }

        const {datasets, labels} = this.buildDatasets();

        this._chart.data.datasets = datasets;
        this._chart.data.labels = labels;

        this._chart.update();
    }

    protected loadConfig(datasets: any[], labels: string[]): ChartConfiguration<'matrix'> {
        return {
            type: 'matrix',
            data: {
                datasets: datasets,
                labels: labels
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
						display: false
                    },
                    tooltip: {
                        callbacks: {
                            title: () => '',
                            label: (item: TooltipItem) => {
                                console.log(item);
                                const data = item.chart.data;
                                const v: any = data.datasets[item.datasetIndex].data[item.dataIndex];
                                return ["x: " + v.x, "y: " + v.y, "v: " + v.v];
                            }
                        }
                    },
                },
                scales: {
                    x: {
                        ticks: {
                            display: true,
                            stepSize: 1,
                        },
                        gridLines: {
                            display: false,
                        },
                        afterBuildTicks: (scale) => {
                            return scale.ticks.slice(1, 4);
                        }
                    },
                    y: {
                        ticks: {
                            display: true,
                            stepSize: 1
                        },
                        gridLines: {
                            display: false
                        },
                        afterBuildTicks: (scale) => {
                            return scale.ticks.slice(1, 4);
                        }
                    }
                }
            },
        };
    }

    public chart(): Chart<'matrix'> { return this._chart; }

    public staticRender() {
        return [<div class='matrix-container'><canvas id='chart'></canvas></div>];
    }


}