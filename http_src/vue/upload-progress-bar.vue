<!-- (C) 2024 - ntop.org -->
<template>
  <Transition name="ntop-uprogress-fade">
    <div v-if="visible" class="ntop-uprogress">
      <!-- Track + percentage + remaining time row -->
      <div class="ntop-uprogress__row">
        <div class="ntop-uprogress__track">
          <div
            class="ntop-uprogress__bar"
            role="progressbar"
            :style="{ width: `${clampedProgress}%` }"
            :aria-valuenow="clampedProgress"
            aria-valuemin="0"
            aria-valuemax="100"
          ></div>
        </div>
        <span class="ntop-uprogress__pct">{{ clampedProgress }}%</span>
        <span v-if="active && remaining_time" class="ntop-uprogress__remaining">
          <i class="fas fa-clock"></i> {{ remaining_time }}
        </span>
      </div>

    </div>
  </Transition>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  /** Upload progress value 0–100 */
  progress: { type: Number, default: 0 },
  /** Whether the progress bar is rendered */
  visible: { type: Boolean, default: false },
  /** Whether an upload is currently in progress (enables shimmer) */
  active: { type: Boolean, default: false },
  /** Formatted remaining time string, e.g. "12s" */
  remaining_time: { type: String, default: "" },
});

const clampedProgress = computed(() =>
  Math.min(100, Math.max(0, Math.round(props.progress)))
);
</script>

<style scoped>
.ntop-uprogress {
  margin-top: 0.75rem;
}

/* Track + percentage row */
.ntop-uprogress__row {
  display: flex;
  align-items: center;
  gap: 0.625rem;
}

.ntop-uprogress__track {
  flex: 1;
  height: 8px;
  background-color: var(--bg-sunken, #f1f3f5);
  border: 1px solid var(--border-subtle, #e9ecef);
  border-radius: 100px;
  overflow: hidden;
}

.ntop-uprogress__bar {
  height: 100%;
  border-radius: 100px;
  background-color: var(--ntop-orange, #ff8f00);
  transition: width 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}

.ntop-uprogress__pct,
.ntop-uprogress__remaining {
  width: 3.5rem;
  text-align: right;
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--ntop-text-color, #111111);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  flex-shrink: 0;
}

/* Transitions */
.ntop-uprogress-fade-enter-active,
.ntop-uprogress-fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.ntop-uprogress-fade-enter-from,
.ntop-uprogress-fade-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}

.ntop-uprogress-meta-fade-enter-active,
.ntop-uprogress-meta-fade-leave-active {
  transition: opacity 0.15s ease;
}
.ntop-uprogress-meta-fade-enter-from,
.ntop-uprogress-meta-fade-leave-to {
  opacity: 0;
}
</style>
