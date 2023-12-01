/**
		(C) 2022 - ntop.org
*/

import formatterUtils from "./formatter-utils";
import colorsInterpolation from "./colors-interpolation";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const constant_serie_colors = {
	"95_perc": "#8EA4E8",
	"avg": "#839BE6",
}

function getSerieId(serie) {
	return `${serie.id}`;
}

function getSerieName(name, id, tsGroup, useFullName) {
	if (name == null) {
		name = id;
	}
	let name_more_space = "";
	if (name != null) {
		name_more_space = `${name}`;
	}
	if (useFullName == false) {
		return name;
	}
	let source_index = getMainSourceDefIndex(tsGroup);
	let source = tsGroup.source_array[source_index];
	let prefix = `${source.label}`;
	return `${prefix} - ${name_more_space}`;
}

function getYaxisId(metric) {
	return `${metric.measure_unit}_${metric.scale}`;
}

const defaultColors = [
	"#C6D9FD",
	"#90EE90",
	"#EE8434",
	"#C95D63",
	"#AE8799",
	"#717EC3",
	"#496DDB",
	"#5A7ADE",
	"#6986E1",
	"#7791E4",
	"#839BE6",
	"#8EA4E8",
];

function setSeriesColors(palette_list) {
	let colors_list = palette_list;
	let count0 = 0, count1 = 0;
	let colors0 = defaultColors;
	let colors1 = d3v7.schemeCategory10;
	colors_list.forEach((s, index) => {
		if (s.palette == 0) {
			palette_list[index] = colors0[count0 % colors0.length];
			count0 += 1;
		} else if (s.palette == 1) {
			palette_list[index] = colors1[count1 % colors1.length];
			count1 += 1;
		}
	});
}

const groupsOptionsModesEnum = {
	'1_chart_x_metric': { value: "1_chart_x_metric", label: i18n('page_stats.layout_1_per_1') },
	'1_chart_x_yaxis': { value: "1_chart_x_yaxis", label: i18n('page_stats.layout_1_per_y') },
}

function getGroupOptionMode(group_id) {
	return groupsOptionsModesEnum[group_id] || null;
};

/* This function is going to translate the response sent from the server to the formatted data needed from the chart library */
function tsArrayToOptionsArray(tsOptionsArray, tsGroupsArray, groupsOptionsMode, tsCompare) {
	/* One chart per metric requested */
	if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_metric"].value) {
		return tsArrayToOptionsArrayRaw(tsOptionsArray, tsGroupsArray, groupsOptionsMode, tsCompare);
	}
	let splittedTsArray = splitTsArrayStacked(tsOptionsArray, tsGroupsArray);
	let DygraphOptionsStacked = tsArrayToOptionsArrayRaw(splittedTsArray.stacked.tsOptionsArray, splittedTsArray.stacked.tsGroupsArray, groupsOptionsMode, tsCompare);
	let DygraphOptionsNotStacked = tsArrayToOptionsArrayRaw(splittedTsArray.not_stacked.tsOptionsArray, splittedTsArray.not_stacked.tsGroupsArray, groupsOptionsMode, tsCompare);
	//console.log([...DygraphOptionsStacked, ...DygraphOptionsNotStacked])
	return [...DygraphOptionsStacked, ...DygraphOptionsNotStacked];
}

function splitTsArrayStacked(tsOptionsArray, tsGroupsArray) {
	let tsOptionsArrayStacked = [];
	let tsGroupsArrayStacked = [];
	let tsOptionsArrayNotStacked = [];
	let tsGroupsArrayNotStacked = [];
	tsGroupsArray.forEach((tsGroup, i) => {
		if (tsGroup.metric.draw_stacked == true) {
			tsOptionsArrayStacked.push(tsOptionsArray[i]);
			tsGroupsArrayStacked.push(tsGroup);
		} else {
			tsOptionsArrayNotStacked.push(tsOptionsArray[i]);
			tsGroupsArrayNotStacked.push(tsGroup);
		}
	});
	return {
		stacked: {
			tsOptionsArray: tsOptionsArrayStacked,
			tsGroupsArray: tsGroupsArrayStacked,
		},
		not_stacked: {
			tsOptionsArray: tsOptionsArrayNotStacked,
			tsGroupsArray: tsGroupsArrayNotStacked,
		},
	};
}

