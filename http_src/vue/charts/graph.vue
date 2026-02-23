<!--
  (C) 2024 - ntop.org

  D3 v7 Graph chart — directed graph with nodes and edges.

  Props:
    nodes         Array<{ id, label?, column?, ...custom }>
                  For 'lr' layout each node must have a `column` (Number, 0 = leftmost).
    edges         Array<{ source: nodeId, target: nodeId, label?, value?, ...custom }>
                  value (Number) — when present the stroke-width is scaled across all
                  valued edges in the range [MIN_EDGE_WIDTH … MAX_EDGE_WIDTH].
    layout        'force' | 'lr'
                    force – physics-based force-directed graph (default)
                    lr    – left-to-right column layout, ideal for traffic-flow diagrams
                            (e.g. client -> hop1 -> hop2 -> server)
    format_node   (node)               => { label, color, radius, stroke, stroke_width }
    format_edge   (edge, src, tgt)     => { label, color, width, dashed }
    on_node_click (node)               => void   (alternative to the 'node_click' emit)
    on_edge_click (edge)               => void   (alternative to the 'edge_click' emit)
    height        Number (default 400px)

  Emits:
    node_click(node)   — fired when a node circle is clicked
    edge_click(edge)   — fired when an edge line/curve is clicked
-->
<template>
  <div ref="container_ref" class="graph-container" :style="{ height: height + 'px' }">
    <svg ref="svg_ref" class="graph-svg">
      <defs ref="defs_ref" />
      <g ref="graph_g_ref" />
    </svg>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch } from "vue";

const d3 = d3v7;

/* Props */

const props = defineProps({
  nodes: { type: Array, default: () => [] },
  edges: { type: Array, default: () => [] },
  layout: { type: String, default: "force" },
  format_node: { type: Function, default: null },
  format_edge: { type: Function, default: null },
  on_node_click: { type: Function, default: null },
  on_edge_click: { type: Function, default: null },
  height: { type: Number, default: 400 },
});

const emit = defineEmits(["node_click", "edge_click"]);

const container_ref = ref(null);
const svg_ref       = ref(null);
const graph_g_ref   = ref(null);
const defs_ref      = ref(null);

/* Internal state */

let simulation      = null;
let zoom_behavior   = null;
let resize_observer = null;

/* Format helpers */

const NODE_DEFAULTS = { label: "", color: "#4e79a7", radius: 20, stroke: "#2a5f8f", stroke_width: 2 };
const EDGE_DEFAULTS  = { label: "", color: "#999999", width: 2, dashed: false };
const MIN_EDGE_WIDTH = 1.5;   // minimum stroke-width when value scaling is active
const MAX_EDGE_WIDTH = 12;    // maximum stroke-width

function node_formatter(d) {
  const base = { ...NODE_DEFAULTS, label: String(d.label ?? d.id ?? "") };
  return props.format_node ? { ...base, ...props.format_node(d) } : base;
}

function edge_formatter(e, src, tgt) {
  const base = { ...EDGE_DEFAULTS, label: String(e.label ?? "") };
  return props.format_edge ? { ...base, ...props.format_edge(e, src, tgt) } : base;
}

/* Main draw */

