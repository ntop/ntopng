<!--
  (C) 2024 - ntop.org

  Show network path from client to server 

  Data format:
    nodes : [{ id, label, color?, first? }]
    edges : [{ from, to, return_path? }]
-->
<template>
  <div class="exporter-graph-wrap">
    <!-- Legend -->
    <div class="d-flex gap-4 py-1">
      <span class="d-flex align-items-center gap-2">
        <svg width="14" height="14"><circle cx="7" cy="7" r="6" fill="#FFCA28" stroke="#b8960f" stroke-width="1.5"/></svg>
        {{ _i18n('client') }}
      </span>
      <span class="d-flex align-items-center gap-2">
        <svg width="14" height="14"><circle cx="7" cy="7" r="6" fill="#FF7043" stroke="#b34d27" stroke-width="1.5"/></svg>
        {{ _i18n('server') }}
      </span>
      <span class="d-flex align-items-center gap-2">
        <svg width="14" height="14"><circle cx="7" cy="7" r="6" fill="#42A5F5" stroke="#1976d2" stroke-width="1.5"/></svg>
        {{ _i18n('hop_exporter') }}
      </span>
      <span class="d-flex align-items-center gap-2 ">
        <svg width="40" height="14">
          <line x1="0" y1="7" x2="38" y2="7" stroke="#adb5bd" stroke-width="1.5" stroke-dasharray="4,3"/>
        </svg>
        {{ _i18n('return_path') }}
      </span>
    </div>
    
    <Graph
      ref="graph_ref"
      :nodes="nodes"
      :edges="edges"
      layout="lr"
      height="35vh"
      :format_node="format_node"
      :format_edge="format_edge"
      @node_click="on_node_click"
      @edge_click="on_edge_click"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as Graph } from "../charts/graph.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

const graph_ref = ref(null);
const nodes     = ref([]);
const edges     = ref([]);

function topology_to_graph(input_nodes, input_edges) {
  // Build forward adj_listacency list
    const adj_list = {};
  
  input_edges.forEach(({ from, to, return_path }) => {
    if (!return_path) {
      (adj_list[from] ??= []).push(to);
    }
  });

  // Longest path BFS from the client node (first: true) to assign columns
  const client = input_nodes.find((n) => n.first) ?? input_nodes[0];
  const col_map = {};
  const queue   = [client.id];
  col_map[client.id] = 0;

  while (queue.length > 0) {
    const current = queue.shift();
    const current_col = col_map[current];
    
    (adj_list[current] ?? []).forEach((next) => {
      if ((col_map[next] ?? -1) < current_col + 1) {
        col_map[next] = current_col + 1;
        queue.push(next);
      }
    });
  }

  // Any node not reachable on the forward path, gets the maximum column so it still renders on the right.
  const max_col = Math.max(0, ...Object.values(col_map));
  input_nodes.forEach((n) => { col_map[n.id] ??= max_col; });

  const out_nodes = input_nodes.map((n) => ({
    id:     n.id,
    label:  n.label  ?? String(n.id),
    color:  n.color  ?? null,
    first:  n.first  ?? false,
    column: col_map[n.id],
  }));

  const out_edges = input_edges.map((e) => ({
    source:      e.from,
    target:      e.to,
    return_path: e.return_path ?? false,
  }));

  return { nodes: out_nodes, edges: out_edges };
}

/* Node edges formatters */

function format_node(node) {
  const color = node.color ?? "#42A5F5";

  const stroke_map = {
    "#FFCA28": "#b8960f",
    "#FF7043": "#b34d27",
    "#42A5F5": "#1976d2",
  };
  const stroke = stroke_map[color] ?? "#1565c0";

  const radius = (node.first || node.color === "#FF7043") ? 18 : 14;

  return { label: node.label, color, stroke, stroke_width: 2, radius };
}

function format_edge(edge /*, src, dst */) {
  return edge.return_path
    ? { color: "#adb5bd", width: 1.5, dashed: true  }
    : { color: "#6ea8fe", width: 2,   dashed: false };
}

/* Node click formatter */

function on_node_click(node) {
  if (node.link) ntopng_url_manager.go_to_url(node.link);
}

function on_edge_click(edge) {
    /* FIXME: Add interface name */
    //console.log(edge)
}

/* Init Component */

onMounted(() => {
  if (!props.context?.nodes?.length) return;
  const { nodes: n, edges: e } = topology_to_graph(props.context.nodes, props.context.edges ?? []);
  nodes.value = n;
  edges.value = e;
});

</script>

<style scoped>
.exporter-graph-wrap {
  max-width: 70vw;
  overflow: hidden;
}
</style>
