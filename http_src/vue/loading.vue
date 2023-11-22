/**
    (C) 2023 - ntop.org    
*/

<template>
  <div ref="overlay" class="overlay centered-message">
    <div class="text-center">
      <div class="spinner-border text-primary mt-6" :style="styles" role="status">
        <span class="sr-only position-absolute">{{ loading }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";

const loading = i18n('loading')
const overlay = ref(null);
const props = defineProps({
  styles: String
});

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
