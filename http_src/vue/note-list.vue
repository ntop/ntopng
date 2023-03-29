<!-- (C) 2022-23 - ntop.org     -->

<template>
  <div id="script-description" class="notes bg-light border" role="alert">
    <b>{{ _i18n('notes') }}</b>
    <ul>
      <template v-for="note in props.note_list">
        <li>{{ note }}</li>
      </template>
    </ul>
  </div>
</template>

<script setup>
import { ref } from "vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  note_list: Array,
});
</script>
