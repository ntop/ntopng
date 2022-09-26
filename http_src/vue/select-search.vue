<template>
<select class="select2 form-select" ref="select2" required name="filter_type" >
  <option v-for="(item, i) in options_2" :selected="selected_option.label == item.label" :value="item">
    {{item.label}}
  </option>
  <optgroup v-for="(item, i) in groups_options_2" :label="item.group">
    <option v-for="(opt, j) in item.options" :selected="selected_option.label == opt.label" :value="opt">
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

const props = defineProps({
    id: String,
    options: Array,
    selected_option: Object,
    disable_change: Boolean,
});

watch(() => props.selected_option, (cur_value, old_value) => {
    console.log(`select-search: selected_options: ${cur_value.label}`);
    // selected2_option.value = cur_value;
});

let first_time_render = true;
let is_mounted = false;
watch(() => props.options, (current_value, old_value) => {    
    if (props.disable_change == true || is_mounted == false) { return; }

    console.log(`Watch select-search: ${props.id}, ${JSON.stringify(props.selected_option)}`);
    // setTimeout(() => render(), 100);
    render();
}, { flush: 'post'});

onMounted(() => {
    console.log("select-search:mounted");
    if (!props.disable_change) {
	render();
    }
    is_mounted = true;
});

function set_options() {
    options_2.value = [];
    groups_options_2.value = [];

    if (props.options == null) { return; }
    let groups_dict = {};
    props.options.forEach((option) => {
	if (option.group == null) {
	    options_2.value.push(option);
	} else {
	    if (groups_dict[option.group] == null) {
		groups_dict[option.group] = { group: option.group, options: [] };
	    }
	    groups_dict[option.group].options.push(option);
	}	
    });
    groups_options_2.value = ntopng_utility.object_to_array(groups_dict);

}

const render = () => {
    console.log(`select-search:render ${JSON.stringify(props.selected_option)}`);
    set_options();
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
	    if (value != props.selected_option) {
		console.log(`UPDATE SELECT_SEARCH \n${JSON.stringify(value)} ${JSON.stringify(props.selected_option)}`);
		emit('update:selected_option', value);
		emit('select_option', value);
	    }
	});
    }
    first_time_render = false;
    // this.$forceUpdate();
    // $(select2Div).val(props.selected_option);
};

defineExpose({ render });

function destroy() {
    console.log("Call destroy select-search");
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
