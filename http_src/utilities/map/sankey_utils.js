/**
    (C) 2022 - ntop.org    
*/
import NtopUtils from "../ntop-utils.js";

let d3 = d3v7;

const defaultSankeySettings = {
  align: "justify", // convenience shorthand for nodeAlign
  nodeId: d => d.id, // given d in nodes, returns a unique identifier (string)
  nodeTitle: d => `${d.id}`, // given d in (computed) nodes, hover text
  nodeGroup: d => d.id.split(/\W/)[0],
  nodeAlign: d3.sankeyJustify, // Sankey node alignment strategy: left, right, justify, center
  nodeWidth: 15, // width of node rects
  nodePadding: 10, // vertical separation between adjacent nodes
  nodeLabel: d => d.id,
  nodeLabelPadding: 6, // horizontal separation between node and label
  nodeStroke: "currentColor", // stroke around node rects
  linkSource: ({source}) => source, // given d in links, returns a node identifier string
  linkTarget: ({target}) => target, // given d in links, returns a node identifier string
  linkSourceNode: ({source_node}) => source_node, // given d in links, returns a node identifier string
  linkTargetNode: ({target_node}) => target_node, // given d in links, returns a node identifier string
  linkPath: d3.sankeyLinkHorizontal(), // given d in (computed) links, returns the SVG path
  linkValue: ({value}) => value, // given d in links, returns the quantitative value
  linkLink: ({link}) => link, // given d in links, returns the quantitative value
  linkTitle: d => `${d.source_node} → ${d.target_node} : ${d.link}\n${d.value}`, // given d in (computed) links
  linkColor: ({link_color}) => link_color, // source, target, source-target, or static color
  sourceColor: ({source_color}) => source_color ? source_color : '',
  targetColor: ({target_color}) => target_color ? target_color : '',
  sourceLink: ({source_link}) => source_link ? source_link : '',
  targetLink: ({target_link}) => target_link ? target_link : '',
  linkStrokeOpacity: 0.5, // link stroke opacity
  linkMixBlendMode: "multiply", // link blending mode
  colors: d3.schemeTableau10, // array of colors
  width: 1200, // outer width, in pixels
  height: 600, // outer height, in pixels
  marginTop: 5, // top margin, in pixels
  marginRight: 1, // right margin, in pixels
  marginBottom: 5, // bottom margin, in pixels
  marginLeft: 1, // left margin, in pixels
}

const formatFlowTitle = (d) => `${i18n('flow')}: ${d.source_node} → ${d.target_node}\n${i18n('protocol')}: ${d.link}\n${i18n('traffic')}: ${NtopUtils.bytesToSize(d.value)}`

const getDefaultSankeySettings = function() {
  return defaultSankeySettings;
}

const dragNodeEvent = function(d) {
  d3.select(this).attr("transform", "translate(" + d.x + "," + (d.y = Math.max(0, Math.min(height - d.dy, d3.event.y))) + ")");
  sankey.relayout();
  link.attr("d", path);
}

const sankeyUtils = function() {
  return {
    formatFlowTitle,
    dragNodeEvent,
    getDefaultSankeySettings
  };
}();

export default sankeyUtils;
