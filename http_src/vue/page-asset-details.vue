<!--
  (C) 2013-26 - ntop.org
-->

<template>
    <div class="row">
        <div class="col-md-12 col-lg-12">
            <div class="mt-4 card card-shadow">
                <div class="card-body">
                    <BootstrapTable :horizontal="true" :id="table_id" :rows="stats_rows"
                        :print_html_title="print_html_title" :print_html_row="print_stats_row">
                    </BootstrapTable>
                </div>
            </div>
        </div>

        <!-- Wazuh -->
        <div v-if="wazuh_info_rows.length > 0" class="col-md-12 col-lg-12">
            <div class="mt-4 card card-shadow">

                <div class="card-header d-flex align-items-center gap-2 fw-semibold">
                    <span>{{ _i18n('asset_details.wazuh_asset_information') }}</span>
                </div>

                <!-- Key-value rows (status, OS, CPU, RAM …) -->
                <div class="card-body pb-0">
                    <BootstrapTable
                        :horizontal="true" :id="wazuh_table_id" :rows="wazuh_info_rows"
                        :print_html_title="print_html_title" :print_html_row="print_stats_row">
                    </BootstrapTable>
                </div>

                <!-- Network Interfaces sub-section -->
                <template v-if="wazuh_ifaces_rows.length > 0">

                    <!-- Section label -->
                    <div class="card-body pt-2 pb-1">
                        <div class="d-flex align-items-center gap-2 text-muted small fw-semibold text-uppercase mb-0">
                            <i class="fas fa-network-wired"></i>
                            <span>{{ _i18n('asset_details.wazuh_network_interfaces') }}</span>
                            <hr class="flex-grow-1 my-0 ms-1">
                        </div>
                    </div>

                    <!-- Interfaces table -->
                    <div class="card-body pt-0 pb-0">
                        <TableWithConfig table_config_id="wazuh_network_ifaces" :rows_data="wazuh_ifaces_rows" 
                            :f_map_columns="map_ifaces_columns" :f_sort_rows="sort_ifaces_rows" :csrf="csrf">
                        </TableWithConfig>
                    </div>

                </template>

            </div>
        </div>

    </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import formatterUtils from "../utilities/formatter-utils";

const _i18n = (t) => i18n(t);

const url = "/lua/pro/rest/v2/get/host/asset_details.lua";
const table_id = ref('asset_details');
const wazuh_table_id  = ref('wazuh_info');
const props = defineProps({
    ifid: Number,
    csrf: String
});

const stats_rows = ref([]);
const wazuh_info_rows = ref([]);

const print_html_title = function (name) {
    return (name || "");
}

const print_stats_row = function (value) {
    let label = value.name || '';
    if (value.url && value.url != '')
        label = `<a href="${http_prefix}${value.url}">${label}</>`;
    return label;
};

// Network Interfaces
const wazuh_ifaces_rows = ref([]);

const map_ifaces_columns = (columns) => {
    let map_columns = 
    {
        "name": (value, row) => {
            return value
        },
        "mac": (value, row) => {
            return value
        },
        "state": (value, row) => {
            return value
        },
        "sent": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value)
        },
        "rcvd": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value)
        }
    }
    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });
    return columns;
};

const sort_ifaces_rows = (col, r0, r1) => {
    if (col != null) {
        if (col.id === 'name') 
            return sortingFunctions.sortByName(r0.name,  r1.name,  col.sort);
        if (col.id === 'mac')
            return sortingFunctions.sortByMacAddress(r0.mac, r1.mac, col.sort);
        if (col.id === 'state')
            return sortingFunctions.sortByName(r0.state, r1.state, col.sort);
        if (col.id === 'sent')
            return sortingFunctions.sortByNumber(r0.sent, r1.sent, col.sort);
        if (col.id === 'rcvd')
            return sortingFunctions.sortByNumber(r0.rcvd, r1.rcvd, col.sort);
    }
    return 0;
};

onMounted(async () => {
    const extra_params = ntopng_url_manager.get_url_object();
    const url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const host_stats = await ntopng_utility.http_request(`${http_prefix}${url}?${url_params}`);
    stats_rows.value = host_stats.host_info || [];
    wazuh_info_rows.value = host_stats.wazuh_info_rows || [];
    wazuh_ifaces_rows.value = host_stats.wazuh_network_ifaces || [];
    $('#navbar_title').html("<i class='fas fa-laptop'></i> " + _i18n('asset_details.assets') + ": " + host_stats.host_name);
});

</script>
