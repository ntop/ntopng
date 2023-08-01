<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    <pre><textarea style="width:100%" rows="15" class="mt-3" readonly>{{body}} </textarea></pre>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);

const showed = () => {};

const props = defineProps({
    body: String,
    title: String,
});
const body = ref('');
const title = ref('');
const my_array = ref([]);

const show = (host, date, result) => {
    
  title.value = i18n("hosts_stats.page_scan_hosts.vs_result").replace("%{host}", host);
  title.value = title.value.replace("%{date}",date);

  body.value = result;
  my_array.value = result.split("|");
  modal_id.value.show();
};



const close = () => {
    modal_id.value.close();
};


defineExpose({ show, close });

onMounted(() => {
});

const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
