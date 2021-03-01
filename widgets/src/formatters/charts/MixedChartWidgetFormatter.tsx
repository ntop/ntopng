/**
 * (C) 2021 - ntop.org
*/

import { h } from '@stencil/core';
import { Chart, ChartConfiguration } from 'chart.js';
import { NtopWidget } from '../../components/ntop-widget/ntop-widget';
import { DisplayFormatter } from '../../types/DisplayFormatter';
import { ChartFormatter } from '../../types/Formatter';
import { COLOR_PALETTE, formatDataByFormatter, formatLabel } from '../../utils/utils';

export default class MixedChartWidgetFormatter implements ChartFormatter {

    private _chart: Chart<'line'>;
    private _parentWidget: NtopWidget;
    private _shadowRoot: ShadowRoot;

    constructor(widget: NtopWidget) {
        this._parentWidget = widget;
    } 
    
    public chart(): Chart<'line'> {
        return this._chart;
    }

    init(shadowRoot: ShadowRoot) {
        
        const mixedChartContainer: HTMLDivElement = shadowRoot.querySelector('.mixed-chart');
        mixedChartContainer.style.width = this._parentWidget.width;
        mixedChartContainer.style.height = this._parentWidget.height;

        const canvas: HTMLCanvasElement = shadowRoot.getElementById('chart') as HTMLCanvasElement;    
        const ctx = canvas.getContext('2d');

        const {datasets, labels} = this.buildDatasets();

        const config: ChartConfiguration<'line'> = this.loadConfig(datasets, labels);
        this._chart = new Chart<'line'>(ctx, config);
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

    staticRender() {
        return [<div class='mixed-chart'><canvas id='chart'></canvas></div>];
    }

    private buildDatasets() {

        const datasources = this._parentWidget._fetchedData.rsp.datasources;
        const firstDatasource = datasources[0];

        let index = 0;

        const datasets = datasources.map(payload => {

            const i = index++;
            const total = payload.data.values.reduce((prev, curr) => prev + curr);
            const ntopDatasource = this._parentWidget._containedDatasources[i];
            const style = ntopDatasource.styles as any;

            const dataset: any = {
                label: payload.data.label, 
                type: ntopDatasource.type,
                tension: 0,
                fill: true,
                data: payload.data.values.map(value => formatDataByFormatter(this._parentWidget.displayFormatter, value, total)),
            }

            if (style.fill !== undefined && !style.fill) {
                dataset.borderColor = COLOR_PALETTE[i];
            }
            else {
                dataset.backgroundColor = COLOR_PALETTE[i]; 
            }

            return Object.assign(ntopDatasource.styles, dataset);
        });

        return {datasets: datasets, labels: firstDatasource.data.keys};
    }

    private loadConfig(datasets: any[], labels: string[]): ChartConfiguration<'line'> {
        return {
            type: 'line',
            data: {
                datasets: datasets,
                labels: labels
            },
            options: {
                responsive: true,
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: (tooltip) => {

                                const {label, dataset, dataIndex} = tooltip;
                                const values: number[] = dataset.data as number[];
                                const total: number = values.reduce((previousValue: number, currentValue: number) => {
                                    return previousValue + currentValue;
                                });
                                const dataPoint = dataset.data[dataIndex] as number;

                                return `${label}${formatLabel(this._parentWidget.displayFormatter, dataPoint, total)}`;
                            }
                        }
                    }
                }
            }
        }
    }

}