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
}

.loading-overlay {
  background-color: rgba(15, 23, 42, 0.9);
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #334155;
  border-radius: 50%;
  border-top-color: var(--ntop-orange); /* Spinning part ntop orange */
  animation: spin 1s ease-in-out infinite;
  margin-bottom: 12px;
}

.loading-text {
  color: #e2e8f0;
  font-size: 14px;
  letter-spacing: 1px;
}

/* Light theme */
:root[data-theme="light"] .loading-overlay,
[data-theme="light"] .loading-overlay {
  background-color: rgba(243, 244, 246, 0.9);
}

:root[data-theme="light"] .loading-spinner,
[data-theme="light"] .loading-spinner {
  border: 3px solid #6b7280;
  border-top-color: var(--ntop-orange);
}

:root[data-theme="light"] .loading-text,
[data-theme="light"] .loading-text {
  color: #374151;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>