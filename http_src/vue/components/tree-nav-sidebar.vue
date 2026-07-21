<!--
  (C) 2026 - ntop.org
  Generic, depth-unlimited lazy tree sidebar (search + expand/collapse + select).
  See doc/developers/vue_components/tree-nav-sidebar.md for the full contract
  and usage examples.

  Props:
    - loadChildren: Function (required) — async (node) => NodeDescriptor[]
        node is null when loading the root level, otherwise the parent
        NodeDescriptor (the same object your loadChildren previously returned).
        NodeDescriptor = {
          id: String|Number,       // unique among siblings' ids is not enough:
                                    // must be globally unique across the whole tree
          name: String,
          icon: String,             // optional, e.g. "bi bi-hdd-network"
          color: String,             // optional dot color, e.g. "#2fb344"
          hasChildren: Boolean,      // optional hint shown before first expand
                                     // (defaults to true; corrected automatically
                                     // once the node is expanded and its real
                                     // children are known)
          badgeValue: Number|String, // optional right-aligned badge
          badgeFormatter: String,    // optional formatter-utils key
          data: any,                 // optional passthrough payload, returned
                                     // verbatim in on_select / on_toggle
        }
    - title: String — header label (i18n-resolved by caller), default ""
    - searchPlaceholder: String — placeholder text for the search input
    - selectedId: String|Number (optional) — id of the currently active node,
        controls the highlight; the component never picks a selection itself
  Emits:
    - on_select(node, ancestors): fired when a row's label is clicked.
        `node` is the clicked NodeDescriptor. `ancestors` is the real path
        from the root to (but excluding) `node`, i.e. [root, ..., parent] —
        derived from the actual tree structure built while lazily expanding,
        never guessed or hardcoded. Root nodes get `ancestors: []`.
    - on_toggle(node, expanded): fired when a row is expanded/collapsed
  Exposes (via ref):
    - reload(): re-fetches the root level and collapses everything
    - ancestorsOf(nodeId): returns the real ancestor chain of any known node
      id (root-to-parent order), or [] if the id is unknown or a root.
    - expandTo(ancestorIds): expands each id in order (root-to-parent, lazily
      loading children as needed) so a node reached from outside the tree
      (e.g. a table row click) becomes visible/highlighted without the user
      having manually expanded every level first.
-->
<template>
    <div class="tree-nav-sidebar d-flex flex-column" ref="sidebarEl"
        :class="{ 'tree-nav-sidebar--sticky': stickyTop !== null, 'tree-nav-sidebar--resizing': isResizing }"
        :style="{ ...(stickyTop !== null ? { top: stickyTop, height: `calc(100vh - ${stickyTop})` } : {}), width: width + 'px', flexBasis: width + 'px', maxWidth: width + 'px' }">
        <div v-if="title" class="tree-nav-sidebar-title px-2 pt-3 pb-2">{{ title }}</div>

        <div v-if="searchPlaceholder !== null"
            class="tree-nav-sidebar-search d-flex align-items-center gap-2 mx-2 mb-2 px-2 py-1"
            :class="{ 'mt-3': !title }">
            <i class="bi bi-search"></i>
            <input type="text" v-model="search" :placeholder="searchPlaceholder" class="tree-nav-sidebar-search-input" />
        </div>

        <Loading :isLoading="isLoading"></Loading>

        <div class="tree-nav-sidebar-list flex-grow-1 overflow-auto">
            <template v-for="row in visibleRows" :key="row.node.id">
                <sidebar-nav-item :id="row.node.id" :name="row.node.name" :icon="row.node.icon" :color="row.node.color"
                    :depth="row.depth" :selected="String(selectedId) === String(row.node.id)" :matched="row.matched"
                    :has-children="row.node.hasChildren" :expanded="expandedIds.has(row.node.id)"
                    :badge-value="row.node.badgeValue" :badge-formatter="row.node.badgeFormatter"
                    :loading="loadingIds.has(row.node.id)" :disabled="row.node.isEmptyPlaceholder"
                    @on_click="handleSelect(row.node)" @on_toggle="handleToggle(row.node)" />
            </template>

            <NoData v-if="!isLoading && visibleRows.length === 0" :show="true" />
        </div>

        <div class="tree-nav-sidebar-resize-handle" :title="_i18n('tree_nav_sidebar.drag_to_resize')" @mousedown="startResize">
            <div class="tree-nav-sidebar-resize-grip">
                <span></span><span></span><span></span>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, computed, onBeforeMount, onUnmounted, watch } from "vue";
