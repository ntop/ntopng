/*jslint vars: true, nomen: true, plusplus: true, maxerr: 500, indent: 4 */

/**
 * @license
 * Copyright 2011 Juan Manuel Caicedo Carvajal (juan@cavorite.com)
 * MIT-licensed (http://opensource.org/licenses/MIT)
 */

/**
 * @fileoverview This file contains additional features for dygraphs, which
 * are not required but can be useful for certain use cases. Examples include
 * exporting a dygraph as a PNG image.
 */

/**
 * Demo code for exporting a Dygraph object as an image.
 *
 * See: http://cavorite.com/labs/js/dygraphs-export/
 */

Dygraph.Export = {};

Dygraph.Export.DEFAULT_ATTRS = {
  backgroundColor: "white",

  //Texts displayed below the chart's x-axis and to the left of the y-axis 
  titleFont: "bold 18px system-ui",
  titleFontColor: "black",

  //Texts displayed below the chart's x-axis and to the left of the y-axis 
  axisLabelFont: "bold 12px system-ui",
  axisLabelFontColor: "black",

  // Texts for the axis ticks
  labelFont: "normal 12px system-ui",
  labelFontColor: "black",

  // Text for the chart legend
  legendFont: "bold 14px system-ui",
  legendFontColor: "black",

  // Default position for vertical labels
  vLabelLeft: 20,

  legendHeight: 20,    // Height of the legend area
  legendMargin: 20,
  lineHeight: 30,
  maxlabelsWidth: 0,
  labelTopMargin: 35,
  magicNumbertop: 8
};

Dygraph.Export.DARK_MODE_DEFAULT_ATTRS = {
  backgroundColor: "transparent",

  //Texts displayed below the chart's x-axis and to the left of the y-axis 
  titleFont: "bold 18px system-ui",
  titleFontColor: "white",

  //Texts displayed below the chart's x-axis and to the left of the y-axis 
  axisLabelFont: "bold 12px system-ui",
  axisLabelFontColor: "white",

  // Texts for the axis ticks
  labelFont: "normal 12px system-ui",
  labelFontColor: "white",

  // Text for the chart legend
  legendFont: "bold 14px system-ui",
  legendFontColor: "white",

  // Default position for vertical labels
  vLabelLeft: 20,

  legendHeight: 20,    // Height of the legend area
  legendMargin: 20,
  lineHeight: 30,
  maxlabelsWidth: 0,
  labelTopMargin: 35,
  magicNumbertop: 8
};

/**
 * Tests whether the browser supports the canvas API and its methods for 
 * drawing text and exporting it as a data URL.
 */
Dygraph.Export.isSupported = function () {
  "use strict";
  try {
    var canvas = document.createElement("canvas");
    var context = canvas.getContext("2d");
    return (!!canvas.toDataURL && !!context.fillText);
  } catch (e) {
    // Silent exception.
  }
  return false;
};

/**
 * Exports a dygraph object as a PNG image.
 *
 *  dygraph: A Dygraph object
 *  img: An IMG DOM node
 *  userOptions: An object with the user specified options.
 *
 */
Dygraph.Export.asPNG = function (dygraph, img, userOptions) {
  "use strict";
  var canvas = Dygraph.Export.asCanvas(dygraph, userOptions);
  img.src = canvas.toDataURL();
};

/**
 * Exports a dygraph into a single canvas object.
 *
 * Returns a canvas object that can be exported as a PNG.
 *
 *  dygraph: A Dygraph object
 *  userOptions: An object with the user specified options.
 *
 */
Dygraph.Export.update = function (self, o) {
  if (typeof (o) != 'undefined' && o !== null) {
    for (var k in o) {
      if (o.hasOwnProperty(k)) {
        self[k] = o[k];
      }
    }
  }
  return self;
};