function draw() {
  if (!svg_ref.value || !graph_g_ref.value || !defs_ref.value) return;

  if (simulation) { simulation.stop(); simulation = null; }

  const width = container_ref.value?.clientWidth || 600;
  const height = props.height;

  const svg  = d3.select(svg_ref.value).attr("width", width).attr("height", height);
  const g    = d3.select(graph_g_ref.value);
  const defs = d3.select(defs_ref.value);

  /* Working copies. D3 mutates x/y/fx/fy onto these */
  const nodes   = props.nodes.map((node) => ({ ...node, _id: String(node.id) }));
  const by_id = Object.fromEntries(nodes.map((node) => [node._id, node]));

  const links = props.edges.map((e) => {
    const src = String(e.source), dst = String(e.target);
    return { _e: e, src: src, dst: dst, source: by_id[src] ?? src, target: by_id[dst] ?? dst };
  });

  nodes.forEach((node) => { node._fmt = node_formatter(node); });
  links.forEach((link) => { link._fmt = edge_formatter(link._e, by_id[link.src], by_id[link.dst]); });

  /* Value-based edge width scaling — when edges carry a numeric `value` field,
   * widths are mapped linearly from MIN_EDGE_WIDTH (smallest value) to MAX_EDGE_WIDTH
   * (largest value).  Edges without a value keep their format_edge width. */
  const valued = links.filter((link) => typeof link._e.value === "number");
  if (valued.length > 0) {
    const val_min = Math.min(...valued.map((link) => link._e.value));
    const val_max = Math.max(...valued.map((link) => link._e.value));
    const range = val_max - val_min;
    
    valued.forEach((link) => {
      const dst = range > 0 ? (link._e.value - val_min) / range : 1;
      link._fmt.width = MIN_EDGE_WIDTH + dst * (MAX_EDGE_WIDTH - MIN_EDGE_WIDTH);
    });
  }

  /* Bidirectional edge detection
   * When both A -> B and B -> A exist the pair is rendered as two opposite side
   * quadratic bezier curves so both arrows remain visually distinct.
   * Edges without a reverse counterpart stay as straight lines. */
  const fwd_set   = new Set(links.map((link) => `${link.src}->${link.dst}`));
  const bidir_set = new Set(links.filter((link) => fwd_set.has(`${link.dst}->${link.src}`)).map((link) => `${link.src}->${link.dst}`)
  );

  const CURVE_AMP = 40;

  /* SVG path string for one edge.
   * - Bidirectional pair  -> quadratic bezier, offset to each side so both arrows are visible.
   * - LR layout           -> cubic S-curve (control points share x-midpoint, keep source/target y).
   *                          This naturally spreads parallel edges that share the same target.
   * - Force layout        -> straight line. */
  function edge_path(d) {
    const sx0 = d.source.x, sy0 = d.source.y;
    const tx  = d.target.x,  ty  = d.target.y;
    const dx = tx - sx0, dy = ty - sy0;
    const dist = Math.hypot(dx, dy) || 1;

    /* Start on source border; end short of target border to leave room for arrowhead */
    const sx = sx0 + (dx / dist) * d.source._fmt.radius;
    const sy = sy0 + (dy / dist) * d.source._fmt.radius;
    const ex = tx  - (dx / dist) * (d.target._fmt.radius + 7);
    const ey = ty  - (dy / dist) * (d.target._fmt.radius + 7);

    if (bidir_set.has(`${d.src}->${d.dst}`)) {
      /* Perpendicular offset: edge with smaller source id curves +side, other −side */
      const mx = (sx + ex) / 2, my = (sy + ey) / 2;
      const sign = Number(d.src) < Number(d.dst) ? 1 : -1;
      const cpx = mx + sign * CURVE_AMP * (-dy / dist);
      const cpy = my + sign * CURVE_AMP * ( dx / dist);
      return `M${sx},${sy} Q${cpx},${cpy} ${ex},${ey}`;
    }

    if (props.layout === "lr") {
      /* S-curve: horizontal tangent at both ends, natural fanout for parallel edges */
      const mid_x = (sx + ex) / 2;
      return `M${sx},${sy} C${mid_x},${sy} ${mid_x},${ey} ${ex},${ey}`;
    }

    return `M${sx},${sy} L${ex},${ey}`;
  }

  /* Label anchor: midpoint for straight S-curve, bezier midpoint (t=0.5) for curved */
  function edge_label_xy(d) {
    const sx0 = d.source.x, sy0 = d.source.y;
    const tx  = d.target.x,  ty  = d.target.y;
    const dx = tx - sx0, dy = ty - sy0;
    const dist = Math.hypot(dx, dy) || 1;
    const sx = sx0 + (dx / dist) * d.source._fmt.radius;
    const sy = sy0 + (dy / dist) * d.source._fmt.radius;
    const ex = tx  - (dx / dist) * (d.target._fmt.radius + 7);
    const ey = ty  - (dy / dist) * (d.target._fmt.radius + 7);

    if (bidir_set.has(`${d.src}->${d.dst}`)) {
      const mx = (sx + ex) / 2, my = (sy + ey) / 2;
      const sign = Number(d.src) < Number(d.dst) ? 1 : -1;
      const cpx = mx + sign * CURVE_AMP * (-dy / dist);
      const cpy = my + sign * CURVE_AMP * (dx / dist);
      
      /* Quadratic bezier midpoint: 0.25·P0 + 0.5·CP + 0.25·P3 */
      return { x: 0.25*sx + 0.5*cpx + 0.25*ex, y: 0.25*sy + 0.5*cpy + 0.25*ey - 6 };
    }
    /* Geometric midpoint works for both straight lines and S-curves */
    return { x: (sx + ex) / 2, y: (sy + ey) / 2 - 6 };
  }

  /* Arrow-head markers */
  defs.selectAll("marker").remove();
  [...new Set(links.map((link) => link._fmt.color))].forEach((color) => {
    const mid = `arrow-${color.replace(/[^a-zA-Z0-9]/g, "")}`;
    defs.append("marker")
      .attr("id", mid).attr("viewBox", "0 -5 10 10")
      .attr("refX", 10).attr("refY", 0)
      .attr("markerWidth", 6).attr("markerHeight", 6)
      .attr("orient", "auto")
      .append("path").attr("d", "M0,-5L10,0L0,5").attr("fill", color);
  });

  g.selectAll("*").remove();
  const graph_links  = g.append("g").attr("class", "g-links");
  const graph_link_labels = g.append("g").attr("class", "g-link-labels");
  const graph_nodes  = g.append("g").attr("class", "g-nodes");
  const graph_node_labels = g.append("g").attr("class", "g-node-labels");

  /* Edges */
  const link_sel = graph_links.selectAll("path").data(links).join("path")
    .attr("fill",             "none")
    .attr("stroke",           (d) => d._fmt.color)
    .attr("stroke-width",     (d) => d._fmt.width)
    .attr("stroke-dasharray", (d) => d._fmt.dashed ? "6,3" : null)
    .attr("marker-end",       (d) => `url(#arrow-${d._fmt.color.replace(/[^a-zA-Z0-9]/g, "")})`)
    .style("cursor", "pointer")
    .on("click", (ev, d) => {
      ev.stopPropagation();
      emit("edge_click", d._e);
      props.on_edge_click?.(d._e);
    });

  /* Edge labels */
  const ll_sel = graph_link_labels.selectAll("text").data(links.filter((d) => d._fmt.label)).join("text")
    .attr("text-anchor", "middle").attr("dominant-baseline", "middle")
    .attr("font-size", "11px").attr("fill", "#555")
    .style("pointer-events", "none")
    .text((d) => d._fmt.label);

  /* Nodes */
  const node_sel = graph_nodes.selectAll("circle").data(nodes, (d) => d._id).join("circle")
    .attr("r",            (d) => d._fmt.radius)
    .attr("fill",         (d) => d._fmt.color)
    .attr("stroke",       (d) => d._fmt.stroke)
    .attr("stroke-width", (d) => d._fmt.stroke_width)
    .style("cursor", "grab")
    .on("click", (ev, d) => {
      ev.stopPropagation();
      emit("node_click", d);
      props.on_node_click?.(d);
    });

  /* Node labels */
  const nl_sel = graph_node_labels.selectAll("text").data(nodes, (d) => d._id).join("text")
    .attr("text-anchor", "middle")
    .attr("font-size", "12px").attr("fill", "#222")
    .style("pointer-events", "none")
    .text((d) => d._fmt.label);

  /* Tick: push positions into DOM */
  function tick() {
    node_sel.attr("cx", (d) => d.x).attr("cy", (d) => d.y);
    nl_sel.attr("x",  (d) => d.x).attr("y", (d) => d.y + d._fmt.radius + 14);
    link_sel.attr("d", edge_path);
    ll_sel.attr("x", (d) => edge_label_xy(d).x).attr("y", (d) => edge_label_xy(d).y);
  }

  /* Layout */
  if (props.layout === "lr") {
    lr_positions(nodes, links, width, height);
    tick();

    /* LR drag: no simulation update x/y directly and re-tick */
    node_sel.call(
      d3.drag()
        .on("start", () => { node_sel.style("cursor", "grabbing"); })
        .on("drag",  (ev, d) => { d.x = ev.x; d.y = ev.y; tick(); })
        .on("end",   () => { node_sel.style("cursor", "grab"); })
    );

    setTimeout(() => fit(svg, g, width, height), 0);
  } else {
    /* Force layout with drag */
    node_sel.call(
      d3.drag()
        .on("start", (ev, d) => {
          node_sel.style("cursor", "grabbing");
          if (!ev.active) simulation.alphaTarget(0.3).restart();
          d.fx = d.x; d.fy = d.y;
        })
        .on("drag", (ev, d) => { d.fx = ev.x; d.fy = ev.y; })
        .on("end",  (ev, d) => {
          node_sel.style("cursor", "grab");
          if (!ev.active) simulation.alphaTarget(0);
          d.fx = null; d.fy = null;
        })
    );

    simulation = d3.forceSimulation(nodes)
      .force("link",      d3.forceLink(links).id((d) => d._id).distance(120))
      .force("charge",    d3.forceManyBody().strength(-350))
      .force("center",    d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius((d) => d._fmt.radius + 10))
      .on("tick", tick);
  }

  /* Zoom & pan */
  zoom_behavior = d3.zoom()
    .scaleExtent([0.05, 10])
    .on("zoom", (ev) => g.attr("transform", ev.transform));
  svg.call(zoom_behavior);
}

