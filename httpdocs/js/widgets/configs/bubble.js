/**
 * (C) 2013-21 - ntop.org
 * Default configuration to use with bubble charts.
 */

export default {
    dataset: {
		borderWidth: function(context) {
			return Math.min(Math.max(1, context.datasetIndex + 1), 8);
		},
		hoverBackgroundColor: 'transparent',
		hoverBackgroundColor: 'transparent',
		hoverBorderWidth: function(context) {
			const value = context.dataset.data[context.dataIndex];
			return Math.round(8 * value.v / 1000);
		},
	},
    options: {
        responsive: true,
        maintainAspectRatio: false,
        tooltips: {
            callbacks: {
                title: function(tooltipItem, data) {
                    return data['labels'][ tooltipItem[0]['index'] ];
                },
                label: function(tooltipItem, data) {
    
                    const dataset = data['datasets'][tooltipItem.datasetIndex];
                    const idx = tooltipItem['index'];
                    const datapoint = dataset['data'][idx];
    
                    if (datapoint) {
                        return (datapoint.label);
                    }
                    else {
                        return ('');
                    }
                }
            }
        },
        elements: {
            points: {
                borderWidth: 1,
                borderColor: 'rgb(0, 0, 0)'
            }
        },
        onClick: function(e) {
            
            const element = this.getElementAtEvent(e);
            const httpPrefix = http_prefix || location.origin;

            // if you click on at least 1 element ...
            if (element.length > 0) {
                const dataset = this.config.data.datasets[element[0]._datasetIndex];
                const data = dataset.data[element[0]._index];
                window.location.href = new URL(dataset.baseUrl + data.link, httpPrefix).toString(); // Jump to this host
            }
        },
    }
};