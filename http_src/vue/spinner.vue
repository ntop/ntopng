<template>
<div v-if="show" class="spinner-border text-primary" :style="{'width': size, 'height': size}" role="status">
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";

const props = defineProps({
    size: String,
    show: Boolean,
});

onMounted(async () => {
});

</script>
