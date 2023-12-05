<!-- (C) 2023 ntop -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
      {{ title }}
  </template>
  <template v-slot:body>
    <div style="min-height:8.5rem">
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4"><b>{{_i18n("name")}}:</b></label>
	<div class="col-sm-6">
	  <input :pattern="pattern" placeholder="" required type="text" class="form-control" v-model="file_name">
	</div>
      </div>
    </div>
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button type="button" @click="store_file" :disabled="disable_add" class="btn btn-primary">{{_i18n("save")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const showed = () => {};
const file_name = ref("");
const order_by = ref("date"); // name / date

const props = defineProps({
    csrf: String,
    title: String,
    get_suggested_file_name: Function,
    store_file: Function,
    allow_spaces: Boolean
});

const emit = defineEmits(['file_stored']);

let pattern = NtopUtils.REGEXES.singleword;

const disable_add = computed(() => {
    let rg = new RegExp(pattern);
    return !rg.test(file_name.value);
});

const show = () => {
    init();
    modal_id.value.show();
};

async function init() {
    file_name.value = props.get_suggested_file_name();
}

const store_file = async () => {
    props.store_file(file_name.value)
    emit('file_stored', file_name.value);
    close();
}

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close });

onMounted(() => {
    if (props.allow_spaces) {
        pattern = NtopUtils.REGEXES.multiword;
    } else {
        pattern = NtopUtils.REGEXES.singleword;
    }
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