Dygraph.Export.asCanvas = function (dygraph, userOptions) {
  "use strict";
  var options = {},
    canvas = document.createElement('canvas');

  if (document.getElementsByClassName('body dark').length > 0) {
    Dygraph.Export.update(options, Dygraph.Export.DARK_MODE_DEFAULT_ATTRS);
  } else {
    Dygraph.Export.update(options, Dygraph.Export.DEFAULT_ATTRS);
  }
  Dygraph.Export.update(options, userOptions);

  canvas.width = dygraph.width_;
  canvas.height = dygraph.height_ + options.legendHeight;

  Dygraph.Export.drawPlot(canvas, dygraph, options);
  Dygraph.Export.drawLegend(canvas, dygraph, options);

  return canvas;
};

/**
 * Adds the plot and the axes to a canvas context.
 */
Dygraph.Export.drawPlot = function (canvas, dygraph, options) {
  "use strict";
  var ctx = canvas.getContext("2d");

  // Add user defined background
  ctx.fillStyle = options.backgroundColor;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Copy the plot canvas into the context of the new image.
  var plotCanvas = dygraph.hidden_;

  let i = 0;

  ctx.drawImage(plotCanvas, 0, 0);

  // Add the x and y axes
  var axesPluginDict = Dygraph.Export.getPlugin(dygraph, 'Axes Plugin');
  if (axesPluginDict) {
    var axesPlugin = axesPluginDict.plugin;

    for (i = 0; i < axesPlugin.ylabels_.length; i++) {
      Dygraph.Export.putLabel(ctx, axesPlugin.ylabels_[i], options,
        options.labelFont, options.labelFontColor);
    }

    for (i = 0; i < axesPlugin.xlabels_.length; i++) {
      Dygraph.Export.putLabel(ctx, axesPlugin.xlabels_[i], options,
        options.labelFont, options.labelFontColor);
    }
  }

  // Title and axis labels

  var labelsPluginDict = Dygraph.Export.getPlugin(dygraph, 'ChartLabels Plugin');
  if (labelsPluginDict) {
    var labelsPlugin = labelsPluginDict.plugin;

    Dygraph.Export.putLabel(ctx, labelsPlugin.title_div_, options,
      options.titleFont, options.titleFontColor);

    Dygraph.Export.putLabel(ctx, labelsPlugin.xlabel_div_, options,
      options.axisLabelFont, options.axisLabelFontColor);

    Dygraph.Export.putVerticalLabelY1(ctx, labelsPlugin.ylabel_div_, options,
      options.axisLabelFont, options.axisLabelFontColor, "center");

    Dygraph.Export.putVerticalLabelY2(ctx, labelsPlugin.y2label_div_, options,
      options.axisLabelFont, options.axisLabelFontColor, "center");
  }

  for (i = 0; i < dygraph.layout_.annotations.length; i++) {
    Dygraph.Export.putLabelAnn(ctx, dygraph.layout_.annotations[i], options,
      options.labelFont, options.labelColor);
  }

};

/**
 * Draws a label (axis label or graph title) at the same position 
 * where the div containing the text is located.
 */
Dygraph.Export.putLabel = function (ctx, divLabel, options, font, color) {
  "use strict";

  if (!divLabel || !divLabel.style) {
    return;
  }

  var top = parseInt(divLabel.style.top, 10);
  var left = parseInt(divLabel.style.left, 10);

  if (!divLabel.style.top.length) {
    var bottom = parseInt(divLabel.style.bottom, 10);
    var height = parseInt(divLabel.style.height, 10);

    top = ctx.canvas.height - options.legendHeight - bottom - height;
  }

  // FIXME: Remove this 'magic' number needed to get the line-height. 
  top = top + options.magicNumbertop;

  var width = parseInt(divLabel.style.width, 10);

  switch (divLabel.style.textAlign) {
    case "center":
      left = left + Math.ceil(width / 2);
      break;
    case "right":
      left = left + width;
      break;
  }

  Dygraph.Export.putText(ctx, left, top, divLabel, font, color);
};

/**
 * Draws a label Y1 rotated 90 degrees counterclockwise.
 */