function tsArrayToOptionsArrayRaw(tsOptionsArray, tsGroupsArray, groupsOptionsMode, tsCompare) {
	let useFullName = false;
	if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_yaxis"].value) {
		let tsDict = {};
		tsGroupsArray.forEach((tsGroup, i) => {
			let yaxisId = getYaxisId(tsGroup.metric);
			let tsEl = { tsGroup, tsOptions: tsOptionsArray[i] };
			if (tsDict[yaxisId] == null) {
				tsDict[yaxisId] = [tsEl];
			} else {
				tsDict[yaxisId].push(tsEl);
			}
		});
		useFullName = tsGroupsArray.length > 1 || (tsGroupsArray.length > 0
			&& tsGroupsArray[0].source_type.display_full_name === true);
		let DygraphOptionsArray = [];
		for (let key in tsDict) {
			let tsArray = tsDict[key];
			let tsOptionsArray2 = tsArray.map((ts) => ts.tsOptions);
			let tsGroupsArray2 = tsArray.map((ts) => ts.tsGroup);
			let DygraphOptions = tsArrayToOptions(tsOptionsArray2, tsGroupsArray2, tsCompare, useFullName);
			DygraphOptionsArray.push(DygraphOptions);
		}
		return DygraphOptionsArray;
	} else if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_metric"].value) {
		useFullName = tsOptionsArray.length > 1 || (tsGroupsArray.length > 0
			&& tsGroupsArray[0].source_type.display_full_name === true);
		let optionsArray = [];
		tsOptionsArray.forEach((tsOptions, i) => {
			let options = tsArrayToOptions([tsOptions], [tsGroupsArray[i]], tsCompare, useFullName);
			optionsArray.push(options);
		});
		return optionsArray;
	}
	return [];
}

function formatSerieProperties(type) {
	if (type == "point") {
		return {
			fillGraph: false,
			customBars: false,
			strokeWidth: 0.0,
			pointSize: 2.0,
		}
	} else if (type == "line") {
		return {
			fillGraph: false,
			customBars: false,
			strokeWidth: 1.5,
			pointSize: 1.5,
		}
	} else if (type == "bounds") {
		return {
			fillGraph: false,
			strokeWidth: 1.0,
			pointSize: 1.5,
			fillAlpha: 0.5
		}
	} else {
		return {
			fillGraph: true,
			customBars: false,
			strokeWidth: 1.0,
			pointSize: 1.5,
			fillAlpha: 0.5
		}
	}
}

function formatBoundsSerie(series, series_info) {
	let formatted_serie = [];
	let color_palette = {};
	let formatter = null;
	let serie_name = null;
	let serie_properties = {}
	series.forEach((ts_info, j) => {
		let scalar = 1;
		let ts_id = timeseriesUtils.getSerieId(ts_info);
		const serie = ts_info.data || []; /* Safety check */
		let s_metadata = series_info.metric.timeseries[ts_id];

		if (s_metadata.invert_direction == true) {
			scalar = -1;
		}

		if (s_metadata.type == "metric") {
			let name = s_metadata.label
			serie_name = getSerieName(name, ts_id, series_info, true)
			serie_properties = formatSerieProperties('bounds');

			color_palette = { color: s_metadata.color, palette: 0 };
			formatter = series_info.metric.measure_unit;
		}

		for (let point = 0; point < serie.length; point++) {
			let serie_point = serie[point]
			if (serie_point == null)
				serie_point = NaN;
			if (formatted_serie[point] == null) {
				formatted_serie[point] = [0, NaN, 0];
			}

			if (s_metadata.type == "metric") {
				formatted_serie[point][1] = serie_point * scalar;
			} else if (s_metadata.type == "lower_bound") {
				formatted_serie[point][0] = serie_point * scalar;
			} else if (s_metadata.type == "upper_bound") {
				formatted_serie[point][2] = serie_point * scalar;
			}
		}
	})

	return { serie: formatted_serie, color: color_palette, formatter: formatter, serie_name: serie_name, properties: serie_properties };
}

