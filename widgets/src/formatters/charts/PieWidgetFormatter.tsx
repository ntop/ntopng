/**
 * (C) 2021 - ntop.org
*/

import { h } from '@stencil/core';
import { ActiveElement, Chart, ChartConfiguration, ChartEvent, TooltipItem } from 'chart.js';
import { ChartFormatter } from "../../types/Formatter";
import { NtopWidget } from '../../components/ntop-widget/ntop-widget';
import { COLOR_PALETTE, formatLabel } from '../../utils/utils';

/**
 * Define a new chart formatter for Pie Charts.
 * See: https://www.chartjs.org/docs/latest/charts/doughnut.html
 */
export default class PieWidgetFormatter implements ChartFormatter {

    private _chart: Chart<'pie' | 'doughnut'>;
    private _parentWidget: NtopWidget;
    private _shadowRoot: ShadowRoot;

    constructor(widget: NtopWidget) {
        this._parentWidget = widget;
    } 

    public chart(): Chart<'pie' | 'doughnut'> {
        return this._chart;
    }

    public init(shadowRoot: ShadowRoot) { 

        this._shadowRoot = shadowRoot;

        const canvas: HTMLCanvasElement = shadowRoot.getElementById('chart') as HTMLCanvasElement;    
        const ctx = canvas.getContext('2d');
        
        const pieContainer: HTMLDivElement = shadowRoot.querySelector('.pie-container');
        pieContainer.style.width = this._parentWidget.width;
        pieContainer.style.height = this._parentWidget.height;
  
        const {datasets, labels} = this.buildDatasets();

        const config: ChartConfiguration<'pie' | 'doughnut'> = this.loadConfig(datasets, labels);
        this._chart = new Chart<'pie' | 'doughnut'>(ctx, config); 
    }

    private buildDatasets() {

        const restResponse = this._parentWidget._fetchedData.rsp.datasources;
        const firstDatasource = restResponse[0];

        const labels = firstDatasource.data.keys;
        const datasets = [{
            data: firstDatasource.data.values,
            label: firstDatasource.data.label,
            backgroundColor: firstDatasource.data.colors || COLOR_PALETTE
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

    protected loadConfig(datasets: any[], labels: string[]): ChartConfiguration<'pie' | 'doughnut'> {

        return {
            type: 'pie',
            data: {
                datasets: datasets,
                labels: labels
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: {
                    animateRotate: false
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'left'
                    },
                    tooltip: {
                        callbacks: {
                            label: (tooltip: TooltipItem<'pie' | 'doughnut'>) => {

                                const {label, dataset, parsed} = tooltip;
                                const values: number[] = dataset.data as number[];
                                const total: number = values.reduce((previousValue: number, currentValue: number) => {
                                    return previousValue + currentValue;
                                });
    
                                return `${label}${formatLabel(this._parentWidget.displayFormatter, parsed, total)}`;
                            }
                        }
                    }
                },
                onClick: (_: ChartEvent, __: ActiveElement[]) => {
                    const restResponse = this._parentWidget._fetchedData.rsp;
                    if (restResponse[0].metadata.url !== undefined) {
                        window.location.href = restResponse[0].metadata.url;
                    }
                },
            }
        };
    }

    public staticRender() {
        return [<div class='pie-container'><canvas id='chart'></canvas></div>];
    }
}