import { default as SidebarNavItem } from "./sidebar-nav-item.vue";
import { default as Loading } from "../loading.vue";
import { default as NoData } from "./no-data.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    loadChildren: {
        type: Function,
        required: true,
    },
    title: {
        type: String,
        default: "",
    },
    searchPlaceholder: {
        type: String,
        default: null, // null hides the search box entirely
    },
    selectedId: [String, Number],
    stickyTop: {
        type: String,
        default: null,
    },
    /* Namespaces the resize-width and lazy-prefetch caches in localStorage so
       multiple tree-nav-sidebar instances */
    cacheKey: {
        type: String,
        default: "default",
    },
});

const emit = defineEmits(["on_select", "on_toggle"]);

const isLoading = ref(true);
const search = ref("");

const MIN_WIDTH = 220;
const MAX_WIDTH = 640;
const DEFAULT_WIDTH = 280;
const WIDTH_STORAGE_KEY = `tree_nav_sidebar_width::${props.cacheKey}`;

function loadStoredWidth() {
    const raw = localStorage.getItem(WIDTH_STORAGE_KEY);
    const parsed = raw != null ? Number.parseInt(raw, 10) : NaN;
    if (Number.isNaN(parsed)) return DEFAULT_WIDTH;
    return Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, parsed));
}

const sidebarEl = ref(null);
const width = ref(loadStoredWidth());
const isResizing = ref(false);
let resizeStartX = 0;
let resizeStartWidth = 0;

function startResize(evt) {
    isResizing.value = true;
    resizeStartX = evt.clientX;
    resizeStartWidth = width.value;
    document.addEventListener("mousemove", onResizeMove);
    document.addEventListener("mouseup", stopResize);
    // Prevents text selection elsewhere on the page while dragging.
    document.body.style.userSelect = "none";
    document.body.style.cursor = "col-resize";
    evt.preventDefault();
}

function onResizeMove(evt) {
    const delta = evt.clientX - resizeStartX;
    width.value = Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, resizeStartWidth + delta));
}

function stopResize() {
    isResizing.value = false;
    document.removeEventListener("mousemove", onResizeMove);
    document.removeEventListener("mouseup", stopResize);
    document.body.style.userSelect = "";
    document.body.style.cursor = "";
    localStorage.setItem(WIDTH_STORAGE_KEY, String(width.value));
}

onUnmounted(() => {
    document.removeEventListener("mousemove", onResizeMove);
    document.removeEventListener("mouseup", stopResize);
});

/* Tree state: nodes keyed by their globally-unique id.
   Each stored node is the caller's NodeDescriptor plus two bookkeeping fields:
   children (array of child ids, or null until first expand) and hasChildren
   (corrected once real children are known). No depth limit: nodes reference
   each other purely by id, so the tree can be arbitrarily deep. */
const nodesById = ref(new Map());
const rootIds = ref([]);
const expandedIds = ref(new Set());
const loadingIds = ref(new Set());

/* In-flight ensureChildrenLoaded() promises, keyed by node id. Concurrent
   callers for the same node*/
const inFlightChildLoads = new Map();

const visibleRows = computed(() => {
    const query = search.value.trim().toLowerCase();
    const rows = [];

    function nodeMatches(node) {
        return !query || node.name.toLowerCase().includes(query);
    }

    function hasMatchingDescendant(node) {
        if (!node.children) return false;
        return node.children.some((childId) => {
            const child = nodesById.value.get(childId);
            if (!child) return false;
            return nodeMatches(child) || hasMatchingDescendant(child);
        });
    }

    /* While searching, every loaded branch is forced open so matches anywhere
       in the (already-fetched) tree stay visible; nothing is auto-expanded
       past what has already been lazily loaded. */
    function walk(id, depth) {
        const node = nodesById.value.get(id);
        if (!node) return;
        const isExpanded = query ? true : expandedIds.value.has(id);
        const selfMatch = nodeMatches(node);
        const children = node.children || [];

        if (!query || selfMatch || hasMatchingDescendant(node)) {
            // Only rows that are themselves a text match get the subtle
            // search-hit highlight -- an ancestor row shown merely because a
            // descendant matches (selfMatch === false) stays unhighlighted,
            // so the highlight always points at the actual hit(s).
            rows.push({ node, depth, matched: !!query && selfMatch });
            if (isExpanded) {
                children.forEach((childId) => walk(childId, depth + 1));
            }
        }
    }

    rootIds.value.forEach((id) => walk(id, 0));
    return rows;
});

