<!-- (C) 2022-23 - ntop.org     -->

<template>
  <div id="script-description" class="notes bg-light border" role="alert" style="overflow-wrap: anywhere !important;">
    <b>{{ _i18n('notes') }}</b>
    <ul>
      <template v-for="note in props.note_list">
        <li v-html="note"></li>
      </template>
      <template v-if="props.add_sub_notes">
        <ul>
          <template v-for="note in props.sub_note_list">
            <li v-html="note"></li>
          </template>
        </ul>
      </template>  
    </ul>
  </div>
</template>

<script setup>
import { ref } from "vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  note_list: Array,
  sub_note_list: Array,
  add_sub_notes: Boolean,
});
</script>
