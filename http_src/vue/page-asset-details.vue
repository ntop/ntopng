<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="mt-4 card card-shadow">
        <div class="card-body">
          <BootstrapTable :horizontal="true" :id="table_id" :rows="stats_rows" :print_html_title="print_html_title"
            :print_html_row="print_stats_row">
          </BootstrapTable>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";

const _i18n = (t) => i18n(t);

const url = "/lua/rest/v2/get/host/asset_details.lua";
const table_id = ref('asset_details');
const props = defineProps({
  ifid: Number,
  csrf: String,
});

const stats_rows = ref([]);

const print_html_title = function (name) {
  return (name || "");
}

const print_stats_row = function (value) {
  let label = value.name || '';
  if (value.url && value.url != '')
    label = `<a href="${http_prefix}${value.url}">${label}</>`

  return label;
}

onMounted(async () => {
  const extra_params = ntopng_url_manager.get_url_object();
  const url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const host_stats = await ntopng_utility.http_request(`${http_prefix}${url}?${url_params}`);
  stats_rows.value = host_stats.host_info
  $('#navbar_title').html("<i class='fas fa-laptop'></i> " + _i18n('host_details.host') + ": " + host_stats.host_name);
});

</script>
