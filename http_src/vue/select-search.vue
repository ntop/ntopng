<template>
    <!-- Select2 wrapper component with Vue integration -->
    <div class="ss-root">
        <select class="select2 form-select ss-control" ref="select2" required name="filter_type" :multiple="multiple"
            :disabled="disabled">
            <!-- Render regular options (without groups) -->
            <option class="no-wrap  p-0" v-for="(item, i) in options_2" :selected="is_selected(item)" :value="item.value"
                :disabled="item.disabled" :data-icon="item.icon" :data-tooltip="item.tooltip" :data-color="item.color">
                {{ item.label }}
            </option>
            <!-- Render grouped options with optgroup elements -->
            <optgroup v-for="(item, i) in groups_options_2" :label="item.group">
                <option v-for="(opt, j) in item.options" :selected="is_selected(opt)" :value="opt.value"
                    :disabled="opt.disabled" :data-icon="item.icon" :data-tooltip="opt.tooltip" :data-color="opt.color">
                    {{ opt.label }}
                </option>
            </optgroup>
        </select>
    </div>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount, nextTick } from "vue";

/* *************************************************** */
/* Reactive references and state variables */
/* *************************************************** */

// Reference to the native select element for Select2 initialization
const select2 = ref(null);

// Define component events for parent communication
const emit = defineEmits(['update:selected_option', 'update:selected_options', 'select_option', 'unselect_option', 'change_selected_options']);

// Reactive state for internal option management
const options_2 = ref([]); // Regular options (without groups)
const groups_options_2 = ref([]); // Grouped options structure
const selected_option_2 = ref({}); // Currently selected option (single select mode)
const selected_values = ref([]); // Array of selected values (multiple select mode)
const refresh_options = ref(0); // Counter to trigger option re-rendering

/* *************************************************** */
/* Component props definition */
/* *************************************************** */

const props = defineProps({
    id: String,                    // Unique component identifier
    options: Array,                // Source options array from parent
    selected_option: Object,       // Currently selected option (single mode)
    selected_options: Array,       // Currently selected options (multiple mode)
    multiple: Boolean,             // Whether multiple selection is allowed
    add_tag: Boolean,              // Whether to allow adding custom tags
    disable_change: Boolean,       // Whether to disable automatic option updates
    theme: String,                 // Select2 theme (e.g., 'bootstrap-5')
    dropdown_size: String,         // Size variant for dropdown ('small' or default)
    disabled: Boolean              // Whether the select element is disabled
});

let first_time_render = true;      // Flag to track initial render state

/* *************************************************** */
/* Lifecycle hooks */
/* *************************************************** */

// Initialize component when mounted to DOM
onMounted(() => {
    if (!props.disable_change || !first_time_render) {
        set_input();  // Setup options and selection state
    }

});


/* *************************************************** */
/* Watchers for reactive prop changes */
/* *************************************************** */

// Watch for changes in selected_option prop (single select mode)
watch(() => props.selected_option, (cur_value, old_value) => {
    set_selected_option(cur_value);
    change_select_2_selected_value();  // Sync Select2 UI with new selection
}, { flush: 'pre' });

// Watch for changes in selected_options prop (multiple select mode)
watch(() => props.selected_options, (cur_value, old_value) => {
    set_selected_values(cur_value);
    change_select_2_selected_value();  // Sync Select2 UI with new selections
}, { flush: 'pre' });

// Watch for option refresh trigger and re-render when needed
watch([refresh_options], (cur_value, old_value) => {
    render();  // Re-initialize Select2 with updated options
}, { flush: 'post' });

// Watch for changes in the options prop from parent
watch(() => props.options, (current_value, old_value) => {
    if (props.disable_change == true || current_value == null) { return; }
    set_input();  // Reprocess options when they change
}, { flush: 'pre' });

/* *************************************************** */
/* Initialization functions */
/* *************************************************** */

/**
 * Initialize component with options and selection state.
 * This function orchestrates the complete setup process by calling:
 * 1. set_options() - processes and categorizes options
 * 2. set_selected_option() - sets single selection state
 * 3. set_selected_values() - sets multiple selection state
 */
function set_input() {
    set_options();           // Process raw options into internal structures
    set_selected_option();   // Initialize single selection state
    set_selected_values();   // Initialize multiple selection state
}

/* *************************************************** */
/* Option processing functions */
/* *************************************************** */