/* LR layout */

function lr_positions(nodes, links, width, height) {
  const px = 80, py = 60;
  const col_map = {};
  nodes.forEach((n) => { (col_map[n.column ?? 0] ??= []).push(n); });
  let keys = Object.keys(col_map).map(Number).sort((a, b) => a - b);

  /* Enforce: leftmost and rightmost columns must have at most 1 node */
  if (keys.length >= 2) {
    if (col_map[keys[0]].length > 1) {
      const vk = (keys[0] + keys[1]) / 2;
      const extras = col_map[keys[0]].splice(1);
      (col_map[vk] ??= []).push(...extras);
      keys = Object.keys(col_map).map(Number).sort((a, b) => a - b);
    }
    if (col_map[keys[keys.length - 1]].length > 1) {
      const vk = (keys[keys.length - 2] + keys[keys.length - 1]) / 2;
      const extras = col_map[keys[keys.length - 1]].splice(1);
      (col_map[vk] ??= []).push(...extras);
      keys = Object.keys(col_map).map(Number).sort((a, b) => a - b);
    }
  }

  /* Minimise edge crossings */
  const id_to_row = {};
  keys.forEach((k) => col_map[k].forEach((n, i) => { id_to_row[n._id] = i; }));

  for (let pass = 0; pass < 3; pass++) {
    keys.forEach((k, ki) => {
      if (ki === 0 || ki === keys.length - 1) return; /* preserve extreme positions */
      const col_nodes = col_map[k];
      const scores = col_nodes.map((n) => {
        const connected = links.filter((l) => l.src === n._id || l.dst === n._id);
        if (!connected.length) return 0;
        const sum = connected.reduce((acc, l) => {
          const other = l.src === n._id ? l.dst : l.src;
          return acc + (id_to_row[other] ?? 0);
        }, 0);
        return sum / connected.length;
      });
      col_map[k] = col_nodes.map((n, i) => ({ n, s: scores[i] }))
        .sort((a, b) => a.s - b.s)
        .map(({ n }) => n);
      col_map[k].forEach((n, i) => { id_to_row[n._id] = i; });
    });
  }

  const MAX_COL_GAP = 150;
  const spread = keys.length > 1 ? Math.min(width - 2 * px, MAX_COL_GAP * (keys.length - 1)) : 0;
  const x_offset = keys.length > 1 ? (width - spread) / 2 : width / 2;

  keys.forEach((k, ci) => {
    const x = keys.length > 1 ? x_offset + (ci / (keys.length - 1)) * spread : width / 2;
    col_map[k].forEach((n, ni, arr) => {
      n.x = n.fx = x;
      n.y = n.fy = arr.length === 1 ? height / 2 : py + (ni / (arr.length - 1)) * (height - 2 * py);
    });
  });
}

/* Fit to view  */

function fit(svg, g, width, height) {
  const bb = g.node()?.getBBox();
  if (!bb || bb.width === 0 || bb.height === 0) return;
  const src  = Math.min(width / (bb.width + 80), height / (bb.height + 80)) * 0.9;
  const tx = (width - bb.width  * src) / 2 - bb.x * src;
  const ty = (height - bb.height * src) / 2 - bb.y * src;

  svg.transition().duration(400)
    .call(zoom_behavior.transform, d3.zoomIdentity.translate(tx, ty).scale(src));
}

onMounted(() => {
  resize_observer = new ResizeObserver(draw);
  resize_observer.observe(container_ref.value);
  draw();
});

onBeforeUnmount(() => {
  simulation?.stop();
  resize_observer?.disconnect();
});

watch(() => [props.nodes, props.edges, props.layout, props.height], draw, { deep: true });

</script>


