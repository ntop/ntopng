/**
    (C) 2023 - ntop.org    
*/

<template>
  <div ref="overlay" class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
    <div class="text-center">
      <div class="spinner-border text-primary mt-5" role="status">
        <span class="sr-only position-absolute">{{ loading }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";

const loading = i18n('loading')
const overlay = ref(null);
const props = defineProps({});

/* Show the loading */
function show_loading(time = 500) {
  $(overlay.value).fadeIn(time);
}

/* Hide the loading */
function hide_loading(time = 500) {
  $(overlay.value).fadeOut(time);
}

defineExpose({ hide_loading, show_loading });

</script>
