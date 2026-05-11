/*
  (C) 2013-23 - ntop.org
 */

/*
  Here a list of functions used to check, format data;
  e.g. functions that check if a string is null or empty
 */

/* This function create a small heatmap, depending on the hours */
const createHeatmap = (data) => {
  const squareLength = 7, squareHeight = 20;
  const colors = ['#d3d3d3', '#28a745', '#f00', '#ffc107'];
  let svg = `<svg width='${squareLength * data.length + data.length * 2}' height='20' viewBox='0 0 ${squareLength * data.length + data.length * 2} 20'>`;
  const this_hour = new Date().getHours();

  for (let x = 0; x < 24; x++) {
    const $rect = $(document.createElementNS("http://www.w3.org/2000/svg", "rect"));
    $rect.attr('x', x * (squareLength + 2)).attr('y', 0).attr('width', squareLength).attr('height', squareHeight);
    const colorIndex = (data.length > 0) ? data[x] : 0;
    $rect.attr('fill', colors[colorIndex]);
    if (this_hour == x) {
      $rect.attr('stroke', '#000'); /* Add stroke for the current hour */
      $rect.attr('stroke-width', '2');
      $rect.attr('stroke-dasharray', '2'); /* Make line dashed */
      $rect.attr('opacity', '0.6');
    }        
    svg = `${svg}${$rect[0].outerHTML}`;
  }
  svg = `${svg}</svg>`;
  return svg;
}

/* ******************************************************************** */

const visualizationUtils = function () {
  return {
    createHeatmap
  };
}();

export default visualizationUtils;

