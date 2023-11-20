<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card  card-shadow">
        <h3 class="d-inline-block pt-3 ps-3" v-html="title_html"></h3>
        <Loading v-if="loading"></Loading>
        <div class="card-body" :class="[loading ? 'ntopng-gray-out' : '']" v-html="message_html"></div>
      </div>
    </div>
  </div>
  
</template>

<script setup>
import { ref, onBeforeMount } from "vue";
import { default as Loading } from "./loading.vue";
import regexValidation from "../utilities/regex-validation.js";

const scan_result_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_result.lua`;

const modal_id = ref(null);
const loading = ref(false);


const props = defineProps({
  context: Object,
}); 
const message = ref('');
const message_html = ref('');
const title_html = ref('');

const title = ref('');
const my_array = ref([]);


async function get_result(host, scan_type, date, epoch) {
  
  loading.value = true;
  let params = {
    host: host,
    scan_type: scan_type,
    scan_return_result: true,
    epoch: epoch

  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);
  let url = `${scan_result_url}?${url_params}`;
  let result = await ntopng_utility.http_request(url);
  message.value = result.rsp;
  message_html.value = `<pre>${message.value}</pre>`;


  const host_href = props.context.is_in_mem === 'true' || props.context.is_in_mem == true ? `${host} <a href="${http_prefix}/lua/host_details.lua?host=${host}"><i class = "fas fa-laptop"></i></a>`: host;
  
  
  title.value = i18n("hosts_stats.page_scan_hosts.vs_result").replace("%{host}", host_href);
  if (date != null)
    date = date.replaceAll("_"," ");

  
  title.value = title.value.replace("%{date}",date);
  title_html.value = title.value;

  loading.value = false;
}



/* ******************************************************************** */ 

onBeforeMount(async () => {
  await get_result(props.context.host, props.context.scan_type, props.context.date, props.context.epoch);
})


</script>

<style scoped>
</style>
