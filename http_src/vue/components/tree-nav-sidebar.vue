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
    <div class="tree-nav-sidebar d-flex flex-column"
        :class="{ 'tree-nav-sidebar--sticky': stickyTop !== null }"
        :style="stickyTop !== null ? { top: stickyTop, height: `calc(100vh - ${stickyTop})` } : {}">
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
                    :depth="row.depth" :selected="String(selectedId) === String(row.node.id)"
                    :has-children="row.node.hasChildren" :expanded="expandedIds.has(row.node.id)"
                    :badge-value="row.node.badgeValue" :badge-formatter="row.node.badgeFormatter"
                    :loading="loadingIds.has(row.node.id)" :disabled="row.node.isEmptyPlaceholder"
                    @on_click="handleSelect(row.node)" @on_toggle="handleToggle(row.node)" />
            </template>

            <NoData v-if="!isLoading && visibleRows.length === 0" :show="true" />
        </div>
    </div>
</template>

<script setup>
import { ref, computed, onBeforeMount, watch } from "vue";
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
});

const emit = defineEmits(["on_select", "on_toggle"]);

const isLoading = ref(true);
const search = ref("");

/* Tree state: nodes keyed by their globally-unique id.
   Each stored node is the caller's NodeDescriptor plus two bookkeeping fields:
   children (array of child ids, or null until first expand) and hasChildren
   (corrected once real children are known). No depth limit: nodes reference
   each other purely by id, so the tree can be arbitrarily deep. */
const nodesById = ref(new Map());
const rootIds = ref([]);
const expandedIds = ref(new Set());
const loadingIds = ref(new Set());

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
            rows.push({ node, depth });
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

async function loadRoots() {
    isLoading.value = true;
    expandedIds.value = new Set();
    const children = await safeLoadChildren(null);
    nodesById.value = new Map();
    children.forEach((node) => nodesById.value.set(node.id, normalizeNode(node, null)));
    rootIds.value = children.map((n) => n.id);
    isLoading.value = false;
    prefetchChildCounts(children);
}

/* Fires one loadChildren call per node to
   learn how many children each row has. */
function prefetchChildCounts(nodes) {
    nodes.forEach(async (node) => {
        if (node.isEmptyPlaceholder || node.hasChildren === false) return;
        if (node.children !== null && node.children !== undefined) return;
        try {
            const kids = await safeLoadChildren(node);
            const stored = nodesById.value.get(node.id);
            if (!stored || stored.children !== null) return; // already expanded/toggled meanwhile
            stored.badgeValue = kids.length > 0 ? kids.length : null;
            stored.badgeFormatter = "no_formatting";
            stored.hasChildren = kids.length > 0;
            nodesById.value.set(node.id, { ...stored });
        } catch (_) {
            // leave the row without a badge
        }
    });
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
   expanded/collapsed state — shared by handleToggle and expandTo. */
async function ensureChildrenLoaded(node) {
    const id = node.id;
    if (node.hasChildren === false || node.children !== null || loadingIds.value.has(id)) return;

    loadingIds.value = new Set([...loadingIds.value, id]);

    let children = await safeLoadChildren(node);
    if (children.length === 0) {
        children = [makeEmptyNode(id)];
    }
    children.forEach((child) => nodesById.value.set(child.id, normalizeNode(child, id)));
    node.children = children.map((c) => c.id);
    /* The chevron always stays visible: a node can always be expanded
       again to re-check for children, regardless of what was found. */
    nodesById.value.set(id, node);
    prefetchChildCounts(children.filter((c) => !c.isEmptyPlaceholder));

    loadingIds.value = new Set([...loadingIds.value].filter((x) => x !== id));
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
    emit("on_select", node, ancestorsOf(node.id));
}

async function reload() {
    await loadRoots();
}

defineExpose({ reload, ancestorsOf, expandTo });
</script>

<style scoped>
.tree-nav-sidebar {
    width: 280px;
    flex: 0 0 280px;
    max-width: 280px;
    background: #12151a;
    height: 100%;
    border-right: 1px solid #0c0e12;
}

.tree-nav-sidebar--sticky {
    position: sticky;
    align-self: flex-start;
}

@media (max-width: 992px) {
    .tree-nav-sidebar {
        width: 100%;
        max-width: 100%;
        flex: 1 1 auto;
        height: 320px;
        border-right: none;
        border-bottom: 1px solid #0c0e12;
    }

    .tree-nav-sidebar--sticky {
        position: static;
        height: 320px;
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
