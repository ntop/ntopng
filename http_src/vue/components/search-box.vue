<!--
    (C) 2013-26 - ntop.org
-->

<template>
    <!-- Search container (expandable input + button + spinner) -->
    <div
        :class="[
            'ms-auto expandable-search align-items-center position-relative d-flex',
            { expanded: expanded }
        ]">
        
        <!-- Search input -->
        <input name="search" type="text" ref="searchInput" class="form-control rounded-pill ps-4-5" autocomplete="off"
            autocorrect="off" :placeholder="_i18n('search')">

        <!-- Loading spinner shown during async search -->
        <Spinner :show="loading" size="1rem" class="spinner-inside">
        </Spinner>

        <!-- Search icon button -->
        <button 
            class="btn btn-link search-btn"
            @click="expanded = true">
            
            <i class="fa-solid fa-magnifying-glass"></i>
        </button>
    </div>

    <!-- Autocomplete dropdown list -->
    <ul ref="searchList" class="autocomplete-dropdown dropdown-menu dropdown-menu-right d-none" role="listbox">
    </ul>
</template>

<script setup>
/* ======================================================
 * Imports
 * ====================================================== */
import { ref, onMounted } from "vue";
import { default as Spinner } from "../spinner.vue";
import { ntopng_utility, ntopng_url_manager } from "../../services/context/ntopng_globals_services";

/* ======================================================
 * Props
 * ====================================================== */
const props = defineProps({
    context: Object,
});


const expanded = ref(false);

/* ======================================================
 * Reactive state & constants
 * ====================================================== */

// REST endpoint used for searching hosts
const searchRestAPI = `${http_prefix}/lua/rest/v2/get/host/find.lua`;

// Debounce timer reference
const debouncerTimer = ref(null);

// DOM references
const searchInput = ref(null);
const searchList = ref(null);

// UI state
const loading = ref(false);

// Delay before triggering search (debounce)
const inputDelay = 200; /* milliseconds */

// Index of currently selected autocomplete item
const currentIndex = ref(-1);

// Currently selected item
const selectedItem = ref({});

// i18n shortcut
const _i18n = (t) => i18n(t);

// Cache of last search results
let lastSuggestions = [];

/* ======================================================
 * Utility functions
 * ====================================================== */

/**
 * Debounce helper to avoid firing search on every keystroke
 */
const debounce = function (callback) {
    clearTimeout(debouncerTimer.value);
    debouncerTimer.value = setTimeout(callback, inputDelay);
};

/**
 * Select an autocomplete item by index
 */
const selectItem = function (index) {
    const item = lastSuggestions[index];
    selectedItem.value = item;
    searchInput.value.value = item.name;
    makeFindHostBeforeSubmitCallback(item);
};

/**
 * Build destination URL and redirect based on selected item type/context
 */
const makeFindHostBeforeSubmitCallback = function (data) {
    let url = "";
    let url_params = {};

    // Historical search context
    if (data.context && data.context === "historical") {
        url = "/lua/pro/db_search.lua";

        if (data.type === "ip") url_params.ip = data.ip;
        else if (data.type === "mac") url_params.mac = data.mac;
        else if (data.type === "community_id") url_params.community_id = data.community_id;
        else if (data.type === "ja3_client") url_params.ja3_client = data.ja3_client;
        else if (data.type === "ja3_server") url_params.ja3_server = data.ja3_server;
        else url_params.name = data.hostname ? data.hostname : data.name;

        // Live context
    } else {
        if (data.type === "mac") {
            url = "/lua/mac_details.lua";
            url_params.host = data.mac;
        } else if (data.type === "network") {
            url = "/lua/hosts_stats.lua";
            url_params.network = data.network;
        } else if (data.type === "snmp_device") {
            url = "/lua/pro/enterprise/snmp_device_details.lua";
            url_params.host = data.snmp_device;
        } else if (data.type === "snmp") {
            url = "/lua/pro/enterprise/snmp_interface_details.lua";
            url_params.host = data.snmp;
            url_params.snmp_port_idx = data.snmp_port_idx;
        } else if (data.type === "asn") {
            url = "/lua/hosts_stats.lua";
            url_params.asn = data.asn;
        } else {
            url = "/lua/host_details.lua";
            url_params.host = data.ip;
            url_params.mode = "restore";
        }
    }

    // Optional interface id
    if (data.ifid) {
        url_params.ifid = data.ifid;
    }

    url_params = ntopng_url_manager.obj_to_url_params(url_params);
    ntopng_url_manager.go_to_url(`${http_prefix}${url}?${url_params}`);
};

/* ======================================================
 * Rendering helpers
 * ====================================================== */

/**
 * Render badges HTML for a search item
 */
const printBadges = (badges) => {
    if (!badges) return "";

    const badgesButtons = [];
    badges.forEach((bg) => {
        const title = bg.title
            ? `data-bs-toggle="tooltip" data-bs-placement="top" title="${bg.title}"`
            : "";

        const icon = bg.icon
            ? `<i class="fa fas fa-${bg.icon}"></i>`
            : "";

        const label = bg.label
            ? `<span ${title} class="badge bg-secondary">${icon}${bg.label}</span>`
            : `<span ${title} class="badge bg-secondary">${icon}</span>`;

        badgesButtons.push(`${label} `);
    });

    return badgesButtons.join("");
};

/**
 * Render link buttons HTML (left/right icons)
 */
