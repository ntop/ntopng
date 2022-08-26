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
  filter_buttons: {
    type: Array,
    required: false,
  },
  table_config: {
    type: Object,
    required: false,
  }
});

const table_id = ref(null);
// let _this = getCurrentInstance().ctx;

let table = null;
onMounted(() => {
  /* Create a datatable with the buttons */
  let extend_config = {
    serverSide: false,
    destroy: true,
    searching: props.enable_search,
    order: [[0, "asc"]],
    pagingType: 'full_numbers',
    columnDefs: {},
    ajax: {
      method: 'get',
      url: props.data_url,
      dataSrc: 'rsp',
      data: (data, settings) => {
        if(Object.keys(data).length == 0) {
          return;
        }

        const tableApi = settings.oInstance.api();
        const orderColumnIndex = data.order[0].column;
        const orderColumnName = tableApi.column(orderColumnIndex).name() || undefined;
        
        if (data.order) {
          data.order = data.order[0].dir;
          data.sort = orderColumnName;
        }

        if (data.columns !== undefined) {
          delete data.columns;
        }

        if (data.search !== undefined) {
          data.map_search = data.search.value;
          delete data.search
        }
        
        return data;
      },
      beforeSend: function() {
        NtopUtils.showOverlays();
      },
      complete: function() {
        NtopUtils.hideOverlays();
      }
    },
    columns: props.columns_config,
  };

  for (const item in (props.table_config || {})) {
    extend_config[item] = props.table_config[item]
  }

  let config = DataTableUtils.getStdDatatableConfig(props.table_buttons);
  config = DataTableUtils.extendConfig(config, extend_config);
  table = $(table_id.value).DataTable(config);
  for (const filter of (props.filter_buttons || [])) {
    new DataTableFiltersMenu({
      filterTitle: filter.filterTitle,
      tableAPI: table,
      filters: filter.filters,
      filterMenuKey: filter.filterMenuKey,
      columnIndex: filter.columnIndex,
      url: props.data_url,
      id: filter.id,
      removeAllEntry: filter.removeAllEntry,
      callbackFunction: filter.callbackFunction
    }).init();
  }
});

//onUpdated(() => { console.log("Updated"); });

const reload = () => {
    if (table == null) { return; }
    table.ajax.reload();
}

const delete_button_handlers = (handlerId) => {
    DataTableUtils.deleteButtonHandlers(handlerId);
};

let is_destroyed = false;

const destroy_table = () => {
    table.clear();
    table.destroy(true);
    is_destroyed = true;
}

defineExpose({ reload, delete_button_handlers, destroy_table });

onBeforeUnmount(() => {
    if (is_destroyed == true) { return; }
    table.destroy(true);
});

</script>

<style scoped>
</style>
