import { ChartTemplate } from './default-template.js';

export default class TimeseriesChartTemplate extends ChartTemplate {

    constructor(params) { super(params); console.log(this); }

    _addGraph() {

        const self = this;
        nv.addGraph(function() {

            const timeseriesChart = nv.models.timeseriesChart();
            timeseriesChart.height(self._height);
            timeseriesChart.width(self._width);
            timeseriesChart.stacked(true);

            d3.select(`#${self._defaultOptions.domId}`)
                .append('svg')
                .datum(self._data.data)
                .transition()
                .duration(1000)
                .call(timeseriesChart);

            if (self._defaultOptions.widget.intervalTime) {
               self._intervalId = setInterval(async function() {
                    const newData = await self._updateData();
                    self._data = newData.data;
                    timeseriesChart.update();
                }, self._defaultOptions.widget.intervalTime);
            }

            self._chart = timeseriesChart;

            return timeseriesChart;
        });
    }

    render() {

        const container = super.render();
        /* if I have data to show then add the graph! */
        if (this._data.length != 0) {
            container.setAttribute('style', `width:${this._width}px;height:${this._width}px`);
            this._addGraph();
        }
        return container;
    }

}