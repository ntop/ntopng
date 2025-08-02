<!-- (C) 2025 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>
            {{ isEditMode ? _i18n("host_pools.edit_host_pool_member") : _i18n("host_pools.add_host_pool_member") }}
        </template>
        <template v-slot:body>
            <!-- Name Input Box -->
            <div class="mb-3 mt-3">
                <label for="pool_name" class="form-label fw-bold">{{ _i18n("host_pools.pool_name") }}</label>
                <input id="pool_name" type="text" class="form-control" :class="{ 'is-invalid': name_error }"
                    v-model="pool_name" :placeholder="_i18n('enter_pool_name')" @input="validateName" required />
                <div v-if="name_error" class="invalid-feedback">
                    {{ name_error }}
                </div>
            </div>
        
            <!-- modal-body -->
        </template>
        <template v-slot:footer>
            <div class="d-flex justify-content-end w-100">
                <button type="button" @click="handleSubmit" class="btn btn-primary" :disabled="!is_name_valid">
                    {{ isEditMode ? _i18n("save") : _i18n("add") }}
                </button>
            </div>
        </template>
    </modal>
</template>

<script setup>
import { ref, onMounted, computed, nextTick } from "vue";
import { default as modal } from "./modal.vue";

const _i18n = (t) => i18n(t);

const modal_id = ref(null);

// Define both emits for add and edit operations
const emit = defineEmits(["add", "edit"]);

// Form inputs
const pool_name = ref("");
const pool_members = ref("");
const name_error = ref("");

// edit mode and current item
const isEditMode = ref(false);
const currentItem = ref(null);

const props = defineProps({
    context: Object,
});

// check if name is valid
const is_name_valid = computed(() => {
    return pool_name.value &&
        pool_name.value.trim().length > 1 &&
        !name_error.value;
});

const validateName = () => {
    const trimmed_name = pool_name.value.trim();

    if (!trimmed_name) {
        name_error.value = _i18n("error_messages.name_cannot_be_empty");
    } else if (trimmed_name.length <= 1) {
        name_error.value = _i18n("error_messages.name_must_be_longer_than_1_character");
    } else {
        name_error.value = "";
    }
};

onMounted(() => { });

// call correct emit if edit or not
function handleSubmit() {
    // validate before submitting
    validateName();

    if (!is_name_valid.value) {
        return;
    }

    const formData = {
        pool_name: pool_name.value.trim(),
        pool_members: pool_members.value
    };

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
    pool_name.value = "";
    pool_members.value = "";
    name_error.value = "";
    isEditMode.value = false;
    currentItem.value = null;

    modal_id.value.show();
};

// show modal for editing host pool name
const showEdit = async (item) => {
    name_error.value = "";

    isEditMode.value = true;
    currentItem.value = item;
    pool_name.value = item.pool_name;
    pool_members.value = item.pool_members || "";

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