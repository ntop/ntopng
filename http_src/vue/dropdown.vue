<!-- (C) 2022 - ntop.org     -->
<!-- Usage: -->
<!--   <Dropdown :id="id" ref="dropdown"> <\!-- Dropdown columns -\-> -->
<!--     <template v-slot:title> -->
<!--       <i class="fas fa-eye"></i> -->
<!--     </template> -->
<!--     <template v-slot:menu> -->
<!--       <div v-for="col in columns_wrap" class="form-check form-switch"><input class="form-check-input" checked="" type="checkbox" id="toggle-Begin"> -->
<!--         <label class="form-check-label" for="toggle-Begin" v-html="print_html_column(col.data)"> -->
<!--         </label> -->
<!--       </div> -->
<!--     </template> -->
<!--   </Dropdown> <\!-- Dropdown columns -\-> -->

<template>
<div class="dropdown" ref="dropdown" style="display:inline-block;">
  <button class="btn btn-sm dropdown-toggle" :class="button_class_2" type="button" :id="id" ref="dropdown_button"  @click="open_close" aria-expanded="false" data-bs-toggle="dropdown">
    <slot name="title"></slot>
  </button>
  <ul class="dropdown-menu" :aria-labelledby="id" style=" max-height: 20rem">
    <!-- <slot name="menu"></slot> -->    
    <li class="dropdown-item" v-for="(opt, i) in options" :ref="el => { menu[i] = el }"></li>
  </ul>
</div>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { useSlots, render, getCurrentInstance, nextTick } from 'vue';
import { render_component } from "./ntop_utils.js";

const instance = getCurrentInstance();
const slots = useSlots();

const options = ref([]);
const menu = ref([]);
const dropdown = ref(null);
const dropdown_button = ref(null);

const props = defineProps({
    id: String,
    auto_load: Boolean,
    button_class: String,
});

let default_overflow = null;
onMounted(() => {
    default_overflow = 	$(dropdown.value).parent().closest('div').css('overflow');
    if (props.auto_load == true) {
	run_f(() => load_menu());
    }
});

const button_class_2 = computed(() => {
    if (props.button_class != null) { return props.button_class; }
    return "btn-link";
})

function run_f(f) {
    f();
}

function open_close() {
    if (!$(dropdown.value).find('.dropdown-menu').is(":hidden")){
	$(dropdown_button.value).dropdown('hide');
	$(dropdown.value).parent().closest('div').css('overflow', "visible");
	$(dropdown_button.value).dropdown('show');
    } else {
	$(dropdown.value).parent().closest('div').css('overflow', default_overflow);
    }
}

function load_menu() {
    options.value = [];
    if (slots == null || slots.menu == null) { return; }
    let menu_options = slots.menu();
    if (menu_options == null || menu_options.length == 0) { return; }
    menu_options.forEach((opt_slot) => {
	let node = opt_slot;
	let element = $("<div></div>")[0];
	const { vNode, el } = render_component(node, { app:  instance?.appContext?.app, element });
	options.value.push(el);
    });
    nextTick(() => {
	options.value.forEach((opt, i) => {
	    let html_element = menu.value[i];
	    $(html_element).append(opt);
	});
    });
}

defineExpose({ load_menu });

</script>
