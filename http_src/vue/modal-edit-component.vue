<!-- (C) 2023 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>{{ title }}</template>
        <template v-slot:body>
            
            <!-- Title -->
            <div class="form-group ms-2 me-2 mt-3 row">
                <label class="col-sm-1 mt-2">
                    {{ _i18n("dashboard.component_title") }}
                </label>
                <div class="col-sm-10">
                    <input v-model="component_title" class="form-control" type="text" required />
                </div>
            </div>

            <!-- Width -->
            <div class="form-group ms-2 me-2 mt-4 row">
                <label class="col-sm-1 mt-3">
                    {{ _i18n("dashboard.component_width") }}
                </label>
                <div class="col-sm-6 mt-2">
                    <input type="range" id="slider" v-model="width_selected" style="width:100%" list="steplist" min="1"
                        max="3" step="1">
                    <datalist class="datalist" id="steplist">
                        <option value="1" id="4" label="Small"></option>
                        <option value="2" id="6" label="Medium"></option>
                        <option value="3" id="12" label="Large"></option>
                    </datalist>
                </div>
            </div>
            
            <!-- Height -->
            <div class="form-group ms-2 me-2 mt-3 row">
                <label class="col-sm-1 mt-2">
                    {{ _i18n("dashboard.component_height") }}
                </label>
                <div class="col-sm-9 mt-2">
                    <input type="range" id="slider" v-model="height_selected" style="width:97%" list="steplist" min="1"
                        max="4" step="1">
                    <datalist class="datalist" id="steplist">
                        <option value="1" label="Small"></option>
                        <option value="2" label="Medium"></option>
                        <option value="3" label="Large"></option>
                        <option value="4" label="Auto"></option>
                    </datalist>
                </div>
            </div>

        </template>
        <template v-slot:footer>
            <div>
                <button type="button" @click="edit_" class="btn btn-primary">
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

/* Modal Ref Consts */
const component_title = ref(null);
const old_component_to_edit = ref(null);
const width_selected = ref(null);
const height_selected = ref(null);

/* **************************************************************************** */

/**
 * 
 *  @brief This method is called to reset the modal ref constants.
 *  */ 
const reset_modal_form = function () {
    component_title.value = "";
    old_component_to_edit.value = null;
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
    height_selected.value = convert_size_to_slider_value(old_component.height);
    width_selected.value = convert_size_to_slider_value(old_component.width);
    component_title.value = old_component.custom_name;
};

/* **************************************************************************** */

/**
 * 
 *  @brief This method is called whenever the modal is opened 
 *  @param old_component_to_edit selected component to edit
 *  */ 
const show = (old_component_to_edit) => {
    /* First of all reset all the data */
    reset_modal_form();
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
    console.log(width_selected);
    const new_width     = convert_slider_value_to_size(width_selected.value);
    const new_height    = convert_slider_value_to_size(height_selected.value);

    emit("edit", {
        id: old_component_to_edit.value.id,
        title: component_title.value,
        height: new_height,
        width: new_width,
    });
    modal_id.value.close();
};

/* **************************************************************************** */

defineExpose({ show });
</script>
  