Dygraph.Export.putVerticalLabelY1 = function (ctx, divLabel, options, font, color, textAlign) {
  "use strict";
  if (!divLabel) {
    return;
  }

  var top = parseInt(divLabel.style.top, 10);
  var left = parseInt(divLabel.style.left, 10) + parseInt(divLabel.style.width, 10) / 2;
  var text = divLabel.innerText || divLabel.textContent;


  // FIXME: The value of the 'left' property is frequently 0, used the option.
  if (!left)
    left = options.vLabelLeft;

  if (textAlign == "center") {
    var textDim = ctx.measureText(text);
    top = Math.ceil((ctx.canvas.height - textDim.width) / 2 + textDim.width);
  }

  ctx.save();
  ctx.translate(0, ctx.canvas.height);
  ctx.rotate(-Math.PI / 2);

  ctx.fillStyle = color;
  ctx.font = font;
  ctx.textAlign = textAlign;
  ctx.fillText(text, top, left);

  ctx.restore();
};

/**
 * Draws a label Y2 rotated 90 degrees clockwise.
 */
Dygraph.Export.putVerticalLabelY2 = function (ctx, divLabel, options, font, color, textAlign) {
  "use strict";
  if (!divLabel) {
    return;
  }

  var top = parseInt(divLabel.style.top, 10);
  var right = parseInt(divLabel.style.right, 10) + parseInt(divLabel.style.width, 10) * 2;
  var text = divLabel.innerText || divLabel.textContent;

  if (textAlign == "center") {
    top = Math.ceil(ctx.canvas.height / 2);
  }

  ctx.save();
  ctx.translate(parseInt(divLabel.style.width, 10), 0);
  ctx.rotate(Math.PI / 2);

  ctx.fillStyle = color;
  ctx.font = font;
  ctx.textAlign = textAlign;
  ctx.fillText(text, top, right - ctx.canvas.width);

  ctx.restore();
};

/**
 * Draws the text contained in 'divLabel' at the specified position.
 */
Dygraph.Export.putText = function (ctx, left, top, divLabel, font, color) {
  "use strict";
  var textAlign = divLabel.style.textAlign || "left";
  var text = divLabel.innerText || divLabel.textContent;

  ctx.fillStyle = color;
  ctx.font = font;
  ctx.textAlign = textAlign;
  ctx.textBaseline = "middle";
  ctx.fillText(text, left, top);
};

/**
 * Draws the legend of a dygraph
 *
 */
Dygraph.Export.drawLegend = function (canvas, dygraph, options) {
  "use strict";
  var ctx = canvas.getContext("2d");

  // Margin from the plot
  var labelTopMargin = 10;

  // Margin between labels
  var labelMargin = 5;

  var colors = dygraph.getColors();
  // Drop the first element, which is the label for the time dimension
  var labels = dygraph.attr_("labels").slice(1);

  // 1. Compute the width of the labels:
  var labelsWidth = 0;

  var i;
  for (i = 0; i < labels.length; i++) {
    labelsWidth = labelsWidth + ctx.measureText("- " + labels[i]).width + labelMargin;
  }

  var labelsX = Math.floor((canvas.width - labelsWidth) / 2);
  var labelsY = canvas.height - options.legendHeight + labelTopMargin;


  var labelVisibility = dygraph.attr_("visibility");

  ctx.font = options.legendFont;
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";

  var usedColorCount = 0;
  for (i = 0; i < labels.length; i++) {
    if (labelVisibility[i]) {
      //TODO Replace the minus sign by a proper dash, although there is a
      //     problem when the page encoding is different than the encoding 
      //     of this file (UTF-8).
      var txt = "- " + labels[i];
      ctx.fillStyle = colors[usedColorCount];
      usedColorCount++
      ctx.fillText(txt, labelsX, labelsY);
      labelsX = labelsX + ctx.measureText(txt).width + labelMargin;
    }
  }
};

/**
 * Finds a plugin by the value returned by its toString method..
 *
 * Returns the the dictionary corresponding to the plugin for the argument.
 * If the plugin is not found, it returns null.
 */
Dygraph.Export.getPlugin = function (dygraph, name) {
  for (let i = 0; i < dygraph.plugins_.length; i++) {
    if (dygraph.plugins_[i].plugin.toString() == name) {
      return dygraph.plugins_[i];
    }
  }
  return null;
}