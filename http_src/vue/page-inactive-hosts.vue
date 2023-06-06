<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <h2 class="ms-3">{{ title }}</h2>
      <div class="card  card-shadow">
        <div class="card-body">
          <div id="inactive_hosts">
            <TableWithConfig ref="table_inactive_hosts" :table_id="table_id" :csrf="csrf"
              :get_extra_params_obj="get_extra_params_obj">
            </TableWithConfig>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";

const _i18n = (t) => i18n(t);

const table_id = ref('inactive_hosts');
const props = defineProps({
  ifid: Number,
  csrf: String,
});
const title = ref(_i18n('local_hosts_only'))

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

</script>