const printLinksButtons = (links) => {
    if (!links) return "";

    const linksButtons = [];
    links.forEach((l) => {
        const icon = l.icon ? `fa fas fa-${l.icon}` : "fa fas fa-link";
        const title = l.title
            ? `data-bs-toggle="tooltip" data-bs-placement="top" title="${l.title}"`
            : "";

        if (!l.url) {
            linksButtons.push(`<span class="me-1" ${title}><i class="text-muted ${icon}"></i></span>`);
        } else {
            linksButtons.push(
                `<button ${title} type="button" class="btn btn-sm btn-link"
                 onClick="ntopng_url_manager.go_to_url('${l.url}')">
                 <i class="${icon}"></i>
                 </button>`
            );
        }
    });

    return linksButtons.join("");
};

/**
 * Build a single autocomplete dropdown item
 */
const formatSearchItem = function (item, index) {
    const linksRight = item?.links?.filter(l => l.url);
    const linksLeft = item?.links?.filter(l => !l.url);

    const container = document.createElement("div");
    container.className = "d-flex";

    // LEFT: label + badges (takes remaining space)
    const left = document.createElement("div");
    left.className = "d-flex align-items-center flex-grow-1";
    left.onclick = () => selectItem(index);

    const leftBtns = document.createElement("div");
    leftBtns.className = "btn-group float-begin";
    leftBtns.style.width = "1.5rem";
    leftBtns.innerHTML = printLinksButtons(linksLeft);

    const label = document.createElement("label");
    label.innerHTML = `<a href="#" class="p-1 dropdown-item">${item.name}</a>`;

    const badges = document.createElement("span");
    badges.innerHTML = printBadges(item.badges);

    left.append(leftBtns, label, badges);

    // RIGHT: action buttons (fixed width)
    const right = document.createElement("div");
    right.className = "btn-group flex-shrink-0";
    right.innerHTML = printLinksButtons(linksRight);

    container.append(left, right);
    return container;
};

/* ======================================================
 * Search & keyboard navigation
 * ====================================================== */

/**
 * Update active element when navigating with keyboard
 */
const updateActive = function (list) {
    list.forEach(li => li.classList.remove("active"));
    if (currentIndex.value >= 0) {
        list[currentIndex.value].classList.add("active");
    }
};

/**
 * Perform async search and render dropdown
 */
const search = async function () {
    currentIndex.value = -1;
    lastSuggestions = [];
    loading.value = true;

    searchList.value.classList.add("d-none");
    searchList.value.innerHTML = "";

    const query = searchInput.value.value.toLowerCase();
    if (!query) {
        loading.value = false;
        return;
    }

    const url_params = ntopng_url_manager.obj_to_url_params({
        ifid: props.context.ifid,
        query
    });

    const suggestions = await ntopng_utility.http_request(
        `${searchRestAPI}?${url_params}`
    );

    suggestions?.results?.forEach((item, index) => {
        const li = document.createElement("li");
        li.className = "dropdown-item";
        li.append(formatSearchItem(item, index));
        searchList.value.appendChild(li);
        lastSuggestions.push(item);
    });

    loading.value = false;
    searchList.value.classList.toggle(
        "d-none",
        !suggestions?.results?.length
    );
};

/**
 * Keyboard navigation handler
 */
const handleKeys = function (e) {
    const options = searchList.value.querySelectorAll("li");

    if (e.key === "ArrowDown") {
        e.preventDefault();
        if (currentIndex.value < options.length - 1) currentIndex.value++;
        updateActive(options);
    }

    if (e.key === "ArrowUp") {
        e.preventDefault();
        if (currentIndex.value > 0) currentIndex.value--;
        updateActive(options);
    }

    if (e.key === "Enter" && currentIndex.value >= 0) {
        selectItem(currentIndex.value);
    }

    if (e.key === "Escape") {
        searchList.value.classList.add("d-none");
        expanded.value = false;
    }
};

/* ======================================================
 * Lifecycle
 * ====================================================== */

/**
 * Setup input listeners after component mount
 */
onMounted(() => {
    searchInput.value.addEventListener("input", () => debounce(search));
    searchInput.value.addEventListener("keydown", handleKeys);
    searchInput.value.addEventListener(
        "blur",
            () => setTimeout(() => {
                searchList.value.classList.add("d-none");
                expanded.value = false;
            }, 200)
    );
});
</script>
<style>
.ps-4-5 {
    padding-left: 2rem !important;
}

.spinner-inside {
    position: absolute;
    pointer-events: none;
    z-index: 10;
    left: 0.75rem;
}

.autocomplete-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    display: inline-block;
    width: auto;
    min-width: 100%;
    white-space: nowrap;
    z-index: 10;
    max-height: 60vh;
    scrollbar-gutter: stable;
    overflow-y: auto;
}

.expandable-search {
    width: 40px;
    /* collapsed */
    transition: width 0.3s ease;
    overflow: hidden;
}

.expandable-search input {
    width: 100%;
    outline: none;
    opacity: 0;
    transition: opacity 0.2s ease;
    padding-left: 2.5rem;
    padding-right: 3rem;
}

.expandable-search .search-btn {
    position: absolute;
    right: 8px;
    color: var(--icon-color);
    z-index: 2;
}

.expandable-search.expanded {
    width: 250px;
    /* expanded */
}

.expandable-search.expanded input {
    outline: none;
    box-shadow: none;
    opacity: 1;
}
</style>