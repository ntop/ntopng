<!-- (C) 2022 - ntop.org     -->
<template>
  <Table ref="table"
	 :id="table_config.id"
         :key="table_config.id"
	 :columns="table_config.columns"
         :get_rows="table_config.get_rows"
         :get_column_id="table_config.get_column_id"
         :print_column_name="table_config.print_column_name"
	 :print_html_row="table_config.print_html_row"
	 :print_vue_node_row="table_config.print_vue_node_row"
	 :f_is_column_sortable="table_config.f_is_column_sortable"
	 :f_get_column_classes="table_config.f_get_column_classes"
	 :f_get_column_style="table_config.f_get_column_style"
	 :enable_search="table_config.enable_search"
	 :paging="table_config.paging"
	 :csrf="csrf"
	 @loaded="on_loaded"
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

const emit = defineEmits(['custom_event', 'loaded'])
const props = defineProps({
    table_id: String,
    csrf: String,
    f_map_columns: Function,
    get_extra_params_obj: Function,
});

const table_config = ref({});
const table = ref(null);

onMounted(async () => {
    if (props.table_id != null) {
	load_table();
    }
});

watch(() => props.table_id, (cur_value, old_value) => {
    load_table();
}, { flush: 'pre'});


async function load_table() {
    table_config.value = await TableUtils.build_table(http_prefix, props.table_id, props.f_map_columns, props.get_extra_params_obj);
}

function on_loaded() {
    emit('loaded');
}

function on_custom_event(event) {
    emit('custom_event', event);
}

const refresh_table = () => {
    table.value.refresh_table();
}

defineExpose({ refresh_table });

</script>

<style scoped>
</style>
