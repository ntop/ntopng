<template>
  <div class="form-check form-switch ms-1" style="white-space:nowrap">
    <input class="form-check-input" style="cursor:pointer;" :checked="value_2 == true" @click="change_value()"   type="checkbox" id="toggle-Begin">
    <label class="form-check-label" for="toggle-Begin" v-html="label">
    </label>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, watch, h } from "vue";

const emit = defineEmits(['update:value', 'change_value']);

const props = defineProps({
    checked: Boolean,
    label: String,
    change_label_side: Boolean,
});

const value_2 = ref(false);

watch(() => props.value, (cur_value, old_value) => {
    value_2.value = props.value;
}, { flush: 'pre'});

function change_value() {
    value_2.value = !value_2.value;
    emit('update:value', value_2.value);
    emit('change_value', value_2.value);
}

</script>

<style scoped>
</style>