/**
 * Process raw options array and separate them into regular and grouped options.
 * This function performs several transformations:
 * 1. Creates a shallow copy of each option to avoid mutation
 * 2. Ensures each option has a value (uses label as fallback)
 * 3. Separates options based on the presence of 'group' property
 * 4. Groups options by their group property using a dictionary
 * 5. Converts the groups dictionary to an array format
 *
 * The resulting structure:
 * - options_2: Array of options without groups
 * - groups_options_2: Array of grouped options with structure {group: string, options: array}
 *
 * @throws Will skip processing if props.options is null
 * @sideeffect Updates options_2, groups_options_2, and increments refresh_options
 */
function set_options() {
    options_2.value = [];
    groups_options_2.value = [];

    if (props.options == null) { return; }
    let groups_dict = {};
    props.options.forEach((option) => {
        let opt_2 = { ...option };  // Create shallow copy to avoid mutation
        // Use label as value if value is not provided
        if (opt_2.value == null) {
            opt_2.value = opt_2.label;
        }
        // Separate options with groups from regular options
        if (option.group == null) {
            options_2.value.push(opt_2);  // Regular option (no group)
        } else {
            if (groups_dict[option.group] == null) {
                groups_dict[option.group] = { group: opt_2.group, options: [] };  // Initialize group
            }
            groups_dict[option.group].options.push(opt_2);  // Add option to group
        }
    });
    // Convert groups dictionary to array format for rendering
    groups_options_2.value = ntopng_utility.object_to_array(groups_dict);
    refresh_options.value += 1; // Trigger re-render
}

/* *************************************************** */
/* Select2 custom matcher for hierarchical search */
/* *************************************************** */

/**
 * Custom search matcher function for Select2 with hierarchical search support.
 * This function implements case-insensitive searching that works across nested option groups.
 *
 * Algorithm:
 * 1. Normalize search term and text to lowercase for case-insensitive comparison
 * 2. If no search term is provided, return all data (no filtering)
 * 3. Check if the parent item's text contains the search term
 * 4. If no match, recursively search through child items (for grouped options)
 * 5. If children match, return the parent with filtered children only
 * 6. Return null if neither parent nor children match
 *
 * @param {Object} params - Select2 search parameters
 * @param {string} params.term - The search term entered by the user
 * @param {Object} data - The option data object from Select2
 * @param {string} data.text - Display text of the option
 * @param {Array} [data.children] - Child options for grouped items
 * @returns {Object|null} - Modified data object with filtered children, original data, or null if no match
 *
 * @example
 * // Returns data unchanged
 * matchCustom({term: ''}, {text: 'Option 1'})
 *
 * // Returns data if text contains 'opt'
 * matchCustom({term: 'opt'}, {text: 'Option 1'})
 *
 * // Returns parent with filtered children
 * matchCustom({term: 'child'}, {text: 'Parent', children: [{text: 'Child 1'}, {text: 'Other'}]})
 */
function matchCustom(params, data) {
    // `params.term` should be the term that is used for searching
    // `data.text` is the text that is displayed for the data object
    // Searching with lower case, case insensitive
    const searchedString = params?.term?.toLowerCase()
    const text = data?.text?.toLowerCase()

    // If there are no search terms, return all of the data
    if (!searchedString?.trim()) {
        // Trim removes white spaces
        return data;
    }

    // Do not display the item if there is no 'text' property
    if (!text) {
        return null;
    }

    // Search for the string in the text
    if (text.indexOf(searchedString) > -1) {
        return data
    }

    // Now search the childs, in case of groups
    const filteredChildren = []
    data?.children?.forEach((child) => {
        const childText = child?.text?.toLowerCase()
        // Search for the string in the text
        if (childText && childText.indexOf(searchedString) > -1) {
            filteredChildren.push(child);
        }
    })

    if (filteredChildren.length > 0) {
        const modifiedParent = { ...data };
        modifiedParent.children = filteredChildren
        return modifiedParent;
    }

    // Return `null` if the term should not be displayed
    return null;
}

/* *************************************************** */
/* Select2 option formatting with icons */
/* *************************************************** */

/**
 * Format option display with optional icon.
 * This function enhances option rendering by adding icon support through Font Awesome or similar icon libraries.
 *
 * @param {Object} option - Select2 option object
 * @param {string} option.id - Option identifier
 * @param {string} option.text - Option display text
 * @param {HTMLElement} option.element - Original DOM element containing data-icon attribute
 * @returns {string|jQuery} - Formatted HTML string or jQuery object with icon if present
 */
