<template>
  <div class="mb-4">{{ title }}</div>
    <div class="row">
      <div class="col-md-12 col-lg-12">
        <div class="card  card-shadow">
                <!-- <Loading ref="loading"></Loading> -->
          <div class="card-body" v-html="message_html">
        </div>
      </div>
    </div>
  </div>
  
</template>

<script setup>
import { ref, onBeforeMount } from "vue";
const scan_result_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_result.lua`;

const modal_id = ref(null);


const props = defineProps({
  context: Object,
}); 
const message = ref('');
const message_html = ref('');

const title = ref('');
const my_array = ref([]);


async function get_result(host, scan_type, date) {
  

  let params = {
    host: host,
    scan_type: scan_type,
    scan_return_result: true

  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${scan_result_url}?${url_params}`;
  let result = await ntopng_utility.http_request(url);
  message.value = result.rsp;
  message_html.value = `<pre>${message.value}</pre>`;
  title.value = i18n("hosts_stats.page_scan_hosts.vs_result").replace("%{host}", host);
  title.value = title.value.replace("%{date}",date);

}



/* ******************************************************************** */ 

onBeforeMount(async () => {
  await get_result(props.context.host, props.context.scan_type, props.context.date);
})


</script>

<style scoped>
</style>
