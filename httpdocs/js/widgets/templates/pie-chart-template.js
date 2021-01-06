import { ChartTemplate } from './default-template.js';

export default class PieChartTemplate extends ChartTemplate {

    constructor(params) {
        super(params);
        this._isDonut = false;
    }

    _addGraph() {

        const self = this;
        if (self._defaultOptions.widget.widgetFetchedData === undefined) {
            return;
        }

        nv.addGraph(function() {

            const pieChart = nv.models.pieChart();

            // set the data label
            pieChart
                .x(d => d.k)
                .y(d => d.v);
            pieChart 
                .showTooltipPercent(true)
                .showLegend(false)
                .showLabels(true)     //Display pie labels
                .labelThreshold(.05)  //Configure the minimum slice size for labels to show up
                .labelType("key") //Configure what type of data to show in the label. Can be "key", "value" or "percent"
                .donut(true)          //Turn on Donut mode. Makes pie chart look tasty!
                .donutRatio(0.35)     //Configure how big you want the donut hole size to be.

            //pieChart.labelType("percent");

            const selectedChart = d3.select(`#${self._defaultOptions.domId}`);

            selectedChart
                .append('b')
                .text(self._defaultOptions.widget.widgetFetchedData.title || "Test Widget #" + self._defaultOptions.widget.widgetId);

            selectedChart
                .append('svg')
                .datum(self._data.rsp[0].data)
                .transition()
                .duration(1500)
                .attr("preserveAspectRatio", "xMidYMid")
                .call(pieChart);
    
            self._chart = pieChart;
            return pieChart;
        });
    }

    render() {

        const container = super.render();
        container.setAttribute('style', `width:${this._width}px; height:${this._width}px`);

        this._addGraph();
        return container;
    }

}