// Format for dropdown list: show color swatch and/or icon before the text, with optional tooltip
const formatResult = (option) => {
    if (!option.id) {
        return option.text;  // Placeholder
    }

    const icon_class = option?.element?.dataset?.icon;
    const color = option?.element?.dataset?.color;
    const tooltip = option?.element?.dataset?.tooltip;

    if (!icon_class && !color && !tooltip) {
        return option.text;
    }

    const $inner = $('<span>').css({ display: 'inline-flex', alignItems: 'center' });

    if (color) {
        $('<span>').css({
            display: 'inline-block', width: '10px', height: '10px',
            borderRadius: '2px', backgroundColor: color,
            marginRight: '5px', verticalAlign: 'middle', flexShrink: 0,
        }).appendTo($inner);
    }

    if (icon_class) {
        $('<i>').addClass(icon_class).css('margin-right', '4px').appendTo($inner);
    }

    $inner.append(document.createTextNode(option.text));

    if (tooltip) {
        return $('<span>').attr({
            'data-bs-toggle': 'tooltip',
            'data-bs-placement': 'right',
            'data-bs-title': tooltip,
        }).css({ display: 'block', width: '100%' }).append($inner);
    }

    return $inner;
}

// Format for selected chip: plain text only — chip background is colored via apply_chip_colors()
const formatSelection = (option) => {
    if (!option.id) {
        return option.text;
    }

    const icon_class = option?.element?.dataset?.icon;
    if (!icon_class) {
        return option.text;
    }

    return $('<span>').append($('<i>').addClass(icon_class)).append('\u00a0' + option.text);
}

// After Select2 re-renders chips, set each chip's background/border to its option's data-color
function apply_chip_colors() {
    const select2Div = select2.value;
    if (!select2Div) return;
    $(select2Div).parent().find('.select2-selection__choice').each(function () {
        const chip = $(this);
        const title = chip.attr('title');
        const opt = $(select2Div).find('option').filter((_, el) => $(el).text().trim() === title).first();
        const color = opt.data('color');
        if (color) {
            chip.css({ 'background-color': color, 'border-color': color });
            chip.find('.select2-selection__choice__remove').css('color', '#fff');
        }
    });
}

/* *************************************************** */
/* Select2 initialization and rendering */
/* *************************************************** */

/**
 * Initialize or re-initialize the Select2 plugin with Vue integration.
 * This is the core rendering function that:
 * 1. Destroys existing Select2 instance if not first render
 * 2. Initializes Select2 with custom configuration
 * 3. Sets up event handlers for selection changes
 * 4. Synchronizes Vue state with Select2 state
 *
 * Configuration includes:
 * - Custom matcher for hierarchical search
 * - Theme customization
 * - Tagging support (when enabled)
 * - Size variants via CSS classes
 *
 * Event handling:
 * - select2:select: Handles both regular selections and custom tag creation
 * - select2:unselect: Manages removal from multiple selections
 *
 * @sideeffect Modifies DOM, sets up jQuery event listeners, updates first_time_render flag
 * @throws May throw if Select2 initialization fails or jQuery is not available
 */
const render = () => {
    let select2Div = select2.value;
    if (first_time_render == false) {
        destroy();  // Clean up existing Select2 instance
    }
    if (!$(select2Div).hasClass("select2-hidden-accessible")) {
        $(select2Div).select2({
            templateResult: formatResult,      // Custom rendering with icons/swatches in dropdown
            templateSelection: formatSelection, // Custom rendering for selected chip
            matcher: matchCustom,               // Hierarchical search matcher
            width: '100%',                       // Full width
            theme: props.theme ? props.theme : 'bootstrap-5',  // Theme (default to bootstrap-5)
            dropdownParent: $(select2Div).parent(),  // Parent container for dropdown
            dropdownAutoWidth: true,                   // Auto-adjust dropdown width
            tags: props.add_tag && !props.multiple,   // Enable tagging only in single mode
            selectionCssClass: props.dropdown_size == "small" ? 'select2--small' : '',  // Size variant
            dropdownCssClass: props.dropdown_size == "small" ? 'select2--small' : ''    // Size variant
        });

        // Handle option selection event
        $(select2Div).on('select2:select', function (e) {
            let data = e.params.data;
            if (data.element === null) {
                // Handle custom tag creation (no DOM element)
                //TODO: implement for multiselect
                let option = { label: data.text, value: data.id };
                emit('update:selected_option', option);
                emit('select_option', option);
                return;
            }
            let value = data.element._value;  // Get actual value from DOM element
            let option = find_option_from_value_or_label(value);  // Find original option object

            if (value !== props.selected_option) {
                emit('update:selected_option', option);
                emit('select_option', option);
            }

            if (!props.multiple) {
                return;  // Single select - done
            }

            // Update selected values for multiple select
            selected_values.value = selected_values.value.filter((v) => v != value);
            selected_values.value.push(value);
            let options = find_options_from_values(selected_values.value);
            emit('update:selected_options', options);
            emit('change_selected_options', options);
            apply_chip_colors();
        });

        // Handle option unselection event (multiple select only)
        $(select2Div).on('select2:unselect', function (e) {
            let data = e.params.data;
            let value = data.element._value;
            if (!props.multiple) {
                return;  // Unselect only relevant for multiple mode
            }
            selected_values.value = selected_values.value.filter((v) => v != value);
            let option = find_option_from_value_or_label(value);
            let options = find_options_from_values(selected_values.value);
            emit('unselect_option', option);
            emit('update:selected_options', options);
            emit('change_selected_options', options);
            apply_chip_colors();
        });
    }
    first_time_render = false;
    // this.$forceUpdate();
    change_select_2_selected_value();  // Sync initial selection
};

