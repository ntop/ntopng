<template>
Ciao Mondo
<NoteList :note_list="notes"></NoteList>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { ntopng_custom_events, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import { default as NoteList } from "./note-list.vue";
import TableUtils from "../utilities/table-utils";
//import NtopUtils from "../utilities/ntop-utils";

const _i18n = (t) => i18n(t);

const notes = [_i18n("snmp.snmp_similarity_note"), _i18n("snmp.snmp_similarity_time_note")];

const props = defineProps({
    context: Object,
});

const table_id = "snmp_similarity_data";

onMounted(async () => {
    TableUtils.build_table(http_prefix, table_id);
});


console.log(props.context);
</script>

<style scoped>
</style>
