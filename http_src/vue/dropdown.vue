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
<div class="dropdown" style="display:inline-block;">
  <button class="btn btn-link dropdown-toggle" type="button" id="id" data-bs-toggle="dropdown" aria-expanded="false">
    <slot name="title"></slot>
  </button>
  <ul class="dropdown-menu" aria-labelledby="id" style="overflow:auto; max-height: 20rem;">
    <!-- <slot name="menu"></slot> -->    
    <li v-for="(opt, i) in options" :ref="el => { menu[i] = el }"></li>
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

const props = defineProps({
    id: String,
});

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
