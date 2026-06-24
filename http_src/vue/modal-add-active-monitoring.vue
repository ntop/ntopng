<!-- (C) 2022 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>{{ title }}</template>
        <template v-slot:body>
            <form>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b> {{ _i18n('active_monitoring_page.measurement') }}
                        </b></label>
                    <div class="col-5">
                        <SelectSearch v-model:selected_option="selected_measurement" :options="measurements_list"
                            @select_option="change_dropdowns">
                        </SelectSearch>
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b> {{ _i18n('db_search.host') }} </b></label>
                    <div class="col-5">
                        <input ref="host" class="form-control" :disabled="disable_host" type="text"
                            :placeholder="host_placeholder" required="" @input="check_host">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b> {{ _i18n('active_monitoring_page.run_monitoring') }}
                        </b></label>
                    <div class="col-5">
                        <SelectSearch v-model:selected_option="selected_granularity" :options="granularities_list"
                            :disabled="disable_granularity">
                        </SelectSearch>
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b> {{ _i18n('threshold') }} </b></label>
                    <div class="col-5">
                        <div class="input-group">
                            <span class="input-group-text measurement-operator"> {{ threshold_operator }} </span>
                            <input ref="threshold" value="99" name="threshold" type="number"
                                class="form-select rounded-right measurement-threshold" min="1" :max="threshold_max">
                        </div>
                    </div>
                    <div class="col-sm-2 pl-0">
                        <span class="my-auto ml-1 measurement-unit d-inline-block p-2"> {{ threshold_unit }} </span>
                    </div>
                </div>
                <div v-if="!disable_interface" class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b> {{ _i18n('active_monitoring_page.interface_used') }}
                        </b></label>
                    <div class="col-5">
                        <SelectSearch v-model:selected_option="selected_interface" :options="interfaces_list">
                        </SelectSearch>
                    </div>
                </div>
            </form>
            <div class="form-group">
                <NoteList :note_list="note_list"></NoteList>
            </div>
        </template>
        <template v-slot:footer>
            <div v-if="show_feedback" class="me-auto w-100 text-danger">{{ error }}</div>
            <div v-if="show_feedback" class="mt-1 notes bg-danger me-auto w-100 bg-opacity-25">
                {{ feedback }}
            </div>
            <div>
                <Spinner :show="activate_add_spinner" size="1rem" class="me-2"></Spinner>
                <button :disabled="disable_add" type="button" @click="add_" class="btn btn-primary">{{ add_button_title
                    }}</button>
            </div>
        </template>
    </modal>
</template>

<script setup>
import { ref, onBeforeMount, onMounted, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";
import { default as Spinner } from "./spinner.vue";
import regexValidation from "../utilities/regex-validation"

const modal_id = ref(null);
const emit = defineEmits(['add']);
const _i18n = (t) => i18n(t);
const disable_add = ref(true)
const show_feedback = ref(false);
const activate_add_spinner = ref(false);
const feedback = ref('');
const error = ref(i18n('active_monitoring_page.error_detected'))
const title = ref(i18n('active_monitoring_page.add_record'));
const measurements_list = ref([]);
const interfaces_list = ref([]);
const granularities_list = ref([]);
const selected_measurement = ref([])
const selected_interface = ref([])
const selected_granularity = ref([])
const disable_granularity = ref(false);
const disable_interface = ref(false);
const disable_host = ref(false);
const threshold_operator = ref('');
const threshold_unit = ref('');
const threshold_max = ref(0);
const threshold = ref(null);
const host = ref(null);
const row = ref(null);
const add_button_title = ref(i18n('add'))
const host_placeholder = ref(i18n('active_monitoring_page.host_placeholder'));

const note_list = [
    _i18n("active_monitoring_page.note_icmp"),
    _i18n("active_monitoring_page.note_http"),
    _i18n("active_monitoring_page.note_alert"),
]

const operators_list = [
    { id: "lt", label: '<' },
    { id: "gt", label: '>' },
]

/* ************************************** */

const props = defineProps({
    context: Object,
    measurements: Array,
    interfaces: Array,
    url_request: String,
});

/* ************************************** */

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.measurements], (cur_value, old_value) => {
    update_lists();
}, { flush: 'pre', deep: true });

