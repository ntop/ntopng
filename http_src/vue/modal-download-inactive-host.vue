<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("download") }}
    </template>
    <template v-slot:body>
      {{ _i18n("download_format") }}
      <div class="mt-3" style="max-width: 8rem;">
      <SelectSearch v-model:selected_option="selected_format" :options="format_list" @select_option="update_option">
      </SelectSearch>
    </div>
    </template><!-- modal-body -->

    <template v-slot:footer>
      <button type="button" @click="download" class="btn btn-primary">{{ _i18n("download") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";
import { default as SelectSearch } from "./select-search.vue";

const _i18n = (t) => i18n(t);
const format = ref('csv');
const selected_format = ref();
const format_list = [
  { label: _i18n("csv"), value: "csv", param: "csv" },
  { label: _i18n("json"), value: "json", param: "json" },
];

const emit = defineEmits(["download"]);
const modal_id = ref();

const props = defineProps({
  context: Object,
});

onMounted(() => { 
  selected_format.value = format_list[0];
});

function update_option(selected_value) {
  selected_format.value = selected_value;
}

async function download() {
  let params = ntopng_url_manager.get_url_object(window.location.search);
  params.download = true;
  params.format = selected_format.value.value;
  const url = `${http_prefix}/lua/rest/v2/get/host/inactive_list.lua?` + ntopng_url_manager.obj_to_url_params(params);
  ntopng_utility.download_URI(url, "inactive_hosts." + selected_format.value.value);
  emit("download");
  close();
}

const show = () => {
  modal_id.value.show();
};

const close = () => {
  modal_id.value.close();
};

defineExpose({ show, close });

</script>
