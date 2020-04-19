import NtopWidgetTemplate from '../ntopWidgetTemplate.js';
export class ChartTemplate extends NtopWidgetTemplate {
    constructor(customType) {
        super();
        this.customType = customType;
    }
    render(data) {
        data.type = this.customType;
        const canvas = document.createElement('canvas');
        const ctx2d = canvas.getContext('2d');
        const chart = new Chart(ctx2d, data);
        this.chart = chart;
        return super.render(data).appendChild(canvas);
    }
    destroyChart() {
        if (!this.chart)
            throw new Error("The chart field cannot be null!");
        this.chart.destroy();
    }
}