/* ************************************** */

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.interfaces], (cur_value, old_value) => {
    const tmp = props.interfaces.filter((t) => (t.is_packet_interface && !t.is_pcap_interface))

    interfaces_list.value = tmp.map((t) => {
        return {
            id: t.ifname,
            label: t.name,
            title: t.name,
        };
    })
    selected_interface.value = interfaces_list.value[0] || [];
    disable_interface.value = (interfaces_list.value.length < 1)
}, { flush: 'pre', deep: true });

/* ************************************** */

/* Brief check regarding the host, it is checked from the back end too */
function check_host(value) {
    if (regexValidation.validateHostName(value) || regexValidation.validateIP(value) || regexValidation.validateURL(value)) {
        disable_add.value = true;
    }
    disable_add.value = false;
}

/* ************************************** */

/* Reset the values to defualt */
function reset_modal_form() {
    disable_add.value = true;
    update_lists();
    host.value.value = ''
    selected_interface.value = interfaces_list.value[0] || [];
    threshold.value.value = '99'
    row.value = null;
    add_button_title.value = i18n('add')
    title.value = i18n('active_monitoring_page.add_record');
}

/* ************************************** */

/* This function is called from the show, to correctly display the data from the selected row */
function format_edit() {
    selected_measurement.value = measurements_list.value.find((el) => el.id === row.value.last_measurement.measurement_type);
    change_dropdowns(selected_measurement.value)
    host.value.value = row.value.target.host
    threshold.value.value = row.value.threshold
    selected_interface.value = interfaces_list.value.find((el) => el.id === row.value.metadata.interface_name)
    selected_granularity.value = granularities_list.value.find((el) => el.id === row.value.metadata.granularity)
    title.value = i18n('active_monitoring_page.edit_record');
    add_button_title.value = i18n('edit')
    disable_add.value = false;
}

/* ************************************** */

/* Function automatically called when opening the modal */
const show = (_row) => {
    reset_modal_form();
    if (_row) {
        row.value = _row;
        format_edit();
    }
    modal_id.value.show();
};

/* ************************************** */

/* Function called when clicking the add button */
const add_ = async () => {
    activate_add_spinner.value = true;
    let params = {
        csrf: props.context.csrf,
        am_host: host.value.value,
        action: (row.value) ? "edit" : "add",
        granularity: selected_granularity.value.id,
        measurement: selected_measurement.value.id,
        threshold: threshold.value.value,
        ifname: selected_interface.value?.id
    }
    /* Handle the edit */
    if (row.value) {
        params.old_host = row.value.target.host
        params.old_granularity = row.value.metadata.granularity
        params.old_measurement = row.value.last_measurement.measurement_type
    }
    const rsp = await ntopng_utility.http_post_request(props.url_request, params);
    activate_add_spinner.value = false;

    if (rsp.result == 'ok') {
        show_feedback.value = false;
        emit('add', params);
        close();
    } else {
        show_feedback.value = true;
        feedback.value = rsp.result;
    }
};

/* ************************************** */

const close = () => {
    modal_id.value.close();
};

/* ************************************** */

const change_dropdowns = (item) => {
    disable_host.value = false;
    const tmp = props.measurements.find((el) => el.key === item.id);
    if (tmp.key === "throughput") {
        host_placeholder.value = i18n('active_monitoring_page.thpt_host_placeholder')
    }
    if (tmp.key === "speedtest") {
        host.value.value = "speedtest.net"
        disable_host.value = true;
        check_host(host.value.value);
    }
    granularities_list.value = tmp.granularities.map((t) => {
        return {
            id: t.value,
            label: t.title,
            title: t.title
        };
    })
    selected_granularity.value = granularities_list.value[0]
    disable_granularity.value = (granularities_list.value.length === 1)
    threshold_operator.value = operators_list.find((el) => el.id === tmp.operator).label
    threshold_unit.value = tmp.unit;
    threshold_max.value = tmp.max_threshold;
};

/* ************************************** */

onBeforeMount(() => { })

/* ************************************** */

onMounted(() => { })

/* ************************************** */

const update_lists = () => {
    measurements_list.value = props.measurements.map((t) => {
        return {
            id: t.key,
            label: t.label,
            title: t.label,
        };
    })
    selected_measurement.value = measurements_list.value[0];
    change_dropdowns(selected_measurement.value)
}

/* ************************************** */

defineExpose({ show, close });

</script>
