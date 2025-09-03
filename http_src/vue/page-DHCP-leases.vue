<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_dhcp_leases" :table_id="table_id" :csrf="csrf"
            :f_map_columns="map_table_def_columns" 
        :f_sort_rows="columns_sorting">
        </TableWithConfig>
    </div>
</template>


<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const table_id = ref('dhcp_leases');
const table_dhcp_leases = ref(null);
const csrf = props.context.csrf;
const ifid = props.context.ifid;

const map_table_def_columns = (columns) => {

    let map_columns = {
        "macAddress": (value, row) => {
            const mac_details_url = `${http_prefix}/lua/mac_details.lua?host=${value}&ifid=${ifid}`

            return `<a href=${mac_details_url}>${value}</a>`
        },
        "leasedIP": (value, row) => {
            const host_info_url = `${http_prefix}/lua/host_details.lua?host=${value}&mac=${row.macAddress}&ifid=${ifid}`
            return `<a href=${host_info_url}>${value}</a>`
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};

</script>
