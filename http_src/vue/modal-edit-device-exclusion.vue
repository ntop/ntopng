<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
    <template v-if="edit_all == false">
      {{title}}
    </template>
    <template v-else>
      {{ title_edit_all }}
    </template>
    
  </template>
  <template v-slot:body>
      <template v-if="edit_all == false">

      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4">{{ _i18n('edit_check.device_alias') }}</label>
        <div class="col-sm-7">
          <input type="text" name="custom_name" class="form-control" :placeholder="custom_name_placeholder"
            v-model="input_mac_address_name">
        </div>

      </div>
      </template>

      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4">{{ _i18n('edit_check.device_status') }}</label>
        <div class="col-sm-7">

          <SelectSearch v-model:selected_option="input_device_status" 
            :options="device_status_list">
          </SelectSearch>
        </div>
      </div>
      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4 pt-2">{{ _i18n('edit_check.trigger_device_disconnected_alert') }}</label>
        <div class="form-switch col-sm-7 pt-2 ps-3">
          <input type="checkbox" class="form-check-input ms-0" v-model="input_trigger_alerts">
        </div>
        <small class="col-form-label">{{ _i18n('edit_check.trigger_device_disconnected_alert_descr') }}</small>
      </div>
    </template>
    <template v-slot:footer>
      <button type="button" @click="edit_" class="btn btn-primary">{{ _i18n('edit') }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";


const input_mac_address_name = ref("");
const input_device_status = ref("");
const input_trigger_alerts = ref("");

const custom_name_placeholder = ref(i18n('if_stats_config.custom_name'));
const modal_id = ref(null);
const emit = defineEmits(['edit']);

const showed = () => { };

const props = defineProps({
    title: String,
    title_edit_all: String,
});


const _i18n = (t) => i18n(t);
const device_status_list = ref([
  {id: "allowed", value:"allowed", label:_i18n('allowed') },
  {id: "denied", value:"denied", label:_i18n('denied') },
])

const edit_all = ref(false);

const show = (row) => {
    if(row != null) {
      input_device_status.value = row.status;
      input_mac_address_name.value = row.mac_address.mac;
      input_trigger_alerts.value = row.trigger_alert || false;
    } else {
      input_device_status.value = device_status_list.value[0];
      edit_all.value = true;
    }
    
    modal_id.value.show();
};

const edit_ = () => {
    if(edit_all.value == false)
      emit('edit', { mac_alias: input_mac_address_name.value, mac_status: input_device_status.value.value, trigger_alerts: input_trigger_alerts.value });
    else 
      emit('edit', { mac_status: input_device_status.value.value, trigger_alerts: input_trigger_alerts.value, mac_alias: 'all', });

    close();
};

const close = () => {
  modal_id.value.close();
};


defineExpose({ show, close });

onMounted(() => {
});

</script>

<style scoped></style>
