<!-- (C) 2022 - ntop.org     -->
<template>
    <modal @showed="showed()" ref="modal_id">
      <template v-slot:title>{{title_delete}}</template>
      <template v-slot:body>
        {{body_delete}}
      </template>
      <template v-slot:footer>
        <button type="button" @click="delete_" class="btn btn-danger">{{_i18n('delete')}}</button>
      </template>
    </modal>
</template>
  
<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const emit = defineEmits(['delete','delete_all']);

const showed = () => {};
let body_delete = ref("");
let title_delete = ref("");
const props = defineProps({
    body: String,
    title: String,
});
const show = (body, title) => {

  if (body != null && title != null) {

    body_delete.value = body;
    title_delete.value = title;
  } else {

    body_delete.value = props.body;
    title_delete.value = props.title;
  }
  modal_id.value.show();
};

const delete_ = () => {
    emit('delete');

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

