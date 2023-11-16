<!-- (C) 2023 ntop -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
      {{ title }}
  </template>
  <template v-slot:body>
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4" >
            <b>{{ file_title }}</b>
        </label>
        <div class="col-sm-8">
          <button type="button" @click="on_pick_file" class="btn btn-primary">{{_i18n("upload")}}</button>
          <span>&nbsp;</span>
          <small v-show="!file_content">No file selected</small>
          <small v-show="file_name">{{ file_name }}</small>
          <input ref="file_input" type='file' accept="application/JSON" @change="on_file_picked" style="display: none" />
        </div>
      </div>
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button type="button" @click="select_file" :disabled="!file_content" class="btn btn-primary">{{_i18n("open")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const showed = () => {};
const file_content = ref("");
const file_name = ref("");
const file_input = ref(null);

const props = defineProps({
    csrf: String,
    title: String,
    file_title: String,
    upload_file: Function,
});

const emit = defineEmits(['file_uploaded']);

const show = () => {
    init();
    modal_id.value.show();
};

async function init() {
    file_name.value = "";
    file_content.value = "";
}

function on_pick_file () {
    file_input.value.click()
}

function on_file_picked (event) {
    const files = event.target.files;

    file_name.value = files[0].name;

    const fileReader = new FileReader();
    fileReader.addEventListener('load', () => {
        file_content.value = fileReader.result;
    })
    fileReader.readAsText(files[0]);

    emit('file_uploaded', file_name.value);
}

const select_file = () => {
    close();
    props.upload_file(file_content.value);
}

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close });

onMounted(() => {
});

const _i18n = (t) => i18n(t);

</script>

<style scoped>
input:invalid {
  border-color: #ff0000;
}
.not-allowed {
  cursor: not-allowed;
}
</style>
