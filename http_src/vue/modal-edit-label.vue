<!-- (C) 2026 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>
            {{ _i18n("labels_page.edit_label") }}
        </template>

        <template v-slot:body>
            <!-- Label Name -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="label_name" class="form-label fw-bold mb-0">
                        {{ _i18n("labels_page.label_name") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <input
                        id="label_name"
                        type="text"
                        class="form-control"
                        :class="{ 'is-invalid': name_error }"
                        v-model="label_name"
                        @input="validateName"
                        :title="isReserved ? _i18n('labels_page.reserved_message') : ''"
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

            <!-- Label Color -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="label_color" class="form-label fw-bold mb-0">
                        {{ _i18n("labels_page.label_color") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <input
                        id="label_color"
                        type="color"
                        class="form-control form-control-color"
                        v-model="label_color"
                        required
                    />
                </div>
            </div>

            <!-- Label Description -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="label_description" class="form-label fw-bold mb-0">
                        {{ _i18n("labels_page.label_description") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <textarea
                        id="label_description"
                        class="form-control"
                        rows="3"
                        v-model="label_description"
                        :title="isReserved ? _i18n('labels_page.reserved_message') : ''"
                        data-bs-toggle="tooltip"
                        data-bs-placement="top"
                        :disabled="isReserved"
                    ></textarea>
                </div>
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

const label_name = ref("");
const label_color = ref("#000000");
const label_description = ref("");

const name_error = ref("");
const currentItem = ref(null);

const isReserved = computed(() => {
    return currentItem.value?.label_reserved === 'true';
});

const props = defineProps({
    context: Object,
});

const is_form_valid = computed(() => {
    return label_name.value.trim().length > 1 && !name_error.value;
});

const validateName = () => {
    if (isReserved.value) {
        name_error.value = "";
        return;
    }
    const trimmed = label_name.value.trim();

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

    if (!is_form_valid.value) {
        return;
    }

    emit("edit", {
        label_name: label_name.value.trim(),
        label_color: label_color.value,
        label_description: label_description.value.trim(),
        item: currentItem.value
    });

    close();
};

const showEdit = async (item) => {
    currentItem.value = item;
    label_name.value = item.label_name;
    label_color.value = item.label_color || "#000000";
    label_description.value = item.label_description || "";

    name_error.value = "";

    await nextTick();
    modal_id.value.show();
};

const close = () => {
    modal_id.value.close();
};

defineExpose({ showEdit, close });

</script>