/* Given an array of timeseries, it compacts them into a single array */
function tsArrayToOptions(tsOptionsArray, tsGroupsArray, tsCompare, useFullName) {
	if (tsOptionsArray.length != tsGroupsArray.length) {
		console.error(`Error in timeseries-utils:tsArrayToOptions: tsOptionsArray ${tsOptionsArray} different length from tsGroupsArray ${tsGroupsArray}`);
		return;
	}
	let formatted_serie = [];
	let formatters = []
	let serie_labels = ["Time"];
	let stacked = false;
	let colors = [];
	let colors_palette = [];
	let serie_properties = {};
	let customBars = false;
	let use_full_name = (useFullName != null) ? useFullName : false;

	/* Go throught each serie */
	tsOptionsArray.forEach((tsOptions, i) => {
		/* Format the data */
		/* the data in Dygraphs should be formatted as follow:
		 * { [ time_1, serie1_1, serie2_1 ], [ time_2, serie1_2, serie2_2 ] } 
		 */

		const series = tsOptions.series || [];
		const epoch_begin = tsOptions.metadata.epoch_begin
		const step = tsOptions.metadata.epoch_step
		const past_serie = tsOptions.additional_series
		const bounds = tsGroupsArray[i].metric.bounds || false;

		/* The serie can possibly have multiple timeseries, like for the 
		 * bytes, we have sent and rcvd, so compact them 
		 */
		if (bounds == true) {
			/* TODO: add avg, past, ecc. timeseries to the bounds one */
			customBars = true;
			let time = epoch_begin;
			const { serie, color, formatter, serie_name, properties } = formatBoundsSerie(series, tsGroupsArray[i], time, step);
			colors_palette.push(color);
			const found = formatters.find(el => el == formatter);
			if (found == null)
				formatters.push(formatter);
			const formatted_name = `${serie_name} ${i18n('lower_value_upper')}`
			serie_labels.push(formatted_name);
			serie_properties[formatted_name] = {}
			serie_properties[formatted_name] = properties;
			const serie_keys = Object.keys(serie);
			serie_keys.forEach((key, j) => {
				const ts_info = serie[key];
				if (formatted_serie[time] == null)
					formatted_serie[time] = [
						{ value: new Date(time * 1000), name: "Time" },
						{ value: ts_info, name: formatted_name }
					]

				time = time + step;
			});
		} else {
			series.forEach((ts_info, j) => {
				const serie = ts_info.data || []; /* Safety check */
				let time = epoch_begin;

				let ts_id = timeseriesUtils.getSerieId(ts_info);
				let s_metadata = tsGroupsArray[i].metric.timeseries[ts_id];
				let extra_timeseries = tsGroupsArray[i].timeseries[j];
				let scalar = 1;
				let name = s_metadata.label

				if (s_metadata.hidden) {
					return;
				}

				if (s_metadata.use_serie_name == true) {
					name = ts_info.name;
				}

				if (stacked == false) {
					stacked = tsGroupsArray[i].metric.draw_stacked;
				}

				if (s_metadata.invert_direction == true) {
					scalar = -1;
				}
				colors_palette.push({ color: s_metadata.color, palette: 0 });
				/* Search for the formatter in the array, if not found, add it. */
				const found = formatters.find(el => el == tsGroupsArray[i].metric.measure_unit);
				if (found == null) {
					formatters.push(tsGroupsArray[i].metric.measure_unit);
				}

				if (ts_info.ext_label) {
					name = ts_info.ext_label
				}

				/* ************************************** */

				const serie_name = getSerieName(name, ts_id, tsGroupsArray[i], use_full_name)
				const avg_label = getSerieName(name + " Avg", ts_id, tsGroupsArray[i], use_full_name)
				const perc_label = getSerieName(name + " 95th Perc", ts_id, tsGroupsArray[i], use_full_name);
				const past_label = getSerieName(name + " " + tsCompare + " Ago", ts_id, tsGroupsArray[i], use_full_name);
				/* Add the serie label to the array of the labels */
				serie_labels.push(serie_name);

				serie_properties[serie_name] = {}
				serie_properties[serie_name] = formatSerieProperties(ts_info.type || 'filled');

				/* ************************************** */

				/* Adding the extra timeseries, 30m ago, avg and 95th */
				if (extra_timeseries?.avg == true) {
					/* Add the serie label to the array of the labels */
					serie_labels.push(avg_label);

					serie_properties[avg_label] = {}
					serie_properties[avg_label] = formatSerieProperties("point");
					colors_palette.push({ color: constant_serie_colors["avg"], palette: 1 });
				}

				if (extra_timeseries?.perc_95 == true) {
					/* Add the serie label to the array of the labels */
					serie_labels.push(perc_label);

					serie_properties[perc_label] = {}
					serie_properties[perc_label] = formatSerieProperties("point");
					colors_palette.push({ color: constant_serie_colors["perc_95"], palette: 1 });
				}
				if (extra_timeseries?.past == true) {
					/* Add the serie label to the array of the labels */
					serie_labels.push(past_label);

					serie_properties[past_label] = {}
					serie_properties[past_label] = formatSerieProperties("line");
					colors_palette.push({ color: constant_serie_colors["past"], palette: 1 });
				}

				/* ************************************** */

				for (let point = 0; point < serie.length; point++) {
					const serie_point = serie[point];
					/* If the point is inserted for the first time, add the time before everything else */
					if (formatted_serie[time] == null) {
						formatted_serie[time] = [{ value: new Date(time * 1000), name: "Time" }];
					}
					/* Add the point to the array */
					if (serie_point != null) {
						formatted_serie[time].push({ value: serie_point * scalar, name: serie_name });
					} else {
						formatted_serie[time].push({ value: NaN, name: serie_name });
					}

					/* Add extra series, avg, 95th and past timeseries */
					if (extra_timeseries?.avg == true) {
						formatted_serie[time].push({ value: ts_info.statistics["average"] * scalar, name: avg_label });
					}
					if (extra_timeseries?.perc_95 == true) {
						formatted_serie[time].push({ value: ts_info.statistics["95th_percentile"] * scalar * scalar, name: perc_label });
					}
					if (extra_timeseries?.past == true) {
						for (const key in past_serie) {
							if (past_serie[key]?.series[j]?.data[point]) {
								formatted_serie[time].push({ value: past_serie[key]?.series[j]?.data[point] * scalar, name: past_label });
							} else {
								formatted_serie[time].push({ value: NaN, name: past_label });
							}
						}
					}

					/* Increase the time using the step */
					time = time + step;
				}
			})
		}
	});
	/* Need to finally format the serie as requested by Dygraph, with
		 NULL as value in case the serie has NOT THAT POINT (e.g. with a 5 minutes frequency, the user
			is confronting a chart with 1 minute frequency, there are 4 minutes with no existing points)
	 */
	let full_serie = [];
	const serie_keys = Object.keys(formatted_serie);
	serie_keys.forEach((key, index) => {
		full_serie[index] = [];
		/* Iterate the serie and for each label, get the value and set to null in case it does not exists */
		serie_labels.forEach((label) => {
			let found = false;
			for (let j = 0; j < formatted_serie[key].length; j++) {
				if (formatted_serie[key][j].name == label) {
					full_serie[index].push(formatted_serie[key][j].value);
					found = true;
					break;
				}
			}
			if (found == false) {
				full_serie[index].push(null);
			}
		})
	});
	setSeriesColors(colors_palette)

	let chartOptions = buildChartOptions(full_serie, serie_labels, serie_properties, formatters, colors_palette, stacked, customBars);
	return chartOptions;
}

