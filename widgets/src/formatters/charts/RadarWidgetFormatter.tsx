/**
 * (C) 2021 - ntop.org
*/

import { h } from '@stencil/core';
import { Chart, ChartConfiguration } from 'chart.js';
import { ChartFormatter, Formatter } from "../../types/Formatter";
import { WidgetResponsePayload } from '../../types/WidgetRestResponse';
import { DisplayFormatter } from "../../types/DisplayFormatter";
import { NtopWidget } from '../../components/ntop-widget/ntop-widget';
import { COLOR_PALETTE, formatLabel } from '../../utils/utils';

/**
 * Define a new chart formatter for Radar Charts.
 * See: https://www.chartjs.org/docs/master/charts/radar
 */
export default class RadarChartWidgetFormatter implements ChartFormatter {

    private _chart: Chart<'radar'>;
    private _parentWidget: NtopWidget;
    private _shadowRoot: ShadowRoot;

    constructor(widget: NtopWidget) {
        this._parentWidget = widget;
    } 

    public init(shadowRoot: ShadowRoot) { 

        this._shadowRoot = shadowRoot;

        const canvas: HTMLCanvasElement = shadowRoot.getElementById('chart') as HTMLCanvasElement;    
        const ctx = canvas.getContext('2d');
        
        const pieContainer: HTMLDivElement = shadowRoot.querySelector('.radar-container');
        pieContainer.style.width = this._parentWidget.width;
        pieContainer.style.height = this._parentWidget.height;
  
        const {datasets, labels} = this.buildDatasets();

        const config: ChartConfiguration<'radar'> = this.loadConfig(datasets, labels);
        this._chart = new Chart<'radar'>(ctx, config); 
    }

    private buildDatasets() {

        const datasources = this._parentWidget._fetchedData.rsp;
        const firstDatasource = datasources[0];
        const labels = firstDatasource.data.keys;

        let index = 0;

        const datasets = datasources.map(payload => {
            
            const selectedColor = COLOR_PALETTE[index++];
            const total = payload.data.values.reduce((prev, curr) => prev + curr);

            return {
                label: payload.data.label, 
                backgroundColor: selectedColor + '90', 
                borderColor: selectedColor, 
                pointBackgroundColor: selectedColor, 
                data: payload.data.values.map(value => {
                    
                    if (this._parentWidget.displayFormatter === DisplayFormatter.PERCENTAGE) {
                        return (value / total) * 100;
                    }

                    return value;
                }
            )}
        });

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

    protected loadConfig(datasets: any[], labels: string[]): ChartConfiguration<'radar'> {
        return {
            type: 'radar',
            data: {
                datasets: datasets,
                labels: labels
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: (tooltip) => {

                                const {label, dataset, dataPoint} = tooltip;
                                const values: number[] = dataset.data as number[];
                                const total: number = values.reduce((previousValue: number, currentValue: number) => {
                                    return previousValue + currentValue;
                                });

                                return `${label}${formatLabel(this._parentWidget.displayFormatter, dataPoint.r, total)}`;
                            }
                        }
                    }
                }
            }
        };
    }

    public chart() { return this._chart; }

    public staticRender() {
        return [<div class='radar-container'><canvas id='chart'></canvas></div>];
    }
}