<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card card-shadow">
      <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
        <div class="text-center">
          <div class="spinner-border text-primary mt-5" role="status">
            <span class="sr-only position-absolute">Loading...</span>
          </div>
        </div>
      </div>
      <div class="card-body">
        <div class="d-flex align-items-center mb-2">
          <div class="d-flex no-wrap">
            <div>
              <selectSearch
                v-model:selected_option="active_hosts_type"
                :options="sankey_format_list"
                @select_option="update_sankey_url">
              </selectSearch>
            </div>
          </div>
        </div>
            
        <Sankey ref="flow_sankey"
          :id="id"
          :page_csrf="props.page_csrf"
          :url="props.url"
          :url_params="props.url_params"
          :extra_settings="extra_settings">
        </Sankey>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as selectSearch } from "./select-search.vue"
import { default as Sankey } from "./sankey.vue";
import sankeyUtils from "../utilities/map/sankey_utils"

const props = defineProps({
  page_csrf: String,
  url: String,
  url_params: Object,
})

const flow_sankey = ref(null);
const extra_settings = {}

const id = "flow-sankey"
const _i18n = (t) => i18n(t);

const sankey_format_list = [
  { filter_name: 'hosts_type', key: 1, id: 'local_only', title: _i18n('flows_page.local_only'), label: _i18n('flows_page.local_only'), currently_active: true, filter_icon: false, countable: false },
//  { filter_name: 'hosts_type', key: 2, id: 'remote_only', title: _i18n('flows_page.remote_only'), label: _i18n('flows_page.remote_only'), currently_active: false, filter_icon: false, countable: false },
  { filter_name: 'hosts_type', key: 2, id: 'local_origin_remote_target', title: _i18n('flows_page.local_cli_remote_srv'), label: _i18n('flows_page.local_cli_remote_srv'), currently_active: false, filter_icon: false, countable: false },
  { filter_name: 'hosts_type', key: 3, id: 'remote_origin_local_target', title: _i18n('flows_page.local_srv_remote_cli'), label: _i18n('flows_page.local_srv_remote_cli'), currently_active: false, filter_icon: false, countable: false },
  { filter_name: 'hosts_type', key: 4, id: 'all_hosts', title: _i18n('flows_page.all_flows'), label: _i18n('flows_page.all_flows'), currently_active: false, filter_icon: false, countable: false },
];
let active_hosts_type = sankey_format_list[0]

const update_data = function() {
  flow_sankey.value.updateData(); 
};

const update_active_hosts_type = function(entry) {
  if(entry) {
    active_hosts_type = entry
  } else {
    sankey_format_list.forEach((value) => {
      if(value.currently_active == true) {
        active_hosts_type = value
      }
    })
  }
}

const update_sankey_url = function(entry) {
  ntopng_url_manager.set_key_to_url(entry.filter_name, entry.id) 
  update_active_hosts_type(entry)
  update_data()
}

onBeforeMount(() => {})

onMounted(() => { 
  extra_settings.linkTitle = sankeyUtils.formatFlowTitle
  update_sankey_url(active_hosts_type)
})

</script>






