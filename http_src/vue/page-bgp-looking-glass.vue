<!-- (C) 2026 - ntop.org -->
<template>
    <div class="row px-3 align-items-center justify-content-center">
        <div class="d-flex col-auto align-items-center mt-3 gap-1 mb-2">
            <div>
                <div class="d-flex align-items-center">
                    <div class="input-group">
                        <input ref="searchInput" name="search" type="text" class="form-control" autocomplete="off"
                            autocorrect="off" :placeholder="_i18n('details.label_bgp_search_ip')"
                            @keydown.enter="searchPrefix" />
                        <button class="btn btn-primary" type="button" @click="searchPrefix">
                            <i class="fas fa-search"></i>
                        </button>
                    </div>
                    <div class="ms-2" style="min-width: 24px;">
                        <Spinner :show="loading" size="1rem" class="me-1"></Spinner>
                    </div>
                </div>
                <div class="mt-1" :class="{ 'text-danger' : isError }" style="min-height: 24px;">
                    <small>{{ validationError }}</small>
                </div>
            </div>
            <!-- Prefix -->
            <div class="col-auto" v-if="prefix">
                <span class="d-inline-flex align-items-center 
                        gap-2 px-3 py-2 rounded-3 border border-primary-subtle 
                        fw-semibold font-monospace fs-6 prefix-color" data-bs-toggle="tooltip" data-bs-placement="top"
                    :title="_i18n('flow_details.bgp_prefix')">
                    <i class="fa-solid fa-network-wired"></i>
                    {{ prefix }}
                </span>
            </div>
            <!-- Prefix -->
            <div class="col-auto" v-if="rpki">
                <a class="badge" :class="rpki === 'Valid' ? 'bg-success' : 'bg-danger'"
                    :href="`https://rpki-validator.ripe.net/ui/?prefix=${prefix}&asns=${asn}`" target="_blank"
                    data-bs-toggle="tooltip" data-bs-placement="top"
                    :title="_i18n('flow_details.   bgp_jump_to_routinator')">
                    {{ _i18n('flow_details.bgp_rpki') }}: {{ rpki }}
                    <i class="fas fa-external-link-alt text-white"></i>
                </a>
            </div>
        </div>

        <div class="col-12">
            <div class="position-relative">
                <TableWithConfig ref="table_ref" :table_id="table_id" :get_extra_params_obj="get_extra_params_obj"
                    :show-loading="true" :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
                    @rows_loaded="rowsLoaded">
                </TableWithConfig>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, watch, nextTick } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as Spinner } from "./spinner.vue";
import regexValidation from "../utilities/regex-validation.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const searchInput = ref(null);
const table_ref = ref(null);
const table_id = ref('bgp_looking_glass');
const rpki_ripe_url = 'https://rpki-validator.ripe.net/api/v1/validity/AS'
const prefix = ref('')
const rpki = ref('')
const asn = ref(0)
const active_host = ref(ntopng_url_manager.get_url_entry('host') || '');
const loading = ref(false);
const isError = ref(false);
const validationError = ref(null);
const isFirstLoading = ref(true);
const note_list = [
    _i18n("flow_details.bgp_looking_glass_descr")
]

watch(() => asn.value, (cur_value, old_value) => {
    updateRPKI();
}, { flush: 'pre' });

/* ***************************************************** */

const updateRPKI = async () => {
    if (!dataUtils.isZeroOrEmptyString(asn.value) && !dataUtils.isEmptyString(prefix.value)) {
        const rsp = await ntopng_utility.http_request(`${rpki_ripe_url}${asn.value}/${prefix.value}`, null, null, true);
        if (rsp?.validated_route?.validity?.state) {
            rpki.value = rsp.validated_route.validity.state
            rpki.value = rpki.value[0].toUpperCase() + rpki.value.slice(1); // Capitalize the first letter
        }
    }
    await nextTick();
    disableLoading();
}

/* ***************************************************** */

const get_extra_params_obj = () => {
    return ntopng_url_manager.get_url_object();
};

/* ***************************************************** */