onBeforeMount(() => {
    loadRoots();
});

watch(
    () => props.loadChildren,
    () => {
        loadRoots();
    }
);

/* Full-tree cache (see prefetchWholeTree): populated in the background after
   the visible root level has already rendered, so first paint stays fast and
   search/expand latency is hidden rather than avoided. Cached for
   CACHE_TTL_MS so a reload within that window can search immediately without
   waiting on any network round-trip at all. */
const CACHE_TTL_MS = 5 * 60 * 1000;
const TREE_STORAGE_KEY = `tree_nav_sidebar_tree::${props.cacheKey}`;

function loadStoredTree() {
    try {
        const raw = localStorage.getItem(TREE_STORAGE_KEY);
        if (!raw) return null;
        const parsed = JSON.parse(raw);
        if (!parsed || typeof parsed !== "object") return null;
        if (Date.now() - parsed.savedAt > CACHE_TTL_MS) return null;
        if (!Array.isArray(parsed.rootIds) || !Array.isArray(parsed.nodes)) return null;
        return parsed;
    } catch (_) {
        return null;
    }
}

function saveTreeCache() {
    try {
        const nodes = [...nodesById.value.entries()];
        localStorage.setItem(TREE_STORAGE_KEY, JSON.stringify({
            savedAt: Date.now(),
            rootIds: rootIds.value,
            nodes,
        }));
    } catch (_) {
        // storage full/unavailable (e.g. quota, or a genuinely circular/huge
        // data payload): caching is a latency optimization, not required for correctness
    }
}

async function loadRoots() {
    const cached = loadStoredTree();
    expandedIds.value = new Set();

    if (cached) {
        // Instant hydrate from cache (whole tree, not just the root level) so
        // the tree -- and search across branches never manually expanded --
        // is usable immediately; still followed by a live fetch below to
        // refresh the root level (and, via prefetchWholeTree, everything else).
        const map = new Map();
        cached.nodes.forEach(([id, node]) => map.set(id, node));
        nodesById.value = map;
        rootIds.value = cached.rootIds;
        isLoading.value = false;
    } else {
        nodesById.value = new Map();
        isLoading.value = true;
    }

    const children = await safeLoadChildren(null);
    // Merge fresh root nodes into whatever cache-hydrated state exists
    // instead of discarding it -- otherwise every deeper cached node would be
    // orphaned (still in the map, but unreferenced once the root's children
    // pointer is reset) and only the root level would survive the refresh.
    children.forEach((node) => {
        const existing = nodesById.value.get(node.id);
        const normalized = normalizeNode(node, null);
        if (existing && existing.children !== null && existing.children !== undefined) {
            normalized.children = existing.children;
        }
        nodesById.value.set(node.id, normalized);
    });
    rootIds.value = children.map((n) => n.id);
    isLoading.value = false;
    // Walk the *normalized* (and possibly cache-restored) root nodes from
    // nodesById, not the raw `children` array loadChildren returned: raw
    // NodeDescriptors have children === undefined, which fails
    // ensureChildrenLoaded's "already loaded" guard (children !== null) and
    // made every root immediately look "already loaded" without ever having
    // fetched anything, so the walk never actually descended past the roots.
    prefetchWholeTree(rootIds.value.map((id) => nodesById.value.get(id)).filter(Boolean));
}

/* Recursively walks the whole tree in the background (after the root level
   has already rendered) so every branch's children are fetched and cached up
   front -- this is what lets search actually find matches under branches the
   user hasn't manually expanded yet, and lets an actual click on a node the
   walk already reached resolve instantly instead of re-fetching (see
   visibleRows/hasMatchingDescendant). Routes every fetch through
   ensureChildrenLoaded, the same single-flight loader handleToggle/expandTo
   use, so a node already being (or having been) fetched by a user click is
   never fetched a second time here, and vice versa. Fire-and-forget: nothing
   awaits this from the caller, it just populates nodesById/localStorage as it
   goes; the loading count/spinner is also skipped for background nodes since
   nothing on screen is waiting on them (see ensureChildrenLoaded's
   showLoading param). */
