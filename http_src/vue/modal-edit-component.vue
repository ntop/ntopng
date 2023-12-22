<!-- (C) 2023 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>{{ title }}</template>
        <template v-slot:body>
            
            <!-- Title -->
            <div class="form-group ms-2 me-2 mt-3 row">
                <label class="col-sm-2 mt-2">
                    <b>{{ _i18n("dashboard.component_title") }}</b>
                </label>
                <div class="col-sm-10">
                    <input v-model="component_title" class="form-control" type="text" required />
                </div>
            </div>

            <!-- Width -->
            <div class="form-group ms-2 me-2 mt-4 row">
                <label class="col-sm-2 mt-3">
                    <b>{{ _i18n("dashboard.component_width") }}</b>
                </label>
                <div class="col-sm-6 mt-2">
                    <div class="range">
                    <input type="range" id="slider" v-model="width_selected" style="width:100%" min="1"
                        max="3" step="1">
                    <div class="sliderticks">
                        <p>{{ _i18n("dashboard.component_sizes.small") }}</p>
                        <p>{{ _i18n("dashboard.component_sizes.medium") }}</p>
                        <p>{{ _i18n("dashboard.component_sizes.large") }}</p>
                    </div>
                </div>
                </div>
            </div>

            
            <!-- Height -->
            <div class="form-group ms-2 me-2 mt-3 row">
                <label class="col-sm-2 mt-2">
                    <b>{{ _i18n("dashboard.component_height") }}</b>
                </label>
                <div class="col-sm-9 mt-2">
                    <div class="range">
                        <input type="range" id="slider" v-model="height_selected" style="width:100%" min="1"
                            max="4" step="1">
                        <div class="sliderticks">
                            <p>{{ _i18n("dashboard.component_sizes.small") }}</p>
                            <p>{{ _i18n("dashboard.component_sizes.medium") }}</p>
                            <p>{{ _i18n("dashboard.component_sizes.large") }}</p>
                            <p>{{ _i18n("dashboard.component_sizes.auto") }}</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Time Window -->
            <div v-if="!hiddenOnReport" class="form-group ms-2 me-2 mt-3 row">
                <label class="col-sm-2 mt-2">
                    <b>{{ _i18n("dashboard.time_window") }}</b>
                </label>
                <div class="col-sm-5">

                    <SelectSearch v-model:selected_option="selected_time_window"
                        :options="time_window_list">
                    </SelectSearch>
                </div>
            </div>

            <!-- Time Offset -->
            <div class="form-group ms-2 me-2 mt-3 row">
                <label class="col-sm-2 mt-2">
                    <b>{{ _i18n("dashboard.time_offset") }}</b>
                </label>
                <div class="col-sm-5">
                    <SelectSearch v-model:selected_option="selected_time_offset"
                        :options="time_offset_list">
                    </SelectSearch>
                </div>
            </div>

            <!-- Advanced Settings -->
            <div class="ms-2 mb-3 mt-4 row">
                <label class="col-form-label col-sm-3 pe-0" id="advanced-view">
                    <b>{{ _i18n("dashboard.advanced_settings") }}</b>
                </label>
                <div class="col-sm-2 ps-0">
                    <div class="form-check form-switch mt-2" id="advanced-view">
                        <input name="show_advanced_settings"  class="form-check-input" type="checkbox" @input="updateAdvancedSettingsView" role="switch">
                        
                    </div>
                </div>
            </div>

            <!-- REST Params -->
            <div v-if="show_advanced_settings" class="form-group ms-2 me-2 mt-3 row">
                <div class="col-sm-12">
                    <p v-if="isNotJsonParamsValid" style="color:rgba(255, 0, 0, 0.797)"> {{_i18n("dashboard.component_json_error")}} </p>
                    <textarea class="highlighted-json" v-model="params_json_data" @focusout="formatJson" style="width:100%; height:100%;" rows="16" cols="10" 
                    ></textarea>
                </div>
            </div>

        </template>
        <template v-slot:footer>
            <div>
                <button type="button" @click="edit_" :disabled="isNotJsonParamsValid" class="btn btn-primary">
                    {{ _i18n("apply") }}
                </button>
            </div>
        </template>
    </modal>
</template>
  
<script setup>

/* Imports */
import { ref } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";  
import dataUtils from "../utilities/data-utils";
/* **************************************************************************** */

/* Function to retrieve the local word */
const _i18n = (t) => i18n(t);

/* Events Emitted */
const emit = defineEmits(["edit"]);

/* Modal Properties */
const props = defineProps({
    csrf: String,
});

/* Consts */
const title = ref(i18n("dashboard.edit_component"));
const modal_id = ref(null);
const slider_values = [
    { id: 1, size_component_value: 4  },
    { id: 2, size_component_value: 6  },
    { id: 3, size_component_value: 12 },
    { id: 4, size_component_value: -1 }
];

/* Time Window options */
const time_window_list = ref([
    { value:'current', label: _i18n("dashboard.current_time"), default: true },    
    { value:'5_min', label: _i18n("dashboard.time_window_list.5_min")  },
    { value:'30_min', label: _i18n("dashboard.time_window_list.30_min") },
    { value:'hour', label: _i18n("dashboard.time_window_list.hour") },
    { value:'2_hours', label: _i18n("dashboard.time_window_list.2_hours") },
    { value:'12_hours', label: _i18n("dashboard.time_window_list.12_hours") },
    { value:'day', label: _i18n("dashboard.time_window_list.day") },
    { value:'week', label: _i18n("dashboard.time_window_list.week") },
    { value:'month', label: _i18n("dashboard.time_window_list.month") },
    { value:'year', label: _i18n("dashboard.time_window_list.year") },
]);