/* *************************************************** */
/* Select2-Vue synchronization functions */
/* *************************************************** */

/**
 * Synchronize Select2's displayed value with Vue's internal state.
 * This function ensures the Select2 UI reflects the current selection state.
 *
 * For single select mode:
 * - Extracts value from selected option object
 * - Sets Select2 value and triggers change event
 *
 * For multiple select mode:
 * - Uses the array of selected values
 * - Updates Select2 with all selected values
 *
 * @sideeffect Modifies Select2 DOM element value and triggers change events
 */
function change_select_2_selected_value() {
    let select2Div = select2.value;
    if (!props.multiple) {
        let value = get_value_from_selected_option(props.selected_option);
        $(select2Div).val(value);
        $(select2Div).trigger("change");
    } else {
        $(select2Div).val(selected_values.value);
        $(select2Div).trigger("change");
        apply_chip_colors();
    }
}

/* *************************************************** */
/* Selection state management */
/* *************************************************** */

/**
 * Determine if an option should be marked as selected in the rendered HTML.
 * This function handles the logic for both single and multiple selection modes.
 *
 * Single select logic:
 * 1. Compares option value with selected option value (strict equality)
 * 2. Special handling for zero values: also matches by label if value is 0 or "0"
 *
 * Multiple select logic:
 * 1. Checks if value exists in selected_values array
 * 2. Falls back to option's own 'selected' property
 *
 * @param {Object} item - The option object to check
 * @param {string|number} item.value - Option value
 * @param {string} item.label - Option display label
 * @param {boolean} [item.selected] - Optional pre-selected flag
 * @returns {boolean} - True if the option should be marked as selected
 */
function is_selected(item) {
    if (!props.multiple) {
        // Special handling for zero values to ensure proper matching
        const is_zero_value = selected_option_2.value.value == 0 || selected_option_2.value.value == "0";
        return item.value == selected_option_2.value.value || (is_zero_value && item.label == selected_option_2.value.label);
    }
    return selected_values.value.find((v) => v == item.value) != null || item.selected;
}

/**
 * Initialize selected values array from props for multiple select mode.
 * This function converts an array of option objects into an array of values.
 * Each option's value is extracted (with label as fallback) and added to selected_values.
 *
 * @sideeffect Updates selected_values reactive array
 * @note Only executes in multiple select mode and when selected_options is provided
 */
function set_selected_values() {
    if (props.selected_options == null || !props.multiple) {
        return;
    }
    selected_values.value = [];
    props.selected_options.forEach((opt) => {
        let value = opt.value || opt.label;  // Use label as fallback if value missing
        selected_values.value.push(value);
    });
}

/**
 * Set the internal selected option state for single select mode.
 * This function handles null/undefined cases by falling back to the first option
 * when no selection is provided and not in multiple select mode.
 *
 * @param {Object|null} selected_option - The option to select, or null for default
 * @sideeffect Updates selected_option_2 reactive reference
 */
function set_selected_option(selected_option) {
    if (selected_option == null && !props.multiple) {
        selected_option = get_props_selected_option();  // Fall back to default
    }
    selected_option_2.value = selected_option;
}

