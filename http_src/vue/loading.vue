/**
(C) 2025 - ntop.org
*/

<template>
  <div ref="overlay" class="loading-overlay">
    <div class="loading-spinner" :style="styles"></div>
    <div class="loading-text">{{ loading }}</div>
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
function show_loading(time = 1500) {
  $(overlay.value).fadeIn(time);
}

/* Hide the loading */
function hide_loading(time = 4500) {
  $(overlay.value).fadeOut(time);
}

defineExpose({ hide_loading, show_loading });

</script>

<style scoped>
.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  z-index: 10;
  background-color: var(--loading-bg);
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--loading-spinner-border);
  border-top-color: var(--ntop-orange);
  border-radius: 50%;
  animation: spin 1s ease-in-out infinite;
  margin-bottom: 12px;
}

.loading-text {
  color: var(--loading-text-color);
  font-size: 14px;
  letter-spacing: 1px;
}

/* Spinner Animation */
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
