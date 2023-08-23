<!-- (C) 2022 - ntop.org     -->
<template>
<div id="empty-map-message" class="alert alert-info" hidden>
  {{ empty_message }}
</div>
<div class="d-flex justify-content-center align-items-center resizable-y-container" style="width: 100%; height: 60vh;" :id=map_id>
</div>
</template>

<script setup>
import { onMounted, onBeforeUnmount } from "vue";
import { ntopng_map_manager } from '../utilities/map/ntopng_vis_network_utils';
import { ntopng_events_manager, ntopng_url_manager } from '../services/context/ntopng_globals_services';

const MIN_SCALE = 0.15;

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

let network = null;
let nodes_dataset = {};
let edges_dataset = {};
let container = null;
let max_entries = false;
let update_view_state_id = null;
let url_params = {};
let is_destroyed = false;

async function check_layout(network) {
  if(!network) return;
  // get all nodes position
  const positions = network.getPositions(network.body.data.nodes.map(x => x.id));
  let refresh_layout = false;
  console.log(positions);
  try {
    for (const [node1, position1] of Object.entries(positions)) {
      for (const [node2, position2] of Object.entries(positions)) {
        /* The x and y of the node1 is +-2 the x and y of the node2 */
        /* In order to not have too close nodes */
        if((node1 != node2)
          && ((position2.x - 2) <= position1.x && position1.x <= (position2.x + 2))
          && ((position2.y - 2) <= position1.y && position1.y <= (position2.y + 2))) {
          console.log(position1);
          console.log(position2);
          refresh_layout = true;
          break;
        }
      }

      if(refresh_layout == true) {
        break;
      }
    }
    
    if(refresh_layout == true) {
      autolayout();
    }
  } catch(error) {
    console.log(error);
  }
}

onMounted(async () => {
  load_scale();
  url_params = props.url_params;
  container = document.getElementById(props.map_id);
  
  // if an host has been defined inside the URL query then add it to the request
  const url = NtopUtils.buildURL(props.url, url_params); 
  await $.get(url, dataRequest, function(response) {
    const {nodes, edges, max_entry_reached} = response.rsp;
    max_entries = max_entry_reached;
    nodes_dataset = new vis.DataSet(nodes);
    edges_dataset = new vis.DataSet(edges);
    const datasets = {nodes: nodes_dataset, edges: edges_dataset};
    empty_network(datasets);
    network = new vis.Network(container, datasets, ntopng_map_manager.get_default_options());
    check_layout(network);
    save_topology_view();
    set_event_listener();
	});
})

onBeforeUnmount(() => {
  if (is_destroyed == true) { return; }
  destroy();
});

const jump_to_host = (params) => {
  const tmpHost = params.id.split('@')
  url_params['host'] = tmpHost[0]
  url_params['vlan_id'] = tmpHost[1]
  ntopng_url_manager.set_key_to_url('host', url_params['host']);
  ntopng_url_manager.set_key_to_url('vlan_id', url_params['vlan_id']);
  ntopng_events_manager.emit_custom_event(ntopng_custom_events.CHANGE_PAGE_TITLE, params)
  reload();
  check_layout();
}

const empty_network = (datasets) => {
  if(datasets.nodes.length == 0 && datasets.edges.length == 0) {
    $(`#empty-map-message`).removeAttr('hidden');
  } else {
    $(`#empty-map-message`).attr('hidden', 'hidden');
  }
}

const load_scale = () => {
  // load old scale for resizable containers
  const oldScale = NtopUtils.loadElementScale($(`.resizable-y-container`))

  if(oldScale === undefined) {
    const scale = {width: $(`.resizable-y-container`).width(), height: $(`.resizable-y-container`).height()};
    NtopUtils.saveElementScale($(this), scale);
    return;
  }

  $(`.resizable-y-container`).width(oldScale.width);
  $(`.resizable-y-container`).height(oldScale.height);
  $(`.resizable-y-container`).on('mouseup', function() {
    const scale = {width: $(`.resizable-y-container`).width(), height: $(`.resizable-y-container`).height()};
    NtopUtils.saveElementScale($(this), scale);
  });

  $(`button[data-toggle="tooltip"]`).tooltip();
}

const set_event_listener = () => {
  /* Default event listeners */
  network.on('hoverEdge', function() {
    $(`.vis-tooltip`).css('position', 'absolute')
  });
  
  network.on("doubleClick", function (params) {
    jump_to_host(nodes_dataset.get(params.nodes[0]))
  });

  network.on('zoom', function(e) {
    update_view_state_id = zoom_in_and_save_topology()
  });

  network.on("dragEnd", function(e) {
    drag()
  });

  network.on("afterDrawing", function(e) {
    ntopng_events_manager.emit_custom_event(ntopng_custom_events.VIS_DATA_LOADED);
  })

  /* Given event listeners */
  for (const item in (props.event_listeners || {})) {
    network.on(item, props.event_listeners[item]);
  }
}

const save_topology_view = () => {
  if(!network) return;
  // get all nodes position
  const positions = network.getPositions(network.body.data.nodes.map(x => x.id));
  // save the nodes position, the network scale and the network view position
  const info = {
    positions: positions,
    network: {
      scale: network.getScale(),
      position: network.getViewPosition()
    }
  };

  $.post(props.url, {
    ...url_params,
    ...{ 
      csrf: props.page_csrf,
      JSON: JSON.stringify(info), 
      action: 'save_view' 
    }
  });
}

const zoom_in_and_save_topology = () => {
  if (network.getScale() <= MIN_SCALE) {
    network.moveTo({
      scale: MIN_SCALE + 0.25,
      position: { x: 0, y: 0 },
      animation: { duration: 1000, easingFunction: 'easeInOutCubic' }
    });
  }

  clearTimeout(update_view_state_id);


  return setTimeout(save_topology_view);
}

const autolayout = () => {
  if (network === undefined) {
    console.error("The network is undefined!");
    return;
  }

  if (!(network instanceof vis.Network)) {
    console.error("Not a vis.Network instance!");
    return;
  }

  network.stabilize();
  setTimeout(() => { save_topology_view() }, 1000);
}

const drag = () => {
  if (update_view_state_id) {
    clearTimeout(update_view_state_id);
  }

  save_topology_view();
}

const destroy = () => {
  if(network)
    network.destroy(true);

  is_destroyed = true
}

const is_max_entry_reached = () => {
  return max_entries;
}

const update_url_params = (new_url_params) => {
  url_params = new_url_params;
}

const reload = async () => {
  const url = NtopUtils.buildURL(props.url, url_params); 
  await $.get(url, dataRequest, function(response) {
    const {nodes, edges, max_entry_reached} = response.rsp;
    max_entries = max_entry_reached;
    nodes_dataset = new vis.DataSet(nodes);
    edges_dataset = new vis.DataSet(edges);
    const datasets = { nodes: nodes_dataset, edges: edges_dataset }
    empty_network(datasets);
    if(network)
      network.setData(datasets);
    
	  save_topology_view();
  });
}


defineExpose({ reload, destroy, is_max_entry_reached, autolayout, update_url_params });
</script>
