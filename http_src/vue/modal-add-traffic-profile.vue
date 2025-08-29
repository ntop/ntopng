<!-- (C) 2025 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>
            {{ isEditMode ? _i18n("traffic_profiles.edit_traffic_profile") :
                _i18n("traffic_profiles.add_traffic_profile") }}
        </template>
        <template v-slot:body>
            <!-- First Row: Profile Name -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="profile_name" class="form-label fw-bold mb-0">{{ _i18n("traffic_profiles.profile_name")
                        }}</label>
                </div>
                <div class="col-md-9">
                    <input id="profile_name" type="text" class="form-control" :class="{ 'is-invalid': name_error }"
                        v-model="profile_name" placeholder="Enter profile name" @input="validateName" required />
                    <div v-if="name_error" class="invalid-feedback">
                        {{ name_error }}
                    </div>
                </div>
            </div>

            <!-- Second Row: Profile Filter -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="profile_filter" class="form-label fw-bold mb-0">{{
                        _i18n("traffic_profiles.traffic_filter_bpf") }}</label>
                </div>
                <div class="col-md-9">
                    <input id="profile_filter" type="text" class="form-control" :class="{ 'is-invalid': filter_error }"
                        v-model="profile_filter" placeholder="Enter filter in nbpf format" @input="validate_nBP_filter"
                        required />
                    <div v-if="filter_error" class="invalid-feedback">
                        {{ filter_error }}
                    </div>
                </div>
            </div>
            <NoteList :note_list="simple_notes"></NoteList>
            <NoteList :note_list="advanced_notes"></NoteList>
            <NoteList :note_list="additional_notes"></NoteList>
        </template>
        <template v-slot:footer>
            <div class="d-flex justify-content-end w-100">
                <button type="button" @click="handleSubmit" class="btn btn-primary" :disabled="!is_form_valid">
                    {{ isEditMode ? _i18n("save") : _i18n("add") }}
                </button>
            </div>
        </template>
    </modal>
</template>

<script setup>
import { ref, onMounted, computed, nextTick } from "vue";
import { default as modal } from "./modal.vue";
import { default as NoteList } from "./note-list.vue";

const _i18n = (t) => i18n(t);

const simple_notes = [
    _i18n("traffic_profiles.simple_filter_examples"),
    _i18n("traffic_profiles.http_traffic") + " tcp and port 80",
    _i18n("traffic_profiles.host_traffic") + " host 192.168.1.2",
    _i18n("traffic_profiles.facebook_traffic") + " l7proto Facebook"
];

const advanced_notes = [
    _i18n("traffic_profiles.advanced_filter_examples"),
    _i18n("traffic_profiles.traffic_between") + " ip host 192.168.1.1 and 192.168.1.2",
    _i18n("traffic_profiles.traffic_from_to") + " ip src 192.168.1.1 and dst 192.168.1.2",
    _i18n("traffic_profiles.destination_network") + " ip dst net 192.168.1.0/24",
    _i18n("traffic_profiles.host_http_https") + " ip host 192.168.1.1 and tcp port (80 or 443)",
    _i18n("traffic_profiles.source_ethernet") + " ether src host 00:11:22:33:44:55"
];

const additional_notes = [
    _i18n("traffic_profiles.note"),
    _i18n("traffic_profiles.note_0"),
    _i18n("traffic_profiles.note_1")
];

const modal_id = ref(null);

// Add and edit emits
const emit = defineEmits(["add", "edit"]);

// Form inputs
const profile_name = ref("");
const profile_filter = ref("");
const name_error = ref("");
const filter_error = ref("");

// edit mode and current item
const isEditMode = ref(false);
const currentItem = ref(null);

const props = defineProps({
    context: Object,
});

// check if form is valid
const is_form_valid = computed(() => {
    return profile_name.value &&
        profile_name.value.trim().length > 1 &&
        profile_filter.value &&
        profile_filter.value.trim().length > 0 &&
        !name_error.value &&
        !filter_error.value;
});

const validateName = () => {
    const trimmed_name = profile_name.value.trim();

    if (!trimmed_name) {
        name_error.value = _i18n("error_messages.name_cannot_be_empty");
    } else if (trimmed_name.length <= 1) {
        name_error.value = _i18n("error_messages.name_must_be_longer_than_1_character");
    } else {
        name_error.value = "";
    }
};

// validate nBPF filter using backend call, else show input cell error
async function validate_nBP_filter(){
    const trimmed_filter = profile_filter.value.trim();

    // empty filter is valid
    if (trimmed_filter === "") {
        filter_error.value = "";
        return true;
    }

    let filter_check_url = `${http_prefix}/lua/pro/rest/v2/check/filter.lua?query=${trimmed_filter}`;

    let headers = {
        'Content-Type': 'application/json'
    };

    try {
        let res = await ntopng_utility.http_request(filter_check_url, {
            method: 'get',
            headers
        });

        if (res.response === false) {
            filter_error.value = _i18n("traffic_profiles.invalid_bpf");
            return false;
        } else {
            filter_error.value = "";
            return true;
        }

    } catch (e) {
        console.error('Network error:', e.message);
        filter_error.value = _i18n("traffic_profiles.invalid_bpf");
        return false;
    }
};

onMounted(() => { });

// call edit or add emit
async function handleSubmit() {
    // Validate name
    validateName();
    
    // validate BPF filter
    const filterIsValid = await validate_nBP_filter();

    // Check if form is valid
    if (!is_form_valid.value || !filterIsValid) {
        return;
    }

    const formData = {
        profile_name: profile_name.value.trim(),
        profile_filter: profile_filter.value.trim()
    };

    // Emit to parent component
    if (isEditMode.value) {
        emit('edit', {
            ...formData,
            item: currentItem.value
        });
    } else {
        emit('add', formData);
    }

    // Close the modal
    close();
}

// Show modal for adding new item
const show = () => {
    // Reset form values
    profile_name.value = "";
    profile_filter.value = "";
    name_error.value = "";
    filter_error.value = "";
    isEditMode.value = false;
    currentItem.value = null;

    modal_id.value.show();
};

// show modal for editing traffic profile
const showEdit = async (item) => {
    name_error.value = "";
    filter_error.value = "";

    isEditMode.value = true;
    currentItem.value = item;
    profile_name.value = item.profile_name;
    profile_filter.value = item.profile_filter || "";

    await nextTick();

    // Check if modal reference exists
    if (!modal_id.value) {
        console.error('Modal reference is null after nextTick');
        return;
    }

    modal_id.value.show();
};

const close = () => {
    modal_id.value.close();
};

// show close and show edit emits
defineExpose({ show, showEdit, close });

</script>