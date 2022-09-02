<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    {{body}}
  </template>
  <template v-slot:footer>
    <button type="button" @click="autolayout_" class="btn btn-primary">{{_i18n('confirm')}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const emit = defineEmits(['autolayout'])

const showed = () => {};

const props = defineProps({
    body: String,
    title: String,
});

const show = () => {
    modal_id.value.show();
};

const autolayout_ = () => {
    emit('autolayout');
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