function getAxisConfiguration(formatter) {
	return {
		axisLabelFormatter: formatter,
		valueFormatter: function (num_or_millis, opts, seriesName, dygraph, row, col) {
			const serie_point = dygraph.rawData_[row][col];
			let data = '';
			if (typeof (serie_point) == "object") {
				serie_point.forEach((el) => {
					data = `${data} / ${formatter(el || 0)}`;
				})
				data = data.substring(3); /* Remove the first three characters ' / ' */
			} else {
				data = formatter(num_or_millis);
			}
			return (data);
		},
		axisLabelWidth: 80,
	}
}

function buildChartOptions(series, labels, serie_properties, formatters, colors, stacked, customBars) {
	const interpolated_colors = colorsInterpolation.transformColors(colors);
	let is_dark_mode = document.getElementsByClassName('body dark').length > 0;
	let highlight_color = 'rgb(255, 255, 255)';
	if (is_dark_mode) {
		highlight_color = 'rgb(13, 17, 23)';
	}

	let config = {
		customBars: customBars,
		labels: labels,
		series: serie_properties,
		data: series,
		labelsSeparateLines: true,
		legend: "follow",
		stackedGraph: stacked, /* TODO. add stacked here */
		connectSeparatedPoints: true,
		includeZero: true,
		drawPoints: true,
		highlightSeriesBackgroundAlpha: 0.7,
		highlightSeriesBackgroundColor: highlight_color,
		highlightSeriesOpts: {
			strokeWidth: 2,
			pointSize: 3,
			highlightCircleSize: 6,
		},
		axisLabelFontSize: 12,
		axes: {
			x: {}
		},
		colors: interpolated_colors,
	};

	if (formatters.length > 1) {
		/* Multiple formatters */
		/* NOTE: at most 2 formatters can be used */
		config.axes.y1 = getAxisConfiguration(formatterUtils.getFormatter(formatters[0]));
		config.axes.y2 = getAxisConfiguration(formatterUtils.getFormatter(formatters[1]));
	} else if (formatters.length == 1) {
		/* Single formatter */
		config.axes.y = getAxisConfiguration(formatterUtils.getFormatter(formatters[0]));
	}

	return config;
}

