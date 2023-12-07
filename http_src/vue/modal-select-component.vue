<!-- (C) 2023 ntop -->
<template>
<modal @showed="showed()" ref="modal_id">
	<template v-slot:title>
	{{ title }}
	</template>

	<template v-slot:body>
	<div class="form-group ms-2 me-2 mt-3 row" style="overflow-y: scroll; height: 45vh">
		<template v-for="c in components">
		<div class="card w-100 wizard-card" :class="{ 'wizard-selected': selected_component == c }">
			<a class="wizard-link" href="#" @click="selected_component = c; onModalChange()">
				<div class="card-body">
					<div class="form-group wizard-form-group">
						<h5><i :class="get_component_type_icon(c.component)"></i> {{_i18n(c.i18n_name)}}</h5>
						<small class="form-text text-muted">{{_i18n(c.i18n_descr)}}</small>
					</div>
				</div>
			</a>
		</div>
		</template>
	</div>
	</template><!-- modal-body -->
  
	<template v-slot:footer>
	</template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";

const modal_id = ref(null);
const showed = () => {};
const selected_component = ref({});
const components = ref([]);
const order_by = ref("date"); // name / date

const props = defineProps({
    csrf: String,
    title: String,
    list_components: Function,
    add_component: Function
});

const emit = defineEmits([]);

const show = () => {
    init();
    modal_id.value.show();
};

async function init() {
    components.value = await props.list_components();
    if (components.value.length > 0) {
        selected_component.value = components.value[0];
    }
}

function get_component_type_icon(component_type) {
    switch (component_type) {
      case 'pie':
        return "fa-solid fa-chart-pie";
      case 'table':
        return "fa-solid fa-table";
      case 'timeseries':
        return "fa-solid fa-chart-line";
      default:
        return "";
    }
}

function onModalChange(e) {
    close();
    props.add_component(selected_component.value);
}

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close });

onMounted(() => {
});

const _i18n = (t) => i18n(t);

</script>

<style scoped>
input:invalid {
  border-color: #ff0000;
}
.not-allowed {
  cursor: not-allowed;
}
</style>