const searchPrefix = () => {
    enableLoading()
    const host = searchInput.value?.value?.trim();
    active_host.value = host || '';
    ntopng_url_manager.set_key_to_url('host', active_host.value);
    if (!dataUtils.isEmptyString(host)) {
        if (!regexValidation.validateIP(host) && !regexValidation.validateCIDR(host)) {
            isError.value = true;
            validationError.value = _i18n('flow_details.bgp_validation_err');
            disableLoading();
            return;
        }
    }
    validationError.value = null;
    refreshTable();
};

/* ***************************************************** */

const clearSearch = () => {
    active_host.value = '';
    if (searchInput.value) searchInput.value.value = '';
    ntopng_url_manager.set_key_to_url('host', '');
    refreshTable()
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

/* ************************************** */

const formatNameValue = function (value) {
    let info = (value.name) ? (value.name) : (value.value)
    if (value.url) {
        info = `<a href='${value.url}'>${info}</a>`
    }
    return `${info}`
}

/* ************************************** */

const formatMultipleValues = function (value) {
    let formatted_info = ""
    const add_ul = value.length > 1
    value?.forEach((el) => {
        let info = (el.name) ? (el.name) : (el.value)
        if (el.url) {
            info = `<a href='${el.url}'>${info}</a>`
        }
        formatted_info = `${formatted_info}<li>${info}`
    })
    formatted_info = `<ul class="m-0">${formatted_info}</ul>`
    return formatted_info
}

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "bgp_peer_id": (value, row) => {
            // Small trick to handle the prefix
            prefix.value = row.bgp_prefix
            if (asn.value === row.asn) loading.value = false;
            asn.value = row.asn
            const formattedPeer = formatNameValue(value)
            return `${formattedPeer}${value.is_best_path ?
                `<span class="badge bg-success ms-1" data-bs-toggle="tooltip" data-bs-placement="top" 
                    title="${_i18n('flow_details.bgp_best_path')}">${_i18n('flow_details.bgp_best')} <i class="fa-solid fa-trophy"></i></span>` : ''}`;
        },
        "bgp_peer_asn": (value, row) => {
            return formatNameValue(value);
        },
        "bgp_origin": (value, row) => {
            return formatNameValue(value);
        },
        "bgp_as_path": (value, row) => {
            return formatMultipleValues(value)
        },
        "bgp_next_hop": (value, row) => {
            return formatNameValue(value);
        },
        "bgp_local_pref": (value, row) => {
            if (dataUtils.isZeroOrEmptyString(value.name)) {
                return '100'
            }
            return value.name
        },
        "bgp_med": (value, row) => {
            if (dataUtils.isZeroOrEmptyString(value.name)) {
                return ''
            }
            return value.name
        },
        "bgp_communities": (value) => {
            return formatMultipleValues(value)
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

        if (col.id == "bgp_peer_id" || col.id == "bgp_next_hop") {
            return sortingFunctions.sortByIP(r0_col.value, r1_col.value, col ? col.sort : null);
        } else if (col.id == "bgp_local_pref") {
            return sortingFunctions.sortByNumber(r0_col.name, r1_col.name, col.sort);
        } else if (col.id == "bgp_med") {
            return sortingFunctions.sortByNumber(r0_col.name, r1_col.name, col.sort);
        } else if (col.id == "bgp_peer_asn") {
            return sortingFunctions.sortByNumber(r0_col.value, r1_col.value, col.sort);
        } else if (col.id == "bgp_as_path" || col.id == "bgp_communities") {
            return sortingFunctions.sortByArrayLength(r0_col, r1_col, col.sort);
        }
    }
}

function rowsLoaded(res) {
    disableLoading();
    if (!isFirstLoading.value) {
        const host = searchInput.value?.value?.trim();
        if (res?.rows?.length === 0) {
            validationError.value = _i18n("flow_details.bgp_no_data") + host;
        }
    }
    isFirstLoading.value = false
    isError.value = false;
}

/* ************************************** */

function disableLoading() {
    loading.value = false
}

/* ************************************** */

function enableLoading() {
    loading.value = true
}

/* ************************************** */

function refreshTable() {
    table_ref.value?.refresh_table();
}

/* ************************************** */

onMounted(() => {
    if (!dataUtils.isEmptyString(active_host.value)) {
        searchInput.value.value = active_host.value
    }
})

</script>

<style scoped>
.prefix-color {
    border-color: var(--bs-border-color) !important;
    background-color: var(--bs-tertiary-bg);
    color: var(--bs-secondary-color);
}
</style>
