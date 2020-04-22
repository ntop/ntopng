import { ChartTemplate } from './default-template.js';

export default class PieChartTemplate extends ChartTemplate {

    constructor(params) {
        super(params);
        this._isDonut = false;
    }

    _addGraph() {

        const self = this;
        console.log(self);

        nv.addGraph(function() {

            const pieChart = nv.models.pieChart();

            pieChart.x(d => d.label);
            pieChart.y(d => d.value);
            pieChart.height(self._height);
            pieChart.width(self._width);
            pieChart.showTooltipPercent(true);
            pieChart.donut(self._isDonut);
            pieChart.labelType("percent");

            d3.select(`#${self._defaultOptions.domId}`)
                .append('svg')
                .datum(self._data.data)
                .transition()
                .duration(1000)
                .call(pieChart);

            if (self._defaultOptions.intervalTime) {
                self._intervalId = setInterval(function() {
                    // TODO: set interval callback
                    pieChart.update();
                }, self._defaultOptions.intervalTime);
            }

            self._chart = pieChart;
            return pieChart;
        });
    }

    render() {

        const container = super.render();
        container.setAttribute('style', `width:${this._width}px;height:${this._width}px`);
        this._addGraph();

        return container;
    }

}