/**
 * Get the selected option from props with safe fallback logic.
 * This function provides a default selection when none is specified.
 *
 * @returns {Object} - The selected option from props, or the first option if none selected
 * @throws May return undefined if props.options is empty
 */
function get_props_selected_option() {
    if (props.selected_option == null) {
        return props.options[0];  // Default to first option
    }
    return props.selected_option;
}

/**
 * Extract the display value from a selected option object.
 * This function handles the optional nature of the 'value' property by using
 * label as a fallback when value is not provided.
 *
 * @param {Object|null} selected_option - The option object
 * @param {string|number} [selected_option.value] - Optional value property
 * @param {string} selected_option.label - Display label (used as fallback value)
 * @returns {string|number} - The value to use for Select2
 */
function get_value_from_selected_option(selected_option) {
    if (selected_option == null) {
        selected_option = get_props_selected_option();
    }
    let value;
    if (selected_option.value != null) {
        value = selected_option.value;
    } else {
        value = selected_option.label;  // Use label as fallback
    }
    return value;
}

/* *************************************************** */
/* Option lookup utility functions */
/* *************************************************** */

/**
 * Convert an array of string/number values to an array of full option objects.
 * This function maps each value through find_option_from_value_or_label to
 * retrieve the complete option object with all its properties.
 *
 * @param {Array<string|number>} values - Array of option values
 * @returns {Array<Object>} - Array of corresponding option objects
 */
function find_options_from_values(values) {
    let options = values.map((v) => find_option_from_value_or_label(v));
    return options;
}

/**
 * Find the original option object from the props.options array by value or label.
 * This function bridges between the internal processed options and the original
 * props to ensure event emissions contain the original option objects.
 *
 * Process:
 * 1. Finds the processed option in options_2 or groups_options_2
 * 2. Uses that option's value or label to locate the original in props.options
 *
 * @param {string|number} value - The value to search for
 * @returns {Object} - The original option object from props.options
 */
function find_option_from_value_or_label(value) {
    let option_2 = find_option_2_from_value(value);
    let option = props.options.find((o) => (o.value === option_2.value) || (o.label == option_2.label));
    return option;
}

/**
 * Find an option from the internal processed collections by its value.
 * This function searches through both regular and grouped options using
 * strict equality comparison (===) for accurate matching.
 *
 * Search order:
 * 1. Regular options (options_2)
 * 2. Grouped options (groups_options_2)
 *
 * @param {string|number} value - The value to search for
 * @returns {Object|null} - The found option object or null if not found
 */
function find_option_2_from_value(value) {
    if (value == null) {
        value = get_value_from_selected_option();
    }
    // Search regular options first
    let option = options_2.value.find((o) => o.value === value);
    if (option != null) { return option; }

    // Search in grouped options if not found in regular options
    for (let i = 0; i < groups_options_2.value.length; i += 1) {
        let g = groups_options_2.value[i];
        option = g.options.find((o) => o.value === value);
        if (option != null) {
            return option;
        }
    }
    return null;
}

/* *************************************************** */
/* Cleanup functions */
/* *************************************************** */

/**
 * Clean up Select2 instance and event listeners to prevent memory leaks.
 * This function safely destroys the Select2 plugin and removes all jQuery
 * event handlers attached to the element.
 *
 * Error handling:
 * - Wraps destruction in try-catch to prevent unmount errors
 * - Logs errors without throwing to avoid disrupting component lifecycle
 *
 * @sideeffect Removes Select2 from DOM, clears event listeners
 */
function destroy() {
    try {
        $(select2.value).select2('destroy');
        $(select2.value).off('select2:select');
    } catch (err) {
        console.error("Destroy select-search catch error:");
        console.error(err);
    }
}

// Lifecycle hook: Clean up before component unmounts
onBeforeUnmount(() => {
    destroy();  // Prevent memory leaks
});

// Expose render function to parent components for manual re-rendering
defineExpose({ render });

</script>

<style scoped>
/* Let options expand naturally */
.select2-results__options {
    width: max-content !important;
}

/* Let dropdown grow to fit content */
.select2-dropdown {
    width: auto !important;
    min-width: 100% !important;
}

/* Prevent wrapping so width reflects longest item */
.select2-results__option {
    white-space: nowrap;
}

.ss-root {
    width: 100%;
    position: relative;
}

.ss-root :deep(.select2-container) {
    width: 100% !important;
}


