<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
    Manage Timeseries
  </template>
  <template v-slot:body>
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button type="button" @click="apply" class="btn btn-primary">Apply</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const showed = () => {};

onMounted(async () => {
});

const show = () => {
    init();
    modal_id.value.show();
};

async function init() {
}

const apply = () => {
    close();
}

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close });

const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
