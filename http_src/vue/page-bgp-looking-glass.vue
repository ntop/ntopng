<!-- (C) 2026 - ntop.org -->
<template>
    <div class="container-fluid px-3">

        <div class="row align-items-center mt-3 mb-3 g-2">
            <div class="col-auto">
                <div class="input-group">
                    <input ref="searchInput" name="search" type="text" class="form-control"
                        style="min-width: 280px;"
                        autocomplete="off" autocorrect="off"
                        :placeholder="_i18n('details.label_bgp_search_ip')"
                        @keydown.enter="searchPrefix" />
                    <button class="btn btn-primary" type="button" @click="searchPrefix">
                        <i class="fas fa-search"></i>
                    </button>
                </div>
            </div>

            <!-- Prefix -->
            <div class="col-auto" v-if="active_host">
                <span class="badge bg-secondary fs-6 px-3 py-2">
                    <i class="fas fa-network-wired me-1"></i>
                    {{ active_host }}
                    <button type="button" class="btn-close btn-close-white ms-2"
                        style="font-size: 0.6rem; vertical-align: middle;"
                        @click="clearSearch" aria-label="Clear"></button>
                </span>
            </div>
        </div>

        <div class="row">
            <div class="col-12">
                <TableWithConfig ref="table_ref" :table_id="table_id"
                    :get_extra_params_obj="get_extra_params_obj" :f_map_columns="map_table_def_columns"
                    :f_sort_rows="columns_sorting">
                </TableWithConfig>
            </div>
        </div>

    </div>
</template>

<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const searchInput = ref(null);
const table_ref = ref(null);
const table_id = ref('bgp_looking_glass');
const active_host = ref(ntopng_url_manager.get_url_entry('host') || '');

/* ***************************************************** */

const get_extra_params_obj = () => {
    return ntopng_url_manager.get_url_object();
};

/* ***************************************************** */

const searchPrefix = () => {
    const host = searchInput.value?.value?.trim();
    active_host.value = host || '';
    ntopng_url_manager.set_key_to_url('host', active_host.value);
    table_ref.value?.refresh_table();
};

/* ***************************************************** */

const clearSearch = () => {
    active_host.value = '';
    if (searchInput.value) searchInput.value.value = '';
    ntopng_url_manager.set_key_to_url('host', '');
    table_ref.value?.refresh_table();
};

/* ************************************** */

const ASLink = (as_obj) => {
    if (!as_obj || !as_obj.raw) return '';
    
    const asn_val = as_obj.raw;
    const asn_name = as_obj.name || `AS ${asn_val}`;
    const url = `${http_prefix}/lua/hosts_stats.lua?asn=${asn_val}`;
    
    return `<a href="${url}" 
                class="text-decoration-none" 
                data-bs-toggle="tooltip" 
                data-bs-placement="top" 
                title="${asn_name}">${asn_val}</a>`;
};

const map_table_def_columns = (columns) => {
    let map_columns = {
        "bgp_peer_id": (value, row) => {
            return value;
        },
        "asn": (value, row) => {
            return value ? ASLink(value) : '';
        },
        "origin": (value, row) => {
            return value ? value.toUpperCase() : '';
        },
        "as_path": (value, row) => {
            if (!Array.isArray(value)) return '';
            return value.map(as_obj => ASLink(as_obj)).join(' ');
        },
        "next_hop": (value, row) => {
            return value;
        },
        "local_pref": (value, row) => {
            return value || 100;
        },
        "med": (value, row) => {
            return value || 0;
        },
        "communities": (value) => {
            if (!Array.isArray(value)) return value ?? '';
            return value.map(comm => {
                if (!comm.left || !comm.right) return comm.raw;
                return `${ASLink(comm.left)}:${ASLink(comm.right)}`;
            }).join(' ');
        },
    };
    
    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};


/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        const r0_col = r0[col.data.data_field];
        const r1_col = r1[col.data.data_field];

        if (col.id == "peer_ip" || col.id == "next_hop") {
            return sortingFunctions.sortByIP(r0_col, r1_col, col ? col.sort : null);
        } else if (col.id == "local_pref" || col.id == "med") {
            return sortingFunctions.sortByNumber(r0_col, r1_col, col.sort);
        } else if (col.id == "asn") {
            // extract asn value
            const val0 = r0_col && r0_col.raw ? parseInt(r0_col.raw) : 0;
            const val1 = r1_col && r1_col.raw ? parseInt(r1_col.raw) : 0;
            return sortingFunctions.sortByNumber(val0, val1, col.sort);
        } else if (col.id == "as_path" || col.id == "communities") {
            return sortingFunctions.sortByArrayLength(r0_col, r1_col, col.sort);
        } 
    }
}

</script>