function getTsQuery(tsGroup, not_metric_query, enable_source_def_value_dict) {
	let tsQuery = tsGroup.source_type.source_def_array.map((source_def, i) => {
		if (enable_source_def_value_dict != null && !enable_source_def_value_dict[source_def.value]) { return null; }
		let source_value = tsGroup.source_array[i].value;
		return `${source_def.value}:${source_value}`;
	}).filter((s) => s != null).join(",");

	if (!not_metric_query && tsGroup.metric.query != null) {
		tsQuery = `${tsQuery},${tsGroup.metric.query}`
	}
	return tsQuery;
}

function getMainSourceDefIndex(tsGroup) {
	let source_def_array = tsGroup.source_type.source_def_array;
	for (let i = 0; i < source_def_array.length; i += 1) {
		let source_def = source_def_array[i];
		if (source_def.main_source_def == true) { return i; }
	}
	return 0;

}

async function getTsChartsOptions(httpPrefix, epochStatus, tsCompare, timeseriesGroups, isPro) {
	let paramsEpochObj = { epoch_begin: epochStatus.epoch_begin, epoch_end: epochStatus.epoch_end };

	let tsChartsOptions;
	if (!isPro) {
		let tsDataUrl = `${httpPrefix}/lua/rest/v2/get/timeseries/ts.lua`;
		let paramsUrlRequest = `ts_compare=${tsCompare}&version=4&zoom=${tsCompare}&limit=180`;
		let tsGroup = timeseriesGroups[0];
		let main_source_index = getMainSourceDefIndex(tsGroup);
		let tsQuery = getTsQuery(tsGroup);
		let pObj = {
			...paramsEpochObj,
			ts_query: tsQuery,
			ts_schema: `${tsGroup.metric.schema}`,
		};
		if (!tsGroup.source_type.source_def_array[main_source_index].disable_tskey) {
			pObj.tskey = tsGroup.source_array[main_source_index].value;
		}
		let pUrlRequest = ntopng_url_manager.add_obj_to_url(pObj, paramsUrlRequest);
		let url = `${tsDataUrl}?${pUrlRequest}`;
		let tsChartOption = await ntopng_utility.http_request(url);
		tsChartsOptions = [tsChartOption];
	} else {
		let paramsChart = {
			zoom: tsCompare,
			limit: 180,
			version: 4,
			ts_compare: tsCompare,
		};

		let tsRequests = timeseriesGroups.map((tsGroup) => {
			let main_source_index = getMainSourceDefIndex(tsGroup);
			let tsQuery = getTsQuery(tsGroup);
			let pObj = {
				ts_query: tsQuery,
				ts_schema: `${tsGroup.metric.schema}`,
			};
			if (!tsGroup.source_type.source_def_array[main_source_index].disable_tskey) {
				pObj.tskey = tsGroup.source_array[main_source_index].value;
			}
			return pObj;
		});
		let tsDataUrlMulti = `${httpPrefix}/lua/pro/rest/v2/get/timeseries/ts_multi.lua`;
		let req = { ts_requests: tsRequests, ...paramsEpochObj, ...paramsChart };
		let headers = {
			'Content-Type': 'application/json'
		};
		tsChartsOptions = await ntopng_utility.http_request(tsDataUrlMulti, { method: 'post', headers, body: JSON.stringify(req) });
	}
	return tsChartsOptions;
}

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
		var leftLegend = point.x * area.w + followOffsetX;

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

const timeseriesUtils = function () {
	return {
		groupsOptionsModesEnum,
		tsArrayToOptions,
		tsArrayToOptionsArray,
		getGroupOptionMode,
		getSerieId,
		getSerieName,
		getTsChartsOptions,
		getTsQuery,
		getMainSourceDefIndex,
	};
}();

export default timeseriesUtils;
