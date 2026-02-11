<!-- (C) 2026 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ title }}
    </template>
    <template v-slot:body>
      {{ message }}
      <div v-if="show_return_msg" class="text-left">
      </div>
    </template><!-- modal-body -->
    <template v-slot:footer>
      <button type="button" @click="reset_label" class="btn btn-danger">{{ _i18n("reset") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { default as modal } from "./modal.vue";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const message = ref('')
const return_message = ref('')
const show_return_msg = ref(false)
const title = ref('')
const err = ref(false);
const row = ref(null);
const label_id = ref(null);

const emit = defineEmits(["reset"]);

const props = defineProps({
  context: Object,
});

onMounted(() => { });

/* ****************************************** */

/* This function simply reset the modal to factory values */
async function resetModal() {
  row.value = null;
  message.value = '';
  return_message.value = '';
  show_return_msg.value = false;
  err.value = false;
  title.value = '';
}

/* ****************************************** */

/* This function formats the reset message */
async function formatMessage(label) {
  title.value = i18n("labels_page.reset_label_title")
  if (label) {
    const label_name = label.label_name;
    title.value = title.value + ": " + label_name;
  }
  message.value = i18n('labels_page.reset_label');
}

/* ****************************************** */

async function reset_label() {
  const formData = {
    label_id: label_id.value,
    reset: true
  };
  emit("reset", formData);
}


const showReset = async (item) => {
  resetModal();
  label_id.value = item.label_id;
  formatMessage(item);
  modal_id.value.show();
};

const close = () => {
  setTimeout(() => {
    modal_id.value.close();
  }, 500 /* 0.5 seconds */)
};

defineExpose({ showReset, close });

</script>
