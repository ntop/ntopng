import { ChartTemplate } from './default-template.js';

export default class MultiBarChartTemplate extends ChartTemplate {

    constructor(params) { super(params); }

    _addGraph() {

        const self = this;
        nv.addGraph(function() {

            const multibarChart = nv.models.multiBarChart();
            multibarChart.height(self._height);
            multibarChart.width(self._width);
            multibarChart.stacked(true);

            d3.select(`#${self._defaultOptions.domId}`)
                .append('svg')
                .datum(self._data)
                .transition()
                .duration(1000)
                .call(multibarChart);

            if (self._defaultOptions.widget.intervalTime) {
               self._intervalId = setInterval(async function() {
                    const newData = await self._updateData();
                    self._data = newData.data;
                    multibarChart.update();
                }, self._defaultOptions.widget.intervalTime);
            }

            self._chart = multibarChart;

            return multibarChart;
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