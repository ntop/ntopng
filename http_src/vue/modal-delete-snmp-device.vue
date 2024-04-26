<!-- (C) 2023 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>{{ title }}{{device}}</template>

    <template v-slot:body>      
      <div v-if="modal_type == 1" class="alert alert-danger text-start">
          {{ body }}{{device}}
      </div>
      <div v-if="modal_type == 2" class="alert alert-warning text-start">
          {{ body }}
      </div>
      <div v-if="modal_type == 3" class="alert alert-danger text-start">
          {{ body }}
      </div>
      <span class="invalid-feedback" id="delete-modal-feedback"></span>

    </template>
    <template v-slot:footer>
      <div>
        
        <button v-if="modal_type == 1"  type="button" @click="delete_" class="btn btn-danger">
          {{ _i18n("delete") }}
        </button>
        <button v-if="modal_type == 2"  type="button" @click="ping_" class="btn btn-warning">
          {{ _i18n("add") }}
        </button>
        <button v-if="modal_type == 3"  type="button" @click="delete_all_unresponsive" class="btn btn-danger">
          {{ _i18n("delete") }}
        </button>
      </div>
    </template>
  </modal>
</template>

<script setup>
/* Imports */
import { ref,  } from "vue";
import { default as modal } from "./modal.vue";

/* ****************************************************** */

const _i18n = (t) => i18n(t);
const emit = defineEmits(["delete"]);


/* Consts */
const title = ref('');
const body = ref('');
const device = ref('');
const modal_type = ref(null);

const modal_id = ref(null);

/* ****************************************************** */

/* This method is called whenever the modal is opened */
const show = (type,row) => {

  modal_type.value = type;
  switch(type) {
    case 1: {
      // delete single row case
      title.value = `${_i18n("delete")} ${_i18n("snmp.snmp_device")}: `;
      device.value = row.ip;
      body.value = `${_i18n("snmp.remove_snmp_device_confirm")}: `;
    } break;
    case 2: {
      // ping all devices case
      title.value = `${_i18n("snmp.ping_all_snmp_devices")}`;
      body.value = `${_i18n("snmp.ping_all_snmp_devices_confirm")}`;
    } break;
    case 3: {
      // prune all unresponsive devices case
      title.value = `${_i18n("snmp.prune_unresponsive_snmp_devices")}`;
      body.value = `${_i18n("snmp.prune_unresponsive_snmp_devices_confirm")}`;
    } break;
  }

  modal_id.value.show();
};

const delete_ = () => {
  emit('delete');
  close();
} 

const ping_ = () => {
  emit('ping_all');
  close();
} 

const delete_all_unresponsive = () => {
  emit('delete_unresponsive');
  close();
} 

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close });
</script>
