<!-- (C) 2022 - ntop.org     -->
<template>
  <Table v-if="mount_table" ref="table"
	 :id="table_id_2"
	 :columns="table_config.columns"
         :get_rows="table_config.get_rows"
         :get_column_id="table_config.get_column_id"
         :print_column_name="table_config.print_column_name"
	 :print_html_row="table_config.print_html_row"
	 :print_vue_node_row="table_config.print_vue_node_row"
	 :f_is_column_sortable="table_config.f_is_column_sortable"
	 :f_get_column_classes="table_config.f_get_column_classes"
	 :f_get_column_style="table_config.f_get_column_style"
	 :display_empty_rows="table_config.display_empty_rows"
	 :f_sort_rows="f_sort_rows"
	 :enable_search="table_config.enable_search"
	 :default_sort="table_config.default_sort"
	 :show_autorefresh="table_config.show_autorefresh"
	 :paging="table_config.paging"
	 :csrf="csrf"
     :display_message="display_message"
     :message_to_display="message_to_display"
	 @loaded="on_loaded"
     @rows_loaded="rows_loaded"
	 @custom_event="on_custom_event">
    <template v-slot:custom_header>
      <slot name="custom_header"></slot>
    </template>
  </Table>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount, nextTick } from "vue";
import { default as Table } from "./table.vue";
import TableUtils from "../utilities/table-utils";

const emit = defineEmits(['custom_event', 'loaded', 'rows_loaded'])
const props = defineProps({
    table_config_id: String, // name of configuration file in httpdocs/tables_config
    table_id: String, // id of table, same table_config_id can have different table_id and then different columuns visible settins
    csrf: String,
    f_map_config: Function,
    f_map_columns: Function,
    f_sort_rows: Function,
    get_extra_params_obj: Function,
    display_message: Boolean,
    message_to_display: String,
});

const table_config = ref({});
const table = ref(null);
const mount_table = ref(false);

onMounted(async () => {
    if (props.table_id != null || props.table_config_id != null) {
	load_table();
    }
});

watch(() => [props.table_id, props.table_config_id], (cur_value, old_value) => {
    load_table();
}, { flush: 'pre'});

const table_id_2 = computed(() => {
    if (props.table_id != null) { return props.table_id; }
    return props.table_config_id;
});

async function load_table() {
    mount_table.value = false;
    await nextTick();
    let table_config_id_2 = props.table_config_id;
    if (table_config_id_2 == null) {
	table_config_id_2 = props.table_id;
    }
    table_config.value = await TableUtils.build_table(http_prefix, table_config_id_2, props.f_map_columns, props.get_extra_params_obj);
    if (props.f_map_config != null) {
	table_config.value = props.f_map_config(table_config.value);
    }
    mount_table.value = true;
    await nextTick();
}

function on_loaded() {
    emit('loaded');
}

function on_custom_event(event) {
    emit('custom_event', event);
}

function rows_loaded(res) {
    emit('rows_loaded', res);
}

const refresh_table = (disable_loading) => {
    if(table.value) {
        table.value.refresh_table(disable_loading);
    }
}

const get_columns_defs = () => {
    if (table.value == null) { return []; }
    return table.value.get_columns_defs();
}

const get_rows_num = () => {
    return table.value.get_rows_num();
}

const search_value = (value) => {
    table.value.search_value(value);
}

defineExpose({ refresh_table, get_columns_defs, get_rows_num, search_value });

</script>

<style scoped>
</style>
