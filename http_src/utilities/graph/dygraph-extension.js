/**
		(C) 2023 - ntop.org
*/

/* Override Dygraph plugins to have a better legend */
Dygraph.Plugins.Legend.prototype.select = function (e) {
	var xValue = e.selectedX;
	var points = e.selectedPoints;
	var row = e.selectedRow;

	var legendMode = e.dygraph.getOption('legend');
	if (legendMode === 'never') {
		this.legend_div_.style.display = 'none';
		return;
	}

	var html = Dygraph.Plugins.Legend.generateLegendHTML(e.dygraph, xValue, points, this.one_em_width_, row);
	if (html instanceof Node && html.nodeType === Node.DOCUMENT_FRAGMENT_NODE) {
		this.legend_div_.innerHTML = '';
		this.legend_div_.appendChild(html);
	} else
		this.legend_div_.innerHTML = html;
	// must be done now so offsetWidth isn’t 0…
	this.legend_div_.style.display = '';

	if (legendMode === 'follow') {
		// create floating legend div
		var area = e.dygraph.plotter_.area;
		var labelsDivWidth = this.legend_div_.offsetWidth;
		var yAxisLabelWidth = e.dygraph.getOptionForAxis('axisLabelWidth', 'y');
		// find the closest data point by checking the currently highlighted series,
		// or fall back to using the first data point available
		var highlightSeries = e.dygraph.getHighlightSeries()
		var point;
		if (highlightSeries) {
			point = points.find(p => p.name === highlightSeries);
			if (!point)
				point = points[0];
		} else
			point = points[0];

		// determine floating [left, top] coordinates of the legend div
		// within the plotter_ area
		// offset 50 px to the right and down from the first selection point
		// 50 px is guess based on mouse cursor size
		const followOffsetX = e.dygraph.getNumericOption('legendFollowOffsetX');
		const x = (point?.x != null) ? point.x : 1;
		var leftLegend = x * area.w + followOffsetX;

		// if legend floats to end of the chart area, it flips to the other
		// side of the selection point
		if ((leftLegend + labelsDivWidth + 1) > area.w) {
			leftLegend = leftLegend - 2 * followOffsetX - labelsDivWidth - (yAxisLabelWidth - area.x);
		}

		this.legend_div_.style.left = yAxisLabelWidth + leftLegend + "px";
		document.addEventListener("mousemove", (e) => {
			localStorage.setItem('timeseries-mouse-top-position', e.clientY + 50 + "px")
		});
		this.legend_div_.style.top = localStorage.getItem('timeseries-mouse-top-position');
	} else if (legendMode === 'onmouseover' && this.is_generated_div_) {
		// synchronise this with Legend.prototype.predraw below
		var area = e.dygraph.plotter_.area;
		var labelsDivWidth = this.legend_div_.offsetWidth;
		this.legend_div_.style.left = area.x + area.w - labelsDivWidth - 1 + "px";
		this.legend_div_.style.top = area.y + "px";
	}
};