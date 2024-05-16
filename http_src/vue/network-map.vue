<!-- (C) 2022 - ntop.org     -->
<template>
  <div v-if="empty_map" class="alert alert-info">
    {{ empty_message }}
  </div>
  <div class="d-flex justify-content-center align-items-center resizable-y-container" style="width: 100%; height: 60vh;"
    :id=map_id>
  </div>
</template>

<script setup>
import { onMounted, onBeforeUnmount, ref } from "vue";
import { ntopng_map_manager } from '../utilities/map/ntopng_vis_network_utils';
import { ntopng_events_manager, ntopng_url_manager } from '../services/context/ntopng_globals_services';

const props = defineProps({
  empty_message: String,
  event_listeners: Object,
  page_csrf: String,
  url: String,
  url_params: Object,
  map_id: String,
});

const dataRequest = {
  ifid: props.url_params.ifid,
  action: 'load_graph',
  map: props.url_params.map_id
};

let nodes_dataset = {};
let edges_dataset = {};
let highlightActive = false;
let network = null;
const max_entries_reached = ref(false);
const empty_map = ref(true);
const is_destroyed = ref(false);
const url_params = ref({});
const datasets = ref(null);
const options = ref(null);
const all_nodes = ref(null);

onMounted(async () => {
  const container = document.getElementById(props.map_id);
  load_scale();
  await request_info();
  options.value = ntopng_map_manager.get_default_options();
  network = new vis.Network(container, datasets.value, options.value);
  set_event_listener();
})

onBeforeUnmount(() => {
  if (is_destroyed.value == true) {
    return;
  }
  destroy();
});

const generate_html_tooltip = (x) => {
  const container = document.createElement("div");
  /* Necessary, otherwise it will go in conflict with other css */
  //container.style.color = "#111111";
  container.innerHTML = `<b>${x.label}</b><br><br>${i18n('db_explorer.host_data')}: ${x.id}`;
  return container;
}

/* This function is used to perform the request */
const request_info = async () => {
  /* if an host has been defined inside the URL query then add it to the request */
  url_params.value = props.url_params;
  const url = NtopUtils.buildURL(props.url, url_params.value);
  await $.get(url, dataRequest, async function (response) {
    const { nodes, edges, max_entry_reached } = response.rsp;
    max_entries_reached.value = max_entry_reached;
    /* Adding tooltip to each node */
    nodes_dataset = new vis.DataSet(nodes.map((x) => {
      x.title = generate_html_tooltip(x);
      return x;
    }));
    edges_dataset = new vis.DataSet(edges);
    datasets.value = {
      nodes: nodes_dataset,
      edges: edges_dataset
    };
    all_nodes.value = nodes_dataset.get({ returnType: "Object" });
    empty_network();
  });
};

/* Add the host to the url and jump to the host */
const jump_to_host = async (params) => {
  const host_info = params.id.split('@')
  url_params.value['host'] = host_info[0]; /* Host IP */
  url_params.value['vlan_id'] = host_info[1]; /* VLAN ID */
  ntopng_url_manager.set_key_to_url('host', url_params.value['host']);
  ntopng_url_manager.set_key_to_url('vlan_id', url_params.value['vlan_id']);
  ntopng_events_manager.emit_custom_event(ntopng_custom_events.CHANGE_PAGE_TITLE, params)
  await reload();
}

/* In case of empty network enable the "Empty Network" message */
const empty_network = () => {
  if (datasets.value?.nodes.length == 0
    && datasets.value?.edges.length == 0) {
    empty_map.value = true;
  } else {
    empty_map.value = false;
  }
}

/* Fix the resizable width/height of the container */
const load_scale = () => {
  const oldScale = NtopUtils.loadElementScale($(`.resizable-y-container`))

  if (oldScale == null) {
    const scale = { width: $(`.resizable-y-container`).width(), height: $(`.resizable-y-container`).height() };
    NtopUtils.saveElementScale($(this), scale);
    return;
  }

  $(`.resizable-y-container`).width(oldScale.width);
  $(`.resizable-y-container`).height(oldScale.height);
  $(`.resizable-y-container`).on('mouseup', function () {
    const scale = { width: $(`.resizable-y-container`).width(), height: $(`.resizable-y-container`).height() };
    NtopUtils.saveElementScale($(this), scale);
  });
}

function neighbourhoodHighlight(params) {
  // if something is selected:
  if (params.nodes.length > 0) {
    highlightActive = true;
    var i, j;
    var selectedNode = params.nodes[0];
    var degrees = 2;

    // mark all nodes as hard to read.
    for (var nodeId in all_nodes.value) {
      if (!all_nodes.value[nodeId].old_color) {
        all_nodes.value[nodeId].old_color =
          all_nodes.value[nodeId].color;
      }
      if (!all_nodes.value[nodeId].old_icon_color) {
        all_nodes.value[nodeId].old_icon_color =
          all_nodes.value[nodeId].icon;
      }
      all_nodes.value[nodeId].color = "#c8c8c8";
      all_nodes.value[nodeId].icon = {
        color: "#c8c8c8"
      };
      if (all_nodes.value[nodeId].hiddenLabel === undefined) {
        all_nodes.value[nodeId].hiddenLabel = all_nodes.value[nodeId].label;
        all_nodes.value[nodeId].label = undefined;
      }
    }
    var connectedNodes = network.getConnectedNodes(selectedNode);
    var allConnectedNodes = [];

    // get the second degree nodes
    for (i = 1; i < degrees; i++) {
      for (j = 0; j < connectedNodes.length; j++) {
        allConnectedNodes = allConnectedNodes.concat(
          network.getConnectedNodes(connectedNodes[j])
        );
      }
    }

    // all first degree nodes get their own color and their label back
    for (i = 0; i < connectedNodes.length; i++) {
      all_nodes.value[connectedNodes[i]].color =
        all_nodes.value[connectedNodes[i]].old_color;
      all_nodes.value[connectedNodes[i]].icon =
        all_nodes.value[connectedNodes[i]].old_icon_color;
      if (all_nodes.value[connectedNodes[i]].hiddenLabel !== undefined) {
        all_nodes.value[connectedNodes[i]].label =
          all_nodes.value[connectedNodes[i]].hiddenLabel;
        all_nodes.value[connectedNodes[i]].hiddenLabel = undefined;
      }
    }

    // the main node gets its own color and its label back.
    all_nodes.value[selectedNode].color =
      all_nodes.value[selectedNode].old_color;
    all_nodes.value[selectedNode].icon =
      all_nodes.value[selectedNode].old_icon_color;
    if (all_nodes.value[selectedNode].hiddenLabel !== undefined) {
      all_nodes.value[selectedNode].label = all_nodes.value[selectedNode].hiddenLabel;
      all_nodes.value[selectedNode].hiddenLabel = undefined;
    }
  } else if (highlightActive === true) {
    // reset all nodes
    for (var nodeId in all_nodes.value) {
      all_nodes.value[nodeId].color =
        all_nodes.value[nodeId].old_color;
      all_nodes.value[nodeId].icon =
        all_nodes.value[nodeId].old_icon_color;
      if (all_nodes.value[nodeId].hiddenLabel !== undefined) {
        all_nodes.value[nodeId].label = all_nodes.value[nodeId].hiddenLabel;
        all_nodes.value[nodeId].hiddenLabel = undefined;
      }
    }
    highlightActive = false;
  }

  // transform the object into an array
  var updateArray = [];
  for (nodeId in all_nodes.value) {
    if (all_nodes.value.hasOwnProperty(nodeId)) {
      updateArray.push(all_nodes.value[nodeId]);
    }
  }
  nodes_dataset.update(updateArray);
}


/* Set the event lister used for callbacks */
const set_event_listener = () => {

  if (!props.event_listeners || !props.event_listeners["stabilizationIterationsDone"]) {
    network.on("stabilizationIterationsDone", function () {
      network.setOptions({ physics: false });
    })
  }

  if (!props.event_listeners || !props.event_listeners["click"]) {
    network.on("click", function (node) {
      neighbourhoodHighlight(node);
    });
  }

  if (!props.event_listeners || !props.event_listeners["doubleClick"]) {
    network.on("doubleClick", function (params) {
      jump_to_host(nodes_dataset.get(params.nodes[0]));
    });
  }


  if (!props.event_listeners || !props.event_listeners["afterDrawing"]) {
    network.on("afterDrawing", function (e) {
      ntopng_events_manager.emit_custom_event(ntopng_custom_events.VIS_DATA_LOADED);
    })
  }

  /* Given event listeners */
  for (const item in (props.event_listeners || {})) {
    network.on(item, props.event_listeners[item]);
  }
}

/* Function used to autolayout/stabilize the network */
const autolayout = () => {
  if (network == null) {
    console.error("The network is undefined!");
    return;
  }

  if (!(network instanceof vis.Network)) {
    console.error("Not a vis.Network instance!");
    return;
  }

  network.stabilize();
}

/* Destroy the network if it's not null */
const destroy = () => {
  if (network != null)
    network.destroy(true);

  is_destroyed.value = true
}

/* This return true if the maximum number of nodes/edges has been reached */
const is_max_entry_reached = () => {
  return max_entries_reached.value;
}

/* Function used to update the params */
const update_url_params = (new_url_params) => {
  url_params.value = new_url_params;
}

/* Function used to reload the map */
const reload = async () => {
  await request_info();
  if (network != null) {
    /* Reload of the physics is done due to a possible bug,
     * with many nodes, the physics could stuck infinitely 
     */
    network.setOptions({ physics: options.value.physics });
    network.setData(datasets.value);
  }
}


defineExpose({ reload, destroy, is_max_entry_reached, autolayout, update_url_params });
</script>
