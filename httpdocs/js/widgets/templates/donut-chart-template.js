import PieChart from './pie-chart-template.js';

export default class DonutChartTemplate extends PieChart {
    constructor(params) {
        super(params);
        this._isDonut = true;
    }
}