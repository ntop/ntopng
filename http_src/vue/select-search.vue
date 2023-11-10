<template>
  <select class="select2 form-select" ref="select2" required name="filter_type" :multiple="multiple">
    <option class="ntopng-dropdown-min-width no-wrap" v-for="(item, i) in options_2" :selected="is_item_selected(item)" :value="item.value" :disabled="item.disabled">
      {{item.label}}
    </option>
    <optgroup v-for="(item, i) in groups_options_2" :label="item.group">
      <option v-for="(opt, j) in item.options" :selected="is_item_selected(opt)" :value="opt.value" :disabled="opt.disabled">
        {{opt.label}}
      </option>
    </optgroup>
  </select>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount } from "vue";

const select2 = ref(null);

// const selected2_option = ref({});

const emit = defineEmits(['update:selected_option', 'select_option', 'unselect_option', 'change_selected_options']);

const options_2 = ref([]);
const groups_options_2 = ref([]);
const selected_option_2 = ref({});
const selected_values = ref([]); // used only if multiple == true
const refresh_options = ref(0);

const props = defineProps({
    id: String,
    options: Array,
    selected_option: Object,
    multiple: Boolean,
    add_tag: Boolean,
    disable_change: Boolean,
});

let first_time_render = true;

onMounted(() => {
    if (!props.options) { return; }
    if (!props.disable_change || !first_time_render) {
    	set_input();
    }
});

watch(() => props.selected_option, (cur_value, old_value) => {
    set_selected_option(cur_value);
    let select2Div = select2.value;
    change_select_2_selected_value();
}, { flush: 'pre'});

watch([refresh_options], (cur_value, old_value) => {
    render();
}, { flush: 'post'});


watch(() => props.options, (current_value, old_value) => {
    if (props.disable_change == true || current_value == null) { return; }
    set_input();
}, { flush: 'pre'});

function set_input() {
    set_options();
    set_selected_option();
}

function set_options() {
    options_2.value = [];
    groups_options_2.value = [];
    
    if (props.options == null) { return; }
    let groups_dict = {};
    props.options.forEach((option) => {
	let opt_2 = { ...option };
	if (opt_2.value == null) {
	    opt_2.value = opt_2.label;
	}
	if (option.group == null) {
	    options_2.value.push(opt_2);
	} else {
	    if (groups_dict[option.group] == null) {
		groups_dict[option.group] = { group: opt_2.group, options: [] };
	    }
	    groups_dict[option.group].options.push(opt_2);
	}
    });
    groups_options_2.value = ntopng_utility.object_to_array(groups_dict);
    refresh_options.value += 1;
}


const render = () => {
    let select2Div = select2.value;
    if (first_time_render == false) {
	destroy();
    }
    if (!$(select2Div).hasClass("select2-hidden-accessible")) {
	$(select2Div).select2({
	    width: '100%',
	    height: '500px',
	    theme: 'bootstrap-5',
	    dropdownParent: $(select2Div).parent(),
	    dropdownAutoWidth : true,
            tags: props.add_tag && !props.multiple,
	});
	$(select2Div).on('select2:select', function (e) {
	    let data = e.params.data;
            if (data.element == null) {
                //TODO: implement for multiselect
                let option = { label: data.text, value: data.id };
		emit('update:selected_option', option);
		emit('select_option', option);
            } else {
	        let value = data.element._value;
	        let option = find_option_from_value(value);
	        if (value != props.selected_option) {
		    emit('update:selected_option', option);
		    emit('select_option', option);
	        }
            }
	    if (!props.multiple) {
		return;
	    }
	    selected_values.value = selected_values.value.filter((v) => v != value);
	    selected_values.value.push(value);
	    let options = find_options_from_values(selected_values.value);
	    emit('change_selected_options', options);		 
	});
	$(select2Div).on('select2:unselect', function (e) {
	    let data = e.params.data;
	    let value = data.element._value;
	    if (!props.multiple) {
		return;
	    }
	    selected_values.value = selected_values.value.filter((v) => v != value);
	    let option = find_option_from_value(value);
	    let options = find_options_from_values(selected_values.value);
	    emit('unselect_option', option);
	    emit('change_selected_options', options);		 
	});
    }
    first_time_render = false;
    // this.$forceUpdate();
    change_select_2_selected_value();
};

function change_select_2_selected_value() {
    let select2Div = select2.value;
    if (!props.multiple) {
	let value = get_value_from_selected_option(props.selected_option);
	$(select2Div).val(value);
	$(select2Div).trigger("change");
    } else {
	$(select2Div).val(selected_values.value);
	$(select2Div).trigger("change");
    }
}

function is_item_selected(item) {
    if (!props.multiple) {
	const is_zero_value = selected_option_2.value.value == 0 ||selected_option_2.value.value == "0";
	return item.value == selected_option_2.value.value || (is_zero_value && item.label == selected_option_2.value.label);
    }
    return selected_values.value.find((v) => v == item.value) != null; 
}

function set_selected_option(selected_option) {
    if (selected_option == null && !props.multiple) {
	selected_option = get_props_selected_option();
    }
    selected_option_2.value = selected_option;
    // if (props.multiple == true && selected_option_2.value?.value != null) {
    // 	selected_values.value.push(selected_option_2.value.value);
    // }
}

function get_props_selected_option() {
    if (props.selected_option == null) {
	return props.options[0];
    }
    return props.selected_option;
}

function get_value_from_selected_option(selected_option) {
    if (selected_option == null) {
	selected_option = get_props_selected_option();
    }
    let value;
    if (selected_option.value != null) {
	value = selected_option.value;
    } else {
	value = selected_option.label;
    }
    return value;
}

function find_options_from_values(values) {
    let options = values.map((v) => find_option_from_value(v));
    return options;
}

function find_option_from_value(value) {
    let option_2 = find_option_2_from_value(value);
    let option = props.options.find((o) => o.label == option_2.label);
    return option;
}

function find_option_2_from_value(value) {
    if (value == null) {
	value = get_value_from_selected_option();
    }
    // let option = options_2.value.find((o) => o.value == value);
    let option = options_2.value.find((o) => o.value == value);
    if (option != null) { return option; }
    for (let i = 0; i < groups_options_2.value.length; i += 1) {
	let g = groups_options_2.value[i];
	option = g.options.find((o) => o.value == value);
	if (option != null) {
	    return option;
	}
    }
    return null;
}
    
defineExpose({ render });

function destroy() {
    try {
	$(select2.value).select2('destroy');
	$(select2.value).off('select2:select');    
    } catch(err) {
	console.error("Destroy select-search catch error:");
	console.error(err);
    }
}

onBeforeUnmount(() => {
    destroy();
});

</script>
