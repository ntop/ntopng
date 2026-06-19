<!-- (C) 2026 - ntop.org     -->
<template>
    <!-- Modal component wrapper for add/edit site form -->
    <modal ref="modal_id">
        <!-- Modal header title - changes based on context (add/edit) -->
        <template v-slot:title>
            {{ _i18n("sites_page.edit_site") }}
        </template>

        <!-- Modal body containing the form fields -->
        <template v-slot:body>
            <!-- ==================== Site Name Field ==================== -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="site_name" class="form-label fw-bold mb-0">
                        {{ _i18n("sites_page.site_name") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <!-- Name input with validation styling -->
                    <input id="site_name" type="text" class="form-control" :class="{ 'is-invalid': name_error }"
                        v-model="site_name" @input="validateNameDebounced"
                        :title="isReserved ? _i18n('sites_page.reserved_message') : ''" data-bs-toggle="tooltip"
                        data-bs-placement="top" :disabled="isReserved" required />
                    <!-- Validation error message display -->
                    <div v-if="name_error" class="invalid-feedback">
                        {{ name_error }}
                    </div>
                </div>
            </div>

            <!-- ==================== Site Description Field ==================== -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="site_description" class="form-label fw-bold mb-0">
                        {{ _i18n("sites_page.site_description") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <!-- Multi-line textarea for description -->
                    <textarea id="site_description" class="form-control" rows="3" v-model="site_description"
                        :title="isReserved ? _i18n('sites_page.reserved_message') : ''" data-bs-toggle="tooltip"
                        data-bs-placement="top" :disabled="isReserved"></textarea>
                </div>
            </div>

            <!-- ==================== Parent Site Field ==================== -->
            <div class="row mb-3">
                <div class="col-md-3">
                    <label class="form-label fw-bold mb-0">
                        {{ _i18n("sites_page.parent_site") }}
                        <i class="fa-solid fa-circle-question" data-bs-toggle="tooltip" data-bs-placement="top"
                            :title="_i18n('sites_page.parent_site_description')"></i>
                    </label>
                </div>

                <div class="col-md-9">
                    <SelectSearch :options="_sitesList" :selected_option="selectedSite"
                        @update:selected_option="updateSelectedOption" />
                </div>
            </div>

            <!-- ==================== Geographic Location Fields ==================== -->
            <div class="row mb-3">
                <div class="col-md-3">
                    <label class="form-label fw-bold mb-0">
                        {{ _i18n("sites_page.site_location") }}
                    </label>
                </div>

                <div class="col-md-9">
                    <!-- Latitude/Longitude input row -->
                    <div class="row mb-2">
                        <div class="col">
                            <!-- Latitude input with high precision (6 decimal places) -->
                            <input type="number" step="0.000001" class="form-control" placeholder="Latitude"
                                v-model.number="site_lat" />
                        </div>
                        <div class="col">
                            <!-- Longitude input with high precision (6 decimal places) -->
                            <input type="number" step="0.000001" class="form-control" placeholder="Longitude"
                                v-model.number="site_lng" />
                        </div>
                    </div>
                </div>
            </div>

            <!-- Map visualization of the selected location -->
            <Transition name="fade-scale">
                <Geomap ref="geomap" :geomapDataArray="geomapDataArray" :tooltipFormatter="formatTooltipData"
                    :glowDots="true" :style="['height: 25vh']" :onMapClick="handleMapClick" />
            </Transition>
        </template>

        <!-- Modal footer with action buttons -->
        <template v-slot:footer>
            <div class="d-flex w-100">
                <!-- Error message display area (validation errors, server errors) -->
                <div v-if="errorMessage" class="alert alert-danger alert-danger-sm col-8">
                    {{ errorMessage }}
                </div>
                <!-- Submit button - disabled until form is valid -->
                <button type="button" class="btn btn-primary ms-auto" @click="handleSubmit" :disabled="!is_form_valid">
                    {{ _i18n("save") }}
                </button>
            </div>
        </template>
    </modal>
</template>


<script setup>
import { ref, computed, nextTick, watch } from "vue";
import { default as modal } from "./modal.vue";
import regexValidation from "../utilities/regex-validation"
import SelectSearch from "./select-search.vue";
import { default as Geomap } from "./geomap.vue";

// Internationalization helper
const _i18n = (t) => i18n(t);

// ==================== Refs and State ====================
const modal_id = ref(null);                    // Reference to modal component
const geomapDataArray = ref([]);                // Data for the map visualization
const geomap = ref(null);

// Form field bindings
const site_name = ref("");             // Site name
const site_description = ref("");      // Site description
const site_lat = ref(0);               // Latitude coordinate
const site_lng = ref(0);                // Longitude coordinate
// Explicit "no parent" entry: lets the parent field be left empty.
const NO_PARENT_OPTION = { id: 0, label: _i18n("sites_page.no_parent_site"), title: _i18n("sites_page.no_parent_site") };
const currentSiteId = ref(null);            // id of the site being edited (null in add mode)
const selectedSite = ref(NO_PARENT_OPTION); // currently selected parent (defaults to "no parent")

// Form state management
const name_error = ref("");                      // Validation error message for name field
const isEditMode = ref(false);                   // Flag: true = edit mode, false = add mode
const currentItem = ref(null);                    // Currently edited item (null for add mode)

// ==================== Component Events ====================
const emit = defineEmits(["edit", "add"]);        // Emit edit or add event on form submission

// ==================== Props ====================
const props = defineProps({
    context: Object,        // Context data (csrf, etc.)
    errorMessage: String,   // Error message from parent component
    sitesList: Object
});

// ==================== Computed Properties ====================

// Check if current site is reserved (default site that cannot be modified)
const isReserved = computed(() => {
    return currentItem.value?.site_reserved === 'true';
});

// Form validity check for enabling/disabling submit button
// Requirements: name not empty, name length > 1, no validation errors
const is_form_valid = computed(() => {
    return site_name.value.trim().length > 1 && !name_error.value;
});

// Build the parent options from the sites list. The site currently being
// edited is excluded (a site cannot be its own parent) and an explicit
// "no parent" entry is prepended so the field can be left empty.
const _sitesList = computed(() => {
    const list = Array.isArray(props.sitesList) ? props.sitesList : [];
    const options = list
        .filter((t) => !(isEditMode.value && currentSiteId.value != null && String(t.id) === currentSiteId.value))
        .map((t) => ({ id: t.id, label: t.name, title: t.name }));
    return [NO_PARENT_OPTION, ...options];
});

/* ************************************** */

const updateSelectedOption = (item) => {
    selectedSite.value = item;
}

// ==================== Watchers ====================

/**
 * Watcher for latitude and longitude.
 * This watcher is triggered whenever the user updates the
 * `site_lat` or `site_lng` fields.
 * 
 * Purpose:
 * - Updates `geomapDataArray` with a single point representing
 *   the current site location.
 */

watch([site_lat, site_lng], ([newLat, newLng]) => {
    if (newLat != null && newLng != null) {
        geomapDataArray.value = [{
            name: site_name.value || "",               // Current site name
            description: site_description.value || "", // Current description
            lat: newLat,                                        // Updated latitude
            lng: newLng                                         // Updated longitude
        }];
    }
});

// ==================== Validation Methods ====================

let debounce_name_timer = null;

function validateNameDebounced() {
    clearTimeout(debounce_name_timer)
    debounce_name_timer = setTimeout(() => {
        validateName()
    }, 400) // wait 400 ms before checking the input in order to not check each single character
}

/**
 * Validates the site name according to business rules:
 * - Cannot be empty
 * - Must be longer than 1 character
 * - Must contain only alphanumeric characters and spaces
 * 
 * For reserved sites, validation is skipped (field is disabled)
 */
const validateName = () => {
    // Reserved sites bypass validation
    if (isReserved.value) {
        name_error.value = "";
        return;
    }

    const trimmed = site_name.value.trim();
    // Unicode-aware regex that allows letters, numbers, and spaces
    const alphanumericRegex = /^[\p{L}0-9 ]+$/u;

    if (!trimmed) {
        name_error.value = _i18n("error_messages.name_cannot_be_empty");
    } else if (trimmed.length <= 1) {
        name_error.value = _i18n("error_messages.name_must_be_longer_than_1_character");
    } else if (!alphanumericRegex.test(trimmed)) {
        name_error.value = _i18n("error_messages.name_must_be_alphanumeric");
    } else {
        name_error.value = "";
    }
};

/* ************************************** */

/**
 * Updates latitude and longitude when the user clicks on the map.
 * Called by the <Geomap> component via the onMapClick prop.
 */
const handleMapClick = ({ lat, lng }) => {
    site_lat.value = parseFloat(lat.toFixed(6)); // round to 6 decimals
    site_lng.value = parseFloat(lng.toFixed(6));
};

/* ************************************** */

/**
 * Formats the tooltip content for map markers
 * Creates an HTML structure with site name, description, and coordinates
 * 
 * @param {Object} site - Site data object with name, description, lat, lng
 * @returns {string} HTML string for tooltip
 */
function formatTooltipData(site) {
    return `
        <div class="custom-tooltip-content">
            <h6>${site.name}</h6>
            <hr/>
            <div>${site.description ?? ''}</div>
            <small>${site.lat}, ${site.lng}</small>
        </div>
    `;
}

/**
 * Handles form submission:
 * 1. Validates the form
 * 2. If valid, emits appropriate event (edit or add) with form data
 */
const handleSubmit = () => {
    validateName();
    if (!is_form_valid.value) return;

    // The parent is optional: 0 means "no parent"
    let parent_id = Number(selectedSite.value?.id ?? 0);
    if (!Number.isFinite(parent_id)) parent_id = 0;

    // A site can never be its own parent (self is already excluded
    // from the options list, this just covers any edge case).
    if (isEditMode.value && currentSiteId.value != null && String(parent_id) === currentSiteId.value) {
        parent_id = 0;
    }

    // Prepare form data object
    const formData = {
        site_name: site_name.value.trim(),
        site_description: site_description.value.trim(),
        site_lat: site_lat.value,
        site_lng: site_lng.value,
        item: currentItem.value,
        site_parent: parent_id
    };

    // Emit appropriate event based on mode
    if (isEditMode.value) {
        emit("edit", formData);
    } else {
        emit("add", formData);
    }
};

/**
 * Opens the modal, optionally with pre-filled data for editing
 * 
 * @param {Object|null} item - Site data for editing, null for add mode
 * @param {string} item.site_name - Site name
 * @param {string} item.site_description - Site description
 * @param {number} item.site_lat - Latitude
 * @param {number} item.site_lng - Longitude
 */
const open = (item = null) => {
    // Destructure item with defaults (handles both edit and add modes)
    const {
        site_name: edited_site_name = "",
        site_description: edited_site_description = "",
        site_lat: edited_site_lat = 0,
        site_lng: edited_site_lng = 0,
        // 0 means no parent
        site_parent: edited_parent_id = 0, 
        site_id: edited_site_id = null,
    } = item || {}

    // Set mode/identity first so the computed options list (which excludes the
    // site itself) is already correct before we resolve the selected parent.
    currentItem.value = item;
    // Determine mode: !!item converts to boolean (true if item exists)
    isEditMode.value = !!item;
    currentSiteId.value = (edited_site_id != null) ? String(edited_site_id) : null;

    // Populate form fields
    site_name.value = edited_site_name;
    site_description.value = edited_site_description;
    site_lat.value = edited_site_lat;
    site_lng.value = edited_site_lng;

    // Resolve the parent selection. Falls back to the explicit "no parent"
    // option when the site has no parent or the parent no longer exists.
    const parent_key = (edited_parent_id != null) ? String(edited_parent_id) : "";
    selectedSite.value = _sitesList.value.find((el) => String(el.id) === parent_key) || NO_PARENT_OPTION;

    // Reset state
    name_error.value = "";

    // Show the modal
    modal_id.value.show();
};

/**
 * Closes the modal
 */
const close = () => {
    modal_id.value.close();
};

// Expose methods to parent components
defineExpose({ open, close });

</script>

<style scoped>
.fade-scale-enter-active,
.fade-scale-leave-active {
    transition: all 0.5s ease;
}

.fade-scale-enter-from {
    opacity: 0;
    transform: scaleY(0);
}

.fade-scale-enter-to {
    opacity: 1;
    transform: scaleY(1);
}

.fade-scale-leave-from {
    opacity: 1;
    transform: scaleY(1);
}

.fade-scale-leave-to {
    opacity: 0;
    transform: scaleY(0);
}

.alert-danger-sm {
    margin-bottom: 0 !important;
    padding: 0.3rem !important
}
</style>
