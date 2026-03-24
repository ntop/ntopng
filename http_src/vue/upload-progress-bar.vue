<!-- (C) 2024 - ntop.org -->
<template>
  <Transition name="ntop-uprogress-fade">
    <div v-if="visible" class="ntop-uprogress">
      <!-- Track + percentage + elapsed time row -->
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
        <span v-if="elapsed_secs > 0" class="ntop-uprogress__elapsed">
          <i class="fas fa-clock"></i> {{ elapsed_label }}
        </span>
      </div>

      <!-- Status label row -->
      <div class="ntop-uprogress__status">
        <Transition name="ntop-uprogress-meta-fade" mode="out-in">
          <span v-if="processing" key="processing" class="ntop-uprogress__label">
            <Spinner :show="true" size="1rem" class="me-1"></Spinner> {{ _i18n("processing") }}
          </span>
          <span v-else-if="uploading" key="uploading" class="ntop-uprogress__label">
            <i class="fas fa-upload"></i> {{ _i18n("uploading") }}
          </span>
        </Transition>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { ref, computed, watch, onUnmounted } from "vue";
import { default as Spinner } from "./spinner.vue";

const props = defineProps({
  /** Upload progress value 0–100 */
  progress:          { type: Number,  default: 0 },
  /** Whether the progress bar is rendered */
  visible:           { type: Boolean, default: false },
  /** Whether an upload is currently in progress */
  active: { type: Boolean, default: false },
});

const _i18n = (t) => i18n(t);

const clampedProgress = computed(() =>
  Math.min(100, Math.max(0, Math.round(props.progress)))
);

// uploading = transfer in flight
// processing = transfer done, awaiting server response
const uploading  = computed(() => clampedProgress.value < 100);
const processing = computed(() => clampedProgress.value === 100);

// Elapsed time ticker
const elapsed_secs = ref(0);
let timer_id = null;

function start_timer() {
  elapsed_secs.value = 0;
  timer_id = setInterval(() => { elapsed_secs.value++; }, 1000);
}

function stop_timer() {
  if (timer_id !== null) {
    clearInterval(timer_id);
    timer_id = null;
  }
}

// Start when active flips on, stop when it flips off
watch(() => props.active, (is_active) => {
  if (is_active) start_timer();
  else           stop_timer();
});

onUnmounted(stop_timer);

const elapsed_label = computed(() => {
  const s = elapsed_secs.value;
  if (s < 60)   return `${s}s`;
  if (s < 3600) return `${Math.floor(s / 60)}m ${s % 60}s`;
  return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
});
</script>

<style scoped>
.ntop-uprogress {
  margin-top: 0.75rem;
}

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
.ntop-uprogress__elapsed {
  width: 3.5rem;
  text-align: right;
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--ntop-text-color, #111111);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  flex-shrink: 0;
}

.ntop-uprogress__status {
  margin-top: 0.35rem;
  min-height: 1.25rem;
}

.ntop-uprogress__label {
  font-size: 0.78rem;
  font-weight: 600;
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
}

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