let prefetchGeneration = 0;
async function prefetchWholeTree(rootNodes) {
    const generation = ++prefetchGeneration;

    async function walk(node) {
        if (generation !== prefetchGeneration) return; // a fresh loadRoots() superseded this run
        if (node.isEmptyPlaceholder || node.hasChildren === false) return;

        await ensureChildrenLoaded(node, /* showLoading */ false);
        if (generation !== prefetchGeneration) return;

        const stored = nodesById.value.get(node.id);
        const children = (stored?.children || []).map((id) => nodesById.value.get(id)).filter(Boolean);
        await Promise.all(children.map((child) => walk(child)));
    }

    await Promise.all(rootNodes.map((node) => walk(node)));
    if (generation === prefetchGeneration) saveTreeCache();
}

/* parentId is recorded on every node as it enters the tree (null for roots).
   This is the only source of ancestry: nothing about "who is whose parent" is
   ever guessed or hardcoded by a caller — it is exactly the structure
   loadChildren built while the user lazily expanded the tree. */
function normalizeNode(node, parentId) {
    return {
        ...node,
        parentId,
        hasChildren: node.hasChildren !== false,
        children: node.children ?? null,
    };
}

/* Real ancestor chain of `nodeId`, root-first, excluding `nodeId` itself.
   Returns [] for an unknown id or a root node. Works for any depth since it
   simply follows parentId pointers recorded when each node was first loaded. */
function ancestorsOf(nodeId) {
    const chain = [];
    let current = nodesById.value.get(nodeId);
    while (current && current.parentId !== null && current.parentId !== undefined) {
        const parent = nodesById.value.get(current.parentId);
        if (!parent) break;
        chain.unshift(parent);
        current = parent;
    }
    return chain;
}

async function safeLoadChildren(node) {
    try {
        const result = await props.loadChildren(node);
        return Array.isArray(result) ? result : [];
    } catch (err) {
        console.error("tree-nav-sidebar: loadChildren failed", err);
        return [];
    }
}

async function handleToggle(node) {
    if (node.hasChildren === false) return;
    const id = node.id;
    if (expandedIds.value.has(id)) {
        expandedIds.value = new Set([...expandedIds.value].filter((x) => x !== id));
        emit("on_toggle", node, false);
        return;
    }

    await ensureChildrenLoaded(node);
    expandedIds.value = new Set([...expandedIds.value, id]);
    emit("on_toggle", node, true);
}

/* Lazily loads and stores a node's children (once), independent of the
   expanded/collapsed state — shared by handleToggle, expandTo, and the
   background prefetchWholeTree walk. Concurrent callers for the same node id
   (see inFlightChildLoads) await the one fetch already in flight instead of
   each starting their own, so a user click on a node the background prefetch
   is already fetching (or has already fetched) never re-fetches it.
   showLoading=false (used by the background walk) skips the spinner state
   since nothing on screen is waiting on that particular fetch. */
async function ensureChildrenLoaded(node, showLoading = true) {
    const id = node.id;
    if (node.hasChildren === false || node.children !== null) return;

    const existing = inFlightChildLoads.get(id);
    if (existing) return existing;

    const promise = (async () => {
        if (showLoading) loadingIds.value = new Set([...loadingIds.value, id]);
        try {
            let children = await safeLoadChildren(node);
            const badgeValue = children.length > 0 ? children.length : null;
            if (children.length === 0) {
                children = [makeEmptyNode(id)];
            }
            children.forEach((child) => nodesById.value.set(child.id, normalizeNode(child, id)));
            node.children = children.map((c) => c.id);
            node.badgeValue = badgeValue;
            node.badgeFormatter = "no_formatting";
            /* The chevron always stays visible: a node can always be expanded
               again to re-check for children, regardless of what was found. */
            nodesById.value.set(id, { ...node });
        } finally {
            if (showLoading) loadingIds.value = new Set([...loadingIds.value].filter((x) => x !== id));
            inFlightChildLoads.delete(id);
        }
    })();

    inFlightChildLoads.set(id, promise);
    return promise;
}

/* Reveals a node reached through a path the caller already knows (e.g. a
   drill-down triggered from outside the tree, like a table row click),
   without requiring the user to have manually expanded each level first.
   ancestorIds must be root-to-parent order, matching on_select's ancestors
   shape; each is expanded in turn, lazily loading children as needed. */
async function expandTo(ancestorIds) {
    for (const id of ancestorIds) {
        const node = nodesById.value.get(id);
        if (!node) return;
        if (node.hasChildren === false) continue;
        await ensureChildrenLoaded(node);
        expandedIds.value = new Set([...expandedIds.value, id]);
    }
}

function makeEmptyNode(parentId) {
    return {
        id: `${parentId}::empty`,
        name: _i18n("tree_nav_sidebar.no_data_available"),
        isEmptyPlaceholder: true,
        hasChildren: false,
        children: [],
    };
}

function handleSelect(node) {
    if (node.isEmptyPlaceholder) return;
    // Clicking the label expands/collapses too, same as the chevron, so the
    // user doesn't have to hit the tiny chevron target to reveal children.
    // Only toggle here when the node is already selected: for a newly
    // selected node the caller reacts to on_select by re-navigating and
    // calling expandTo() itself (see revealInSidebar in page-sites-dashboard),
    // which always expands -- so toggling here too would just be redundant.
    // But collapsing an *already selected* node has nothing else forcing it
    // back open, so that's the one case this needs to handle directly.
    const alreadySelected = String(props.selectedId) === String(node.id);
    if (node.hasChildren !== false && (alreadySelected || !expandedIds.value.has(node.id))) {
        handleToggle(node);
    }
    emit("on_select", node, ancestorsOf(node.id));
}

async function reload() {
    await loadRoots();
}

defineExpose({ reload, ancestorsOf, expandTo });
</script>

<style scoped>
.tree-nav-sidebar {
    position: relative;
    background: #12151a;
    height: 100%;
    border-right: 1px solid #0c0e12;
    flex-shrink: 0;
}

.tree-nav-sidebar--sticky {
    position: sticky;
    align-self: flex-start;
}

.tree-nav-sidebar--resizing {
    transition: none !important;
}

.tree-nav-sidebar-resize-handle {
    position: absolute;
    top: 0;
    right: -6px;
    width: 13px;
    height: 100%;
    cursor: col-resize;
    z-index: 5;
    display: flex;
    align-items: center;
    justify-content: center;
}

/* The draggable edge itself: a hairline, faint at rest so it reads as a
   normal border rather than a UI element sitting in front of content, and
   only brightening on hover/drag to confirm it's interactive. The handle's
   own hitbox (13px wide, see .tree-nav-sidebar-resize-handle) stays generous
   for an easy grab even though nothing that wide is ever drawn. */
.tree-nav-sidebar-resize-handle::before {
    content: "";
    position: absolute;
    top: 0;
    left: 5px;
    width: 1px;
    height: 100%;
    background: rgba(234, 106, 42, 0.25);
    transition: background-color 0.15s ease, width 0.15s ease;
}

.tree-nav-sidebar-resize-handle:hover::before,
.tree-nav-sidebar--resizing .tree-nav-sidebar-resize-handle::before {
    background: var(--ntop-orange, #EA6A2A);
    width: 2px;
}

/* Grip: a small, always-solid orange pill with dots -- stays highlighted at
   rest (not just on hover) so it constantly signals "this is resizable",
   growing slightly and gaining a shadow on hover/drag to confirm the drag is
   live. */
.tree-nav-sidebar-resize-grip {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    width: 8px;
    height: 18px;
    border-radius: 3px;
    justify-content: center;
    background: var(--ntop-orange, #EA6A2A);
    transition: background-color 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}

.tree-nav-sidebar-resize-handle:hover .tree-nav-sidebar-resize-grip,
.tree-nav-sidebar--resizing .tree-nav-sidebar-resize-grip {
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
    transform: scaleX(1.25);
}

.tree-nav-sidebar-resize-grip span {
    width: 2px;
    height: 2px;
    border-radius: 50%;
    background: #12151a;
}

.tree-nav-sidebar-resize-handle:hover .tree-nav-sidebar-resize-grip span,
.tree-nav-sidebar--resizing .tree-nav-sidebar-resize-grip span {
    background: #12151a;
}

@media (max-width: 992px) {
    .tree-nav-sidebar {
        width: 100% !important;
        max-width: 100% !important;
        flex: 1 1 auto;
        height: 320px;
        border-right: none;
        border-bottom: 1px solid #0c0e12;
    }

    .tree-nav-sidebar--sticky {
        position: static;
        height: 320px;
    }

    .tree-nav-sidebar-resize-handle {
        display: none;
    }
}

.tree-nav-sidebar-title {
    font-size: 10.5px;
    font-weight: 700;
    color: #7c8494;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.tree-nav-sidebar-search {
    background: #1c212b;
    border-radius: 7px;
    color: #5c6472;
}

.tree-nav-sidebar-search-input {
    border: none;
    outline: none;
    background: transparent;
    color: #c7ccd4;
    font-size: 12.5px;
    width: 100%;
}

.tree-nav-sidebar-list {
    overflow-x: auto;
    overflow-y: auto;
}
</style>
