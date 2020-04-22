import { ChartTemplate } from './default-template.js';

export default class PieChartTemplate extends ChartTemplate {

    constructor(params) {
        super(params);
        this._isDonut = false;
        this._intervalId = 0;
    }

    _addGraph(container) {

        const self = this;

        nv.addGraph(function() {

            const pieChart = nv.models.pieChart();
            pieChart.x(d => d.label);
            pieChart.y(d => d.value);
            pieChart.height(self._height);
            pieChart.width(self._width);
            pieChart.showTooltipPercent(true);
            pieChart.donut(self._isDonut);

            d3.select(container.getAttribute('id'))
                .datum(self._data)
                .transition().duration(1200)
                .attr('width', self._width)
                .attr('height', self._height)
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
        super._addGraph(container);

        return container;
    }

}