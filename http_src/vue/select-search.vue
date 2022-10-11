<template>
<select class="select2 form-select" ref="select2" required name="filter_type" >
  <option v-for="(item, i) in options_2" :selected="(item.value == selected_option_2.value)" :value="item.value" :disabled="item.disabled">
    {{item.label}}
  </option>
  <optgroup v-for="(item, i) in groups_options_2" :label="item.group">
    <option v-for="(opt, j) in item.options" :selected="(item.value == selected_option_2.value)" :value="opt.value" :disabled="opt.disabled">
      {{opt.label}}
    </option>
  </optgroup>
</select>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount } from "vue";

const select2 = ref(null);

// const selected2_option = ref({});

const emit = defineEmits(['update:selected_option', 'select_option']);

const options_2 = ref([]);
const groups_options_2 = ref([]);
const selected_option_2 = ref({});

const props = defineProps({
    id: String,
    options: Array,
    selected_option: Object,
    disable_change: Boolean,
});

function get_props_selected_option() {
    if (props.selected_option == null) {
	return props.options[0];
    }
    return props.selected_option;
}

function set_selected_option(selected_option) {
    if (selected_option == null) {
	selected_option = get_props_selected_option();
    }
    selected_option_2.value = selected_option;
    if (selected_option_2.value.value == null) {
	selected_option_2.value.value = selected_option.label;
    }
}

watch(() => props.selected_option, (cur_value, old_value) => {
    set_selected_option(cur_value);
    let select2Div = select2.value;
    let value = get_value_from_selected_option(cur_value);
	$(select2Div).val(value)
	$(select2Div).trigger("change");
    // }
}, { flush: 'pre'});

function get_value_from_selected_option(selected_option) {
    if (selected_option == null) {
	selected_option = get_props_selected_option();
    }
    let value;
    if (selected_option.value) {
	value = selected_option.value;
    } else {
	value = selected_option.label;
    }
    return value;
}

function find_option_from_value(value) {
    if (value == null) {
	value = get_value_from_selected_option();
    }
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

let first_time_render = true;

watch(() => props.options, (current_value, old_value) => {    
    if (props.disable_change == true) { return; }    
    set_input();
}, { flush: 'pre'});

onMounted(() => {
    if (!props.disable_change || !first_time_render) {
    	set_input();
    }
});

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
    
}

watch([options_2, groups_options_2], (cur_value, old_value) => {
    render();
}, { flush: 'post'});

function set_input() {
    set_options();
    set_selected_option();
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
	    dropdownAutoWidth : true
	});
	$(select2Div).on('select2:select', function (e) {
	    let data = e.params.data;
	    let value = data.element._value;
	    let option = find_option_from_value(value);
	    if (value != props.selected_option) {
		// emit('update:selected_option', value);
		// emit('select_option', value);
		emit('update:selected_option', option);
		emit('select_option', option);
	    }
	});
    }
    first_time_render = false;
    // this.$forceUpdate();
    // $(select2Div).val(props.selected_option);
};

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
