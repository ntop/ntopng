<template>
<select class="select2 form-select" ref="select2" required name="filter_type">
  <option v-for="item in options" :value="item">
    {{item.label}}
  </option>	  
</select>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount } from "vue";

const select2 = ref(null);

const emit = defineEmits(['update:selected_option', 'select_option']);

const props = defineProps({
    options: Array,
    selected_option: Object,
    init: Boolean,
});

onMounted(() => {
    if (props.init) {
	init();
    }
});

const init = () => {
    let select2Div = select2.value;
    if (!$(select2Div).hasClass("select2-hidden-accessible")) {
	$(select2Div).select2({
	    width: '100%',
	    theme: 'bootstrap-5',
	    dropdownParent: $(select2Div).parent(),
	});
	$(select2Div).on('select2:select', function (e) {
	    let data = e.params.data;
	    let value = data.element._value;
	    emit('update:selected_option', value);
	    emit('select_option', value);
	});
    }
    // console.log("PROPS SELECTED OPTION");
    // console.log(props.selected_option);
    // $(select2Div).val(props.selected_option).trigger('change')
};

defineExpose({ init });

onBeforeUnmount(() => {
    $(select2.value).select2('destroy');
});

</script>
