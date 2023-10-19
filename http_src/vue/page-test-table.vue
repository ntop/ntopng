<template>
  <div id="aggregated_live_flows">          
    <Datatable ref="table_test"
	       :table_buttons="table_config.table_buttons"
	       :columns_config="table_config.columns_config"
	       :data_url="table_config.data_url"
	       :filter_buttons="table_config.table_filters"
	       :enable_search="table_config.enable_search"
	       :table_config="table_config.table_config">
    </Datatable>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import NtopUtils from "../utilities/ntop-utils";
import { default as Datatable } from "./datatable.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    url: String,
    ifid: Number,
    columns_config: Array
});

const table_config = ref({})
const table_test = ref(null);

onBeforeMount(() => {
    set_datatable_config();
});

function set_datatable_config() {
    const datatableButton = [];
    
    let params = { 
	ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,	
    };
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    
    datatableButton.push({
	text: '<i class="fas fa-sync"></i>',
	className: 'btn-link',
	action: function (e, dt, node, config) {
            table_test.value.reload();
	}
    });
    
    let defaultDatatableConfig = {
	table_buttons: datatableButton,
	data_url: `${props.url}?${url_params}`,
	enable_search: true,
    };
    
    let columns = [];
    
    defaultDatatableConfig.columns_config = props.columns_config;
    table_config.value = defaultDatatableConfig;
}
    
</script>
