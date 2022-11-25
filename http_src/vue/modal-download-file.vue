<!-- (C) 2022 - ntop.org     -->
<template>
<modal ref="modal_id">
  <template v-slot:title>
    {{props.title}}
  </template>
  <template v-slot:body>
    <div class="form-group mt-2 row">
      <label class="col-form-label col-sm-4" >
        <b>{{_i18n("modal_download_file.filename")}}:</b>
      </label>
      <div class="col-sm-6">
	<input class="form-control" v-model="filename" required type="text" placeholder="">
      </div>
      <label class="col-form-label col-sm-2">
	.{{props.ext}}
      </label>
    </div>    
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button type="button" @click="download" class="btn btn-primary" :disabled="filename == null || filename == ''" >{{_i18n("modal_download_file.download")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const filename = ref("");

const props = defineProps({
    title: String,
    ext: String,
});

const emit = defineEmits(["download"]);

const show = (name) => {
    filename.value = name;
    modal_id.value.show();
};

function download() {
    let name = `${filename.value}.${props.ext}`;
    emit('download', name);
    close();
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
