<!-- (C) 2022 - ntop.org     -->
<template>
<div>  
<table ref="table_id" class="table w-100 table-striped table-hover table-bordered mt-3">
  <thead>
    <tr>
      <th v-for="item in columns_config">{{ item.columnName }}</th>
    </tr>
  </thead>
  <tbody></tbody>
</table>
</div>
</template>

<script setup>
import { ref, onMounted, getCurrentInstance, computed, watch, onBeforeUnmount } from "vue";
import { default as modal } from "./modal.vue";

const props = defineProps({
    table_buttons: Array,
    columns_config: Array,
    data_url: String,
    enable_search: Boolean,
});

const table_id = ref(null);
// let _this = getCurrentInstance().ctx;

let table = null;
onMounted(() => {
    /* Create a datatable with the buttons */
    let config = DataTableUtils.getStdDatatableConfig(props.table_buttons);
    config = DataTableUtils.extendConfig(config, {
        serverSide: false,
        searching: props.enable_search,
	order: [[0, "asc"]],
        pagingType: 'full_numbers',
	columnDefs: {},
	ajax: {
	    method: 'get',
	    url: props.data_url,
	    dataSrc: 'rsp',
            beforeSend: function() {
                NtopUtils.showOverlays();
            },
            complete: function() {
              NtopUtils.hideOverlays();
            }
        },
        columns: props.columns_config,
    });
    table = $(table_id.value).DataTable(config);
});

const reload = () => {
    if (table == null) { return; }
    table.ajax.url(props.data_url).load();
}

const delete_button_handlers = (handlerId) => {
    DataTableUtils.deleteButtonHandlers(handlerId);
};

defineExpose({ reload, delete_button_handlers });


onBeforeUnmount(() => {
    table.destroy(true);
});

</script>

<style scoped>
</style>
