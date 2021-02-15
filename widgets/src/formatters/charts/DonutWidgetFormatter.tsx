/**
 * (C) 2021 - ntop.org
*/

import Chart from 'chart.js';

import PieWidgetFormatter from './PieWidgetFormatter';

/**
 * Define a new chart formatter for Donut Charts.
 * See: https://www.chartjs.org/docs/latest/charts/doughnut.html
 */
export default class DonutWidgetFormatter extends PieWidgetFormatter {

    /* Override the chart type. The pie and donut chart are the same. */
    protected loadConfig(datasets: any[], labels: string[]): Chart.ChartConfiguration<'pie' | 'doughnut'> {
        const config = super.loadConfig(datasets, labels);
        config.type = 'doughnut';
        return config;
    }
}