<template>
<select class="select2 form-select" ref="select2" v-model="selected_option" required name="filter_type">
  <option v-for="item in options" :value="item">
    {{item.label}}
  </option>	  
</select>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";

const select2 = ref(null);

const emit = defineEmits(['update:selected_option', 'select_option']);

const props = defineProps({
    options: Array,
    selected_option: Object,
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
	    emit('update:selected_option', data.element._value);
	    emit('select_option', data.element._value);
	});
    }    
};

defineExpose({ init });

</script>