.ss-root :deep(.select2-container--bootstrap-5 .select2-selection) {
    background-color: var(--input-bg, #fff);
    border: 1px solid var(--input-border, #ced4da);
    color: var(--input-text, #495057);
    border-radius: 7px;
    font-size: 0.8rem;
    min-height: 34px;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.ss-root :deep(.select2-container--bootstrap-5.select2-container--focus .select2-selection),
.ss-root :deep(.select2-container--bootstrap-5.select2-container--open .select2-selection) {
    border-color: var(--ntop-orange, #FF8F00);
    box-shadow: 0 0 0 2px rgba(255, 143, 0, 0.18);
    outline: none;
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-selection--single) {
    display: flex !important;
    align-items: center !important;
    height: 34px;
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-selection--single .select2-selection__rendered) {
    line-height: 1 !important;
    padding-left: 0.55rem;
    padding-right: 1.5rem;
    font-size: 0.8rem;
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap !important;
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-selection--single .select2-selection__arrow) {
    height: 100% !important;
    top: 0 !important;
    right: 6px;
    display: flex;
    align-items: center;
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-dropdown) {
    background-color: var(--bg-surface, #fff);
    border: 1px solid rgba(0, 0, 0, 0.03);
    border-radius: 7px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    font-size: 0.8rem;
    overflow: hidden;
    padding: 0;
}

/* search */
.ss-root :deep(.select2-container--bootstrap-5 .select2-search--dropdown) {
    padding: 0.4rem 0.5rem;
    border-bottom: 1px solid var(--border-subtle, #e9ecef);
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-search__field) {
    border-radius: 5px;
    font-size: 0.8rem;
    padding: 0.2rem 0.5rem;
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-results__options) {
    padding: 0 !important;
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-results__option) {
    position: relative;
    border-radius: 6px;
    margin: 0;
    padding: 0.27rem 0.6rem 0.27rem 0.75rem;
    font-size: 0.8rem;
    background: transparent !important;
    color: var(--ntop-text-color, #111) !important;
}

.ss-root :deep(.select2-container--bootstrap-5 .select2-results__option::after) {
    content: '';
    position: absolute;
    left: 0;
    top: 0;
    height: 100%;
    width: 4px;
    border-radius: 2px;
    background-color: transparent;
}


.ss-root :deep(.select2-container--bootstrap-5
.select2-results__option--highlighted) {
    background: rgba(175, 184, 193, 0.20) !important;
}

/* kill pill on every hover — restore below for selected+hover */
.ss-root :deep(.select2-container--bootstrap-5
.select2-results__option--highlighted::after) {
    background-color: transparent !important;
}

.ss-root :deep(.select2-container--bootstrap-5
.select2-results__option--selected) {
    background: rgba(175, 184, 193, 0.20) !important;
}

.ss-root :deep(.select2-container--bootstrap-5
.select2-results__option--selected::after) {
    background-color: var(--ntop-orange, #FF8F00) !important;
}

.ss-root :deep(.select2-container--bootstrap-5
.select2-results__option--highlighted.select2-results__option--selected) {
    background: rgba(175, 184, 193, 0.20) !important;
}

.ss-root :deep(.select2-container--bootstrap-5
.select2-results__option--highlighted.select2-results__option--selected::after) {
    background-color: var(--ntop-orange, #FF8F00) !important;
}

.ss-root :deep(.select2-results__group) {
    font-size: 0.68rem;
    font-weight: 700;
    text-transform: uppercase;
    padding: 0.4rem 0.625rem 0.15rem;
}

.ss-root :deep(.select2-selection--multiple .select2-selection__choice) {
    border: none;
    color: #fff;
    border-radius: 4px;
    font-size: 0.75rem;
    padding: 0.1rem 0.45rem;
    margin: 2px;
}

.ss-root :deep(.select2-selection__choice__remove) {
    color: rgba(255, 255, 255, 0.7);
}

.ss-root :deep(.select2-selection__choice__remove:hover) {
    color: #fff;
}

.ss-root :deep(.select2--small .select2-selection--single) {
    height: 26px !important;
    min-height: 26px !important;
}

.ss-root :deep(.select2--small .select2-results__option) {
    font-size: 0.78rem;
    padding: 0.2rem 0.5rem;
}

.ss-root :deep(.select2-container--disabled .select2-selection) {
    background-color: var(--bg-sunken, #f1f3f5);
    cursor: not-allowed;
}

/* isolate native select */
select.ss-control {
    font-size: 0.8rem !important;
    height: 34px !important;
}
</style>
