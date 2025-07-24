/**
(C) 2025 - ntop.org
*/

<template>
    <div ref="overlay" class="loading-overlay">
        <div class="loading-content vertical">
            <div class="loading-spinner" :style="styles"></div>
            <div class="loading-text">{{ loading }}</div>
        </div>
    </div>
</template>

<script setup>
import { ref, watch, onMounted } from "vue";

/* *************************************** */

const loading = i18n('loading')
const overlay = ref(null);
const props = defineProps({
    styles: String,
    isLoading: Boolean,
});

function adjustLoadingPosition() {
    if (!overlay.value || !overlay.value.parentElement) {
        return
    }

    const parentHeight = overlay.value.parentElement.getBoundingClientRect();
    const viewportHeight = window.innerHeight;

    /* Height higher then viewpoint, add the fixed one */
    if (parentHeight.height > viewportHeight * 0.7) {
        overlay.value?.classList.add("fixed");
    } else {
        overlay.value?.classList.remove("fixed");
    }
}

/* *************************************** */

/* By default already show the loading */
onMounted(() => {
    if (props.isLoading) {
        adjustLoadingPosition();
        showLoading();
        window.addEventListener("resize", () => adjustLoadingPosition());
    }
})

/* *************************************** */

watch(() => [props.isLoading], (cur_value, old_value) => {
    if (props.isLoading) {
        showLoading() /* isLoading is true, show the loading css */
    } else {
        hideLoading() /* isLoading is false, hide the loading css */
    }
}, { flush: 'pre' });

/* *************************************** */

/* Show the loading */
function showLoading() {
    overlay.value?.classList.add("show");
}

/* *************************************** */

/* Hide the loading */
function hideLoading() {
    overlay.value?.classList.remove("show");
}

</script>

<style scoped>
.loading-overlay {
    position: absolute;
    inset: 0;
    /* top: 0; left: 0; bottom: 0; right: 0; */
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 999;
    /* Bootstrap max overlay is 999 */
    opacity: 0;
    pointer-events: none;
    transition: opacity 1s ease;
}

.loading-overlay {
    background-color: rgba(15, 23, 42, 0.9);
}

.loading-overlay.show {
    opacity: 1;
    pointer-events: all;
}

.loading-spinner {
    width: 40px;
    height: 40px;
    border: 3px solid #334155;
    border-radius: 50%;
    border-top-color: var(--ntop-orange);
    /* Spinning part ntop orange */
    animation: spin 1s ease-in-out infinite;
    margin-bottom: 12px;
}

.loading-text {
    color: #e2e8f0;
    font-size: 14px;
    letter-spacing: 1px;
}

.loading-content {
  display: flex;
  align-items: center;
}

.loading-content.vertical {
  display: flex;
  flex-direction: column; 
  align-items: center; 
}

/* Variante fixed visibile ovunque */
.loading-overlay.fixed {
    padding-top: min(20%, 100px);
    align-items: normal !important;
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