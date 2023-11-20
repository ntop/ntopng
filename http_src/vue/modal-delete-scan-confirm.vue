<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    {{ body }}
    <NoteList v-if="show_note_list"
      :note_list="note_list">
    </NoteList>
  </template>
  <template v-slot:footer>
    <template v-if="delete_type == 'delete_all' || delete_type == 'delete_single_row'">
      <button type="button" @click="delete_" class="btn btn-danger">{{_i18n('delete')}}</button>
    </template>
    <template v-else>
      <button type="button" @click="delete_" class="btn btn-primary">{{_i18n('hosts_stats.page_scan_hosts.schedule_scan')}}</button>

    </template>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as NoteList } from "./note-list.vue";

const modal_id = ref(null);
const emit = defineEmits(['delete','delete_all']);

const showed = () => {};

const props = defineProps({
    body: String,
    title: String,
});
const body = ref('');
const title = ref('');
const delete_type = ref('');
const show_note_list = ref(true);
const note_list = [
  i18n('note_scan_host')
];

const show = (type, value) => {
  show_note_list.value = false;
  delete_type.value = type

    if(type == "delete_all") {
      title.value = i18n("delete_all_entries");
      body.value = value;
    } else if(type == "delete_single_row") {
      title.value = i18n("delete_vs_host_title");
      body.value = value;
    } else if(type == "scan_all_rows") {
      title.value = i18n("scan_all_hosts_title");
      body.value = value;
    } else if(type == "scan_row") {
      show_note_list.value = true;
      title.value = i18n("scan_host_title");
      body.value = value;
    } else if (type == "delete_single_report") {
      title.value = i18n("hosts_stats.page_scan_hosts.reports_page.delete_title");
      body.value = i18n("hosts_stats.page_scan_hosts.reports_page.delete_description");
    }
    
    modal_id.value.show();
};

const delete_ = () => {
    if (delete_type.value == "delete_all") {
      emit('delete_all');
    } else if ( delete_type.value == "delete_single_row") {
      emit('delete');
    } else if (delete_type.value == "scan_all_rows") {
      emit('scan_all_rows');
    } else if (delete_type.value == "scan_row") {
      emit('scan_row');
    }
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
