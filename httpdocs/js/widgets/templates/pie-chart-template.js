import { ChartTemplate } from './default-template.js';

export default class PieChartTemplate extends ChartTemplate {

    constructor(params) {
        super(params);
        this._isDonut = false;
        console.log(this);
    }

    _addGraph() {

        const self = this;
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
            .append('b')
            .text(self._defaultOptions.widget.widgetFetchedData.title);

            d3.select(`#${self._defaultOptions.domId}`)
                .append('svg')
                .datum(self._data.data)
                .transition()
                .duration(1750)
                .call(pieChart);

            if (self._defaultOptions.widget.intervalTime) {
                self._intervalId = setInterval(async function() {
                    const newData = await self._updateData();
                    self._data = newData.data;
                    d3.select(`#${self._defaultOptions.domId}>svg`)
                        .datum(newData.data)
                        .transition()
                        .duration(1750)
                        .call(pieChart);
                }, self._defaultOptions.widget.intervalTime);
            }

            self._chart = pieChart;
            return pieChart;
        });
    }

    render() {

        const container = super.render();
        /* if I have no data to show then don't add the graph! */
        if (this._data.length != 0) {
            container.setAttribute('style', `width:${this._width}px;height:${this._width}px`);
            this._addGraph();
        }

        return container;
    }

}