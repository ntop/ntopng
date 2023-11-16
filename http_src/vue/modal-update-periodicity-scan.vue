<!-- (C) 2022 - ntop.org     -->
<template>
    <modal @showed="showed()" ref="modal_id">
      <template v-slot:title>{{title}}</template>
      <template v-slot:body>
        <div class="form-group ms-2 me-2 mt-3 row">

        <label class="col-form-label col-sm-4" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.automatic_scan")}}</b>
        </label>
        <div class="col-8">
          
          <SelectSearch v-model:selected_option="selected_scan_frequency"
                :options="automatic_scan_frequencies_list">
          </SelectSearch> 
      </div>
      </div>
      </template>
      <template v-slot:footer>
        <button type="button" @click="update_" class="btn btn-secondary me-4">{{_i18n('hosts_stats.page_scan_hosts.update_all')}}</button>
      </template>
    </modal>
    </template>
    
<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as SelectSearch } from "./select-search.vue";

import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const emit = defineEmits(['update',]);

const props = defineProps({
        title: String,
    });
const automatic_scan_frequencies_list = ref([
  { id: "disabled", label:i18n('hosts_stats.page_scan_hosts.disabled')},
  { id: "1day", label:i18n('hosts_stats.page_scan_hosts.every_night')},
  { id: "1week", label:i18n('hosts_stats.page_scan_hosts.every_week')},
]);

let selected_scan_frequency = ref(automatic_scan_frequencies_list.value[0]);
    
const showed = () => {};

//  const title = ref(i18n("hosts_stats.page_scan_hosts.delete_host_title"))

const show = (row) => {
  modal_id.value.show();
};

const update_ = () => {
    emit('update', {scan_frequency: selected_scan_frequency.value.id});

    close();
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