/* Time Offset options */
const time_offset_list = ref([
    { value:'current', label: _i18n("dashboard.current_time"), default: true }, 
    { value:'hour', label: _i18n("dashboard.time_offset_list.hour") },
    { value:'day', label: _i18n("dashboard.time_offset_list.day") },
    { value:'week', label: _i18n("dashboard.time_offset_list.week") },
    { value:'month', label: _i18n("dashboard.time_offset_list.month") },
    { value:'year', label: _i18n("dashboard.time_offset_list.year") },
]);

/* Modal Ref Consts */
const old_component_to_edit = ref(null);
const component_title = ref(null);
const width_selected = ref(null);
const height_selected = ref(null);
const params_json_data = ref(null);
const selected_time_window = ref(null);
const selected_time_offset = ref(null);
const show_advanced_settings = ref(false); // bool used to enable the advanced view
const isNotJsonParamsValid = ref(false); // bool used to validate the REST Params in textarea
const hiddenOnReport = ref(false); // bool used to hide time_window when the page is report

/* **************************************************************************** */

/**
 * 
 * @brief This method change the value of the show_advanced_settings
 *        in order to enable the advanced view or disable it.
 */
const updateAdvancedSettingsView = function() {
    show_advanced_settings.value = !show_advanced_settings.value;
}

/**
 * 
 * @brief This method changes the value of the show_advanced_settings 
 *        boolean to enable or disable the advanced view.
 */
const formatJson = function() {
    
    isNotJsonParamsValid.value = false;
    try {
        params_json_data.value = JSON.stringify(JSON.parse(params_json_data.value), null, 2);
    } catch (e) {
        isNotJsonParamsValid.value = true;
    }
    return params_json_data.value;
};

/**
 * 
 * @brief This method selects from the time_array 
 *        (either time_offset_list or time_window_list) 
 *        the object with a value equal to time_value (the old values). 
 *        In case time_value is empty or null, 
 *        the method returns the default object ('Current').
 * @param time_value The time value (5_min, hour, ...) to search for
 * @param time_array The array of time objects 
 *                   (either from time_offset_list or time_window_list).
 */
const find_time_object = function(time_value, time_array) {
    if (dataUtils.isEmptyOrNull(time_value)) {
        return time_array.find((t) => t.default);
    } else {
        return time_array.find((t) => t.value == time_value);
    }
}

/**
 * 
 *  @brief This method is called to reset the modal ref constants.
 *  */ 
const reset_modal_form = function (hidden) {
    old_component_to_edit.value = null;
    isNotJsonParamsValid.value = false;
    hiddenOnReport.value = hidden;
    component_title.value = "";
    height_selected.value = 1;
    width_selected.value = 1;
};

/* **************************************************************************** */

/**
 * 
 *  @brief This method is called to set the old data of the selected component 
 *         for editing.
 *  @param old_component_to_edit selected component to edit
 *  */ 
const set_old_component_values = (old_component) => {
    old_component_to_edit.value = old_component;

    component_title.value = old_component.custom_name;
    width_selected.value = convert_size_to_slider_value(old_component.width);
    height_selected.value = convert_size_to_slider_value(old_component.height);
    
    selected_time_window.value = find_time_object(old_component.time_window,time_window_list.value);
    selected_time_offset.value = find_time_object(old_component.time_offset, time_offset_list.value);

    params_json_data.value = JSON.stringify(old_component.params, null, 2);
};

/* **************************************************************************** */

/**
 * 
 *  @brief This method is called whenever the modal is opened 
 *  @param old_component_to_edit selected component to edit
 *  */ 
const show = (old_component_to_edit, hiddenOnReport) => {
    /* First of all reset all the data */
    reset_modal_form(hiddenOnReport);
    /* Set the old data of the component */
    set_old_component_values(old_component_to_edit);
    modal_id.value.show();
};

/* **************************************************************************** */

/**
 * 
 *  @brief Convert a slider value           (1 (Small), 2 (Medium), 3 (Large),   4 (Auto)) 
 *                 to component size value  (4 (Small), 6 (Medium), 12 (Large), -1 (Auto))
 *  @param s_v slider value 
 *  */ 
const convert_slider_value_to_size = (s_v) => {
    return slider_values.find((c) => c.id == Number(s_v)).size_component_value;
} 

/**
 * 
 *  @brief Convert a component size value (4 (Small), 6 (Medium), 12 (Large), -1(Auto))
 *         to slider value                (1 (Small), 2 (Medium), 3 (Large),  4 (Auto))  
 *  @param size component size value 
 *  */ 
const convert_size_to_slider_value = (size) => {
    return slider_values.find((c) => c.size_component_value == Number(size)).id;
} 

/* **************************************************************************** */

/**
 * 
 *  @brief Function called when the 'Apply' button is clicked 
 *         to emit an 'edit' event and close the modal.
 *  */ 
const edit_ = () => {
    const new_width     = convert_slider_value_to_size(width_selected.value);
    const new_height    = convert_slider_value_to_size(height_selected.value);
    const new_params    = `${params_json_data.value}`;

    emit("edit", {
        id: old_component_to_edit.value.id,
        title: component_title.value,
        height: new_height,
        width: new_width,
        time_offset: selected_time_offset.value.value,
        time_window: selected_time_window.value.value,
        rest_params: new_params
    });
    modal_id.value.close();
};

/* **************************************************************************** */

defineExpose({ show });
</script>
  