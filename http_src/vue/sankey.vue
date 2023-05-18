/**
    (C) 2022 - ntop.org    
*/

<template>
  <div v-if="no_data" class="alert alert-info" id="empty-message">{{ _i18n('flows_page.no_data') }}</div>
  <div class="d-flex justify-content-center align-items-center" v-bind:id="id"></div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import sankeyUtils from "../utilities/map/sankey_utils"

const no_data = ref(false)
const props = defineProps({
  id: String,
  page_csrf: String,
  url: String,
  url_params: Array,
  extra_settings: Object,
})

function SankeyChart(data) {
  /* Get default settings */
  let settings = {
    ...sankeyUtils.getDefaultSankeySettings(),
    ...props.extra_settings
  };

  /* Get the links and nodes formatted list */
  const link_source = d3v7.map(data, settings.linkSource).map(intern);
  const link_target = d3v7.map(data, settings.linkTarget).map(intern);
  const link_source_node = d3v7.map(data, settings.linkSourceNode).map(intern);
  const link_target_node = d3v7.map(data, settings.linkTargetNode).map(intern);
  const link_link = d3v7.map(data, settings.linkLink).map(intern);
  const link_value = d3v7.map(data, settings.linkValue);
  const link_color = d3v7.map(data, settings.linkColor);
  const source_color = d3v7.map(data, settings.sourceColor);
  const target_color = d3v7.map(data, settings.targetColor);
  const source_link = d3v7.map(data, settings.sourceLink);
  const target_link = d3v7.map(data, settings.targetLink);

  let links = data;
  let nodes = Array.from(d3v7.union(link_source, link_target), id => ({ id }));

  const node_id_list = d3v7.map(nodes, settings.nodeId).map(intern);
  settings.nodeGroups = d3v7.map(nodes, settings.nodeGroup).map(intern);

  nodes = d3v7.map(nodes, (_, i) => ({ id: node_id_list[i] }));
  links = d3v7.map(links, (_, i) => ({ 
    source: link_source[i], 
    target: link_target[i], 
    value: link_value[i] ,
    source_node: link_source_node[i],
    target_node: link_target_node[i],
    link: link_link[i],
    color: link_color[i],
    source_color: source_color[i],
    target_color: target_color[i],
    source_link: source_link[i],
    target_link: target_link[i],
  }));

  /* Colors/Label/Titles arrays */
  const color = d3v7.scaleOrdinal(settings.nodeGroups, settings.colors);
  const node_label_list = d3v7.map(nodes, settings.nodeLabel);
  const node_title_list = d3v7.map(nodes, settings.nodeTitle);
  const link_title_list = d3v7.map(links, settings.linkTitle);

  /* Compute the Sankey layout. */
  let sankey = d3v7.sankey()
    .nodeId(({index: i}) => node_id_list[i])
    .nodeAlign(settings.nodeAlign)
    .nodeWidth(settings.nodeWidth)
    .nodePadding(settings.nodePadding)
    .extent([[settings.marginLeft, settings.marginTop], [settings.width - settings.marginRight, settings.height - settings.marginBottom]])
    ({nodes, links});

  const svg = d3v7.create("svg")
    .attr("viewBox", [0, 0, settings.width, settings.height])
    .attr("style", "max-width: 100%; height: 60vh; height: intrinsic;");

  let deltaX, deltaY;
    
  const width = settings.width;
  const link = svg.append("g")
    .attr("fill", "none")
    .attr("stroke-opacity", settings.linkStrokeOpacity)
    .selectAll("g")
    .data(links)
    .join("g")
    .style("mix-blend-mode", settings.linkMixBlendMode)
    .append("path")
    .attr("d", settings.linkPath)
    .attr("stroke", ({ color }) => color )
    .attr("stroke-width", ({ width }) => Math.max(1, width))
    .call(link_title_list ? path => path.append("title").text(({index: i}) => link_title_list[i]) : () => {});


  const drag = d3v7.drag()
    .on("start", function (event, d) {
        const current = d3v7.select(this);
        deltaX = current.attr("x") - event.x;
        deltaY = current.attr("y") - event.y;
    })
    .on("drag", function (event, d) {
      d3v7.select(this)
            .attr("x", event.x + deltaX)
            .attr("y", event.y + deltaY);

      debugger;
      sankey = d3v7.sankey().update(sankey)
        link.selectAll("path")
        .data(sankey.links, function(d) { return d; });
    });
    
  const node = svg.append("g")
    .attr("stroke", settings.nodeStroke)
    .attr("stroke-width", settings.nodeStrokeWidth)
    .attr("stroke-opacity", settings.nodeStrokeOpacity)
    .attr("stroke-linejoin", settings.nodeStrokeLinejoin)
    .selectAll("rect")
    .data(nodes)    
    .join("rect")
    .call(drag)
	  .on("dblclick", function(data) { 
      data = data.currentTarget.__data__
      const sourceLink = data.sourceLinks;
      const targetLink = data.targetLinks;
      const link = (sourceLink && sourceLink[0]) ? sourceLink[0] : targetLink[0];

      if(link) {
        /* Get the node link from the rest */
        if(link.source.id === data.id) {
          if(link.source_link && link.source_link !== '')
            window.open(link.source_link, '_blank');
        } else if(link.target.id === data.id) {
          if(link.target_link && link.target_link !== '')
            window.open(link.target_link, '_blank');
        } 
      } 
    })
    /*.on("drag", sankeyUtils.dragNodeEvent) */
    .attr("x", d => d.x0)
    .attr("y", d => d.y0)
    .attr("height", d => d.y1 - d.y0)
    .attr("width", d => d.x1 - d.x0)
    .attr("cursor", "pointer")
    .attr("fill", (data) => { 
      const sourceLink = data.sourceLinks;
      let node_color = color(settings.nodeGroups[data.index]) 

      if(sourceLink && sourceLink[0]) {
        /* Get the node color from the rest */
        if(sourceLink[0].source.id === data.id) {
          if(sourceLink[0].source_color && sourceLink[0].source_color !== '') 
            node_color = sourceLink[0].source_color;
        } else if(sourceLink[0].target.id === data.id) {
          if(sourceLink[0].target_color && sourceLink[0].target_color !== '') 
            node_color = sourceLink[0].target_color;
        }
      } 
      
      return node_color;
    })
    .append("title").text(({index: i}) => node_title_list[i]);

  svg.append("g")
    .attr("font-family", "sans-serif")
    .attr("font-size", 10)
    .selectAll("text")
    .data(nodes)
    .join("text")
    .attr("x", d => d.x0 < width / 2 ? d.x1 + settings.nodeLabelPadding : d.x0 - settings.nodeLabelPadding)
    .attr("y", d => (d.y1 + d.y0) / 2)
    .attr("dy", "0.35em")
    .attr("text-anchor", d => d.x0 < settings.width / 2 ? "start" : "end")
    .text(({index: i}) => node_label_list[i]);

  function intern(value) {
    return value !== null && typeof value === "object" ? value.valueOf() : value;
  }

  return Object.assign(svg.node(), {scales: {color}});
}


const _i18n = (t) => i18n(t);
const format_request = function() {
  let params = {}
  props.url_params.forEach((name) => {
    params[name] = ntopng_url_manager.get_url_entry(name);
  });

  return NtopUtils.buildURL(props.url, params); 
}

const updateData = async function(data) {
  /* Show the loading overlay */
  NtopUtils.showOverlays();  

  /* Update the URL using the params needed */
  const url = format_request()
  /* Do the request and update the sankey */
  await $.get(url, function(rsp, status){
    const data = rsp.rsp;
    if(data.length > 0) {
      let chart = SankeyChart(data)
      no_data.value = false
      $(`#${props.id}`).empty();
      $(`#${props.id}`).append(chart);
    } else {
      $(`#${props.id}`).empty();
      no_data.value = true
    }  
  });

  NtopUtils.hideOverlays();
};

onMounted(() => { })

defineExpose({ updateData })
</script>

