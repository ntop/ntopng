<!-- (C) 2026 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>
            {{ _i18n("exporter_sites_page.edit_exporter_site") }}
        </template>

        <template v-slot:body>
            <!-- exporter_site Name -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="exporter_site_name" class="form-label fw-bold mb-0">
                        {{ _i18n("exporter_sites_page.exporter_site_name") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <input
                        id="exporter_site_name"
                        type="text"
                        class="form-control"
                        :class="{ 'is-invalid': name_error }"
                        v-model="exporter_site_name"
                        @input="validateName"
                        :title="isReserved ? _i18n('exporter_sites_page.reserved_message') : ''"
                        data-bs-toggle="tooltip"
                        data-bs-placement="top"
                        :disabled="isReserved"
                        required
                    />
                    <div v-if="name_error" class="invalid-feedback">
                        {{ name_error }}
                    </div>
                </div>
            </div>

            <!-- exporter_site Description -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="exporter_site_description" class="form-label fw-bold mb-0">
                        {{ _i18n("exporter_sites_page.exporter_site_description") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <textarea
                        id="exporter_site_description"
                        class="form-control"
                        rows="3"
                        v-model="exporter_site_description"
                        :title="isReserved ? _i18n('exporter_sites_page.reserved_message') : ''"
                        data-bs-toggle="tooltip"
                        data-bs-placement="top"
                        :disabled="isReserved"
                    ></textarea>
                </div>
            </div>

            <!-- exporter_site Location -->
            <div class="row mb-3">
                <div class="col-md-3">
                    <label class="form-label fw-bold mb-0">
                        {{ _i18n("exporter_sites_page.exporter_site_location") }}
                    </label>
                </div>

                <div class="col-md-9">
                    <!-- Lat / Lng -->
                    <div class="row mb-2">
                        <div class="col">
                            <input type="number"
                                step="0.000001"
                                class="form-control"
                                placeholder="Latitude"
                                v-model.number="exporter_site_lat" />
                        </div>
                        <div class="col">
                            <input type="number"
                                step="0.000001"
                                class="form-control"
                                placeholder="Longitude"
                                v-model.number="exporter_site_lng" />
                        </div>
                    </div>
                </div>
            </div>
            <div v-if="errorMessage" class="alert alert-danger mb-3">
                {{ errorMessage }}
            </div>
        </template>

        <template v-slot:footer>
            <div class="d-flex justify-content-end w-100">
                <button
                    type="button"
                    class="btn btn-primary"
                    @click="handleSubmit"
                    :disabled="!is_form_valid"
                >
                    {{ _i18n("save") }}
                </button>
            </div>
        </template>
    </modal>
</template>


<script setup>
import { ref, computed, nextTick } from "vue";
import { default as modal } from "./modal.vue";

const _i18n = (t) => i18n(t);

const modal_id = ref(null);

const emit = defineEmits(["edit"]);

const exporter_site_name = ref("");
const exporter_site_description = ref("");
const exporter_site_lat = ref(null);
const exporter_site_lng = ref(null);

const name_error = ref("");
const isEditMode = ref(false);
const currentItem = ref(null);

const isReserved = computed(() => {
    return currentItem.value?.exporter_site_reserved === 'true';
});

const props = defineProps({
    context: Object,
    errorMessage: String
});

const is_form_valid = computed(() => {
    return exporter_site_name.value.trim().length > 1 && !name_error.value;
});

const validateName = () => {
    if (isReserved.value) {
        name_error.value = "";
        return;
    }
    const trimmed = exporter_site_name.value.trim();

    if (!trimmed) {
        name_error.value = _i18n("error_messages.name_cannot_be_empty");
    } else if (trimmed.length <= 1) {
        name_error.value = _i18n("error_messages.name_must_be_longer_than_1_character");
    } else {
        name_error.value = "";
    }
};

const handleSubmit = () => {
    validateName();
    if (!is_form_valid.value) return;

    const formData = {
        exporter_site_name: exporter_site_name.value.trim(),
        exporter_site_description: exporter_site_description.value.trim(),
        exporter_site_lat: exporter_site_lat.value,
        exporter_site_lng: exporter_site_lng.value,
        item: currentItem.value
    };

    if (isEditMode.value) {
        emit("edit", formData);
    } else {
        emit("add", formData);
    }

};

const showAdd = () => {
    currentItem.value = null;
    exporter_site_name.value = "";
    exporter_site_description.value = "";
    exporter_site_lat.value = null;
    exporter_site_lng.value = null;
    name_error.value = "";
    isEditMode.value = false;

    modal_id.value.show();
};


const showEdit = async (item) => {
    currentItem.value = item;
    exporter_site_name.value = item.exporter_site_name;
    exporter_site_description.value = item.exporter_site_description || "";
    exporter_site_lat.value = item.exporter_site_lat;
    exporter_site_lng.value = item.exporter_site_lng;

    name_error.value = "";
    isEditMode.value = true;

    modal_id.value.show();
    await nextTick();
};


const close = () => {
    modal_id.value.close();
};

defineExpose({ showEdit, showAdd, close });

</script>