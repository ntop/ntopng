<!-- (C) 2025 - ntop.org     -->
<template>
    <div class="m-2 px-3">
        <Slider v-model="timelineValue" :format="format" :min="timelineMin" :max="timelineMax" :step="timelineStep"
            :disabled="disabled_date_picker" tooltipPosition="right" @change="onSliderChange" class="slider-blue" />
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { ntopng_utility, ntopng_url_manager, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import Slider from '@vueform/slider'
import FormatterUtils from "../utilities/formatter-utils.js";

const props = defineProps({
    id: String,
    min_epoch: Number,
    disabled_date_picker: Boolean,
});

const emit = defineEmits(['epoch_change']);

const timelineValue = ref(0)
const timelineMin = ref(0)
const timelineMax = ref(0)
const timelineStep = ref(24 * 60 * 60) /* day */

const format = function (value) {
    let today = FormatterUtils.getMidnightEpoch(ntopng_utility.get_utc_seconds(Date.now()));
    if (value == today) {
        return i18n("live");
    }
    
    let str = FormatterUtils.formatDateTime(value, 'date_only');
    return str;
}

/* ************************************** */

onBeforeMount(() => {
    let min = props.min_epoch;
    let today = FormatterUtils.getMidnightEpoch(getUTCSeconds(Date.now()));
    if (!min || FormatterUtils.getMidnightEpoch(min) == today) {
        let yesterday = FormatterUtils.getMidnightEpoch(today - timelineStep.value);
        min = yesterday; /* set begin time to yesterday at least */
    }
    setSliderMin(min);
})

/* ************************************** */

onMounted(() => {
    let epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
    let epoch_end = ntopng_url_manager.get_url_entry("epoch_end");

    if (epoch_begin != null && epoch_end != null) {
        // update the status
        epoch_begin = Number.parseInt(epoch_begin);
        epoch_begin = FormatterUtils.getMidnightEpoch(epoch_begin); /* align to midnight */
        epoch_end = epoch_begin + timelineStep.value;

        emitEpochChange({ epoch_begin: epoch_begin, epoch_end: epoch_end }, props.id, true);
    }

    ntopng_events_manager.on_event_change(props.id, ntopng_events.EPOCH_CHANGE, (new_status) => onStatusUpdated(new_status), true);

    // notifies that component is ready
    ntopng_sync.ready(props.id);
})

/* ************************************** */

function setSliderValue(val) {
    timelineValue.value = val;
}

/* ************************************** */

function setSliderMin(val) {
    timelineMin.value = FormatterUtils.getMidnightEpoch(val);
}

/* ************************************** */

function setSliderMax(val) {
    timelineMax.value = val;
}

/* ************************************** */

const getUTCSeconds = function (utc_ms) {
    return ntopng_utility.get_utc_seconds(utc_ms);
}

/* ************************************** */

const emitEpochChange = function (epoch_status, id, emit_only_global_event) {
    if (epoch_status.epoch_end == null || epoch_status.epoch_begin == null) { return; };
    if (id != props.id) {
        onStatusUpdated(epoch_status);
    }
    ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, epoch_status, props.id);
    if (emit_only_global_event) {
        return;
    }
    let today = FormatterUtils.getMidnightEpoch(ntopng_utility.get_utc_seconds(Date.now()));
    if (epoch_status.epoch_begin == today) {
        epoch_status.isToday = true
    }
    emit("epoch_change", epoch_status);
}

/* ************************************** */

function onSliderChange(newValue) {
    let epoch_begin = newValue;
    let epoch_end = newValue + timelineStep.value;
    let epoch_status = { epoch_begin: epoch_begin, epoch_end: epoch_end };
    ntopng_url_manager.add_obj_to_url(epoch_status);
    emitEpochChange(epoch_status, props.id);
}

/* ************************************** */

const onStatusUpdated = function (status) {
    let now = getUTCSeconds(Date.now());
    now = FormatterUtils.getMidnightEpoch(now);

    setSliderMax(now);

    if (status.epoch_end != null && status.epoch_begin != null
        && Number.parseInt(status.epoch_end) > Number.parseInt(status.epoch_begin)) {
        status.epoch_begin = Number.parseInt(status.epoch_begin);
        status.epoch_end = Number.parseInt(status.epoch_end);
    } else {
        // First iteration, set to Now
        let now = getUTCSeconds(Date.now());
        status.epoch_begin = now;
        status.epoch_end = now + timelineStep.value;

        ntopng_url_manager.add_obj_to_url(status);
        /* Skip the emit on the first */
        //emitEpochChange(status, props.id);
    }

    setSliderValue(status.epoch_begin);

    ntopng_url_manager.add_obj_to_url({ epoch_begin: status.epoch_begin, epoch_end: status.epoch_end });
}

</script>

<style scoped>

.slider-blue {
  --slider-connect-bg: #3B82F6;
  --slider-tooltip-bg: #3B82F6;
  --slider-handle-ring-color: #3B82F630;
}

</style>
