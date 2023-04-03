<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <input class="form-control" type="text" v-model="application_name" spellcheck="false" hidden>
  <template v-slot:title>{{ title }}</template>
  <template v-slot:body>{{ body }}</template>
  <template v-slot:footer>
    <button type="button" @click="delete_" class="btn btn-primary">{{_i18n('delete')}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const emit = defineEmits(['delete']);
const _i18n = (t) => i18n(t);
const title = i18n('custom_categories.delete_app')
const body = i18n('custom_categories.delete_app_confirm')
const application_name = ref(null)

const show = (row) => {
  if(row != null) {
    application_name.value = row.application
  }
  modal_id.value.show();
};

const delete_ = () => {
  emit('delete', { 
    protocol_alias: application_name.value,
  });
    
  close();
};

const close = () => {
  modal_id.value.close();
};

defineExpose({ show, close });


</script>

<style scoped>
</style>
