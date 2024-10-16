/**
    (C) 2023 - ntop.org
*/

/* *********************************************** */

const MAX_BAR_WIDTH = 90; /* 100 px */
const FILL_COLORS = [
  'rgb(144, 238, 144)',
  'rgb(25, 135, 84)',
  'rgb(255, 193, 7)',
  'rgb(220, 53, 69)'
];

/* *********************************************** */

function darkenColor(colorStr) {
  const color = Dygraph.toRGB_(colorStr);
  color.r = Math.floor((255 + color.r) / 2);
  color.g = Math.floor((255 + color.g) / 2);
  color.b = Math.floor((255 + color.b) / 2);
  return 'rgb(' + color.r + ',' + color.g + ',' + color.b + ', 0.9)';
}

/* *********************************************** */

function getColor(current_value, max_value, default_color) {
  if(!max_value || !current_value) {
    return darkenColor(default_color);
  }
  /* Security check */
  if(current_value > max_value) {
    current_value = max_value;
  }

  const colors_module = max_value / FILL_COLORS.length;
  for(let i = 1; i < FILL_COLORS.length + 1; i++) {
    if(current_value <= colors_module * i) {
      return FILL_COLORS[i - 1];
    }
  }
}

/* *********************************************** */

/* This function is used to create a bar chart instead of a line chart */
function barChartPlotter(e) {
  const ctx = e.drawingContext;
  const points = e.points;
  const y_bottom = e.dygraph.toDomYCoord(0);
  const max_value = e.dygraph.user_attrs_.valueRange[1]
  const default_color = e.color;
  
  /* Find the minimum separation between x-values.
   * This determines the bar width.
   */
  let min_sep = Infinity;
  for (let i = 1; i < points.length; i++) {
    const sep = points[i].canvasx - points[i - 1].canvasx;
    if (sep < min_sep && sep > 0) min_sep = sep;
  }

  if(min_sep > MAX_BAR_WIDTH) {
    min_sep = MAX_BAR_WIDTH
  }

  /* Keep just a little distance between the bars */
  const bar_width = Math.floor(0.9 * min_sep);

  /* Do the actual plotting */
  for (var i = 0; i < points.length; i++) {
    const p = points[i];
    const center_x = p.canvasx;
    const current_value = p.yval;
    ctx.fillStyle = getColor(Math.abs(current_value), Math.abs(max_value), default_color);
    ctx.fillRect(center_x - bar_width / 2, p.canvasy,
      bar_width, y_bottom - p.canvasy);
    ctx.strokeRect(center_x - bar_width / 2, p.canvasy,
      bar_width, y_bottom - p.canvasy);
  }
}

/* *********************************************** */

const dygraphPlotters = function () {
  return {
    barChartPlotter,
  };
}();

export default dygraphPlotters;