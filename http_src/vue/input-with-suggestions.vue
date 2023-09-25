<template>
  <input :pattern="pattern" list="OptionList" name="value" type="text" class="form-control" @change="update_input_value">
  <datalist id="OptionList" ref="datalist">
    <template v-for="option in option_list">
      <option :value="option.value">{{ option.label }}</option>
    </template>
  </datalist>
</template>

<script setup>
const emit = defineEmits(['input_changed']);

const props = defineProps({
  pattern: String,
  option_list: Array,
});

const update_input_value = function(value) {
  emit('input_changed', value.srcElement.value);
};
</script>