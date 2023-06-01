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
  <button class="btn dropdown-toggle" :class="button_class_2" type="button" :id="id" ref="dropdown_button"  aria-expanded="false" data-bs-toggle="dropdown">
    <slot name="title"></slot>
  </button>
  <ul class="dropdown-menu" :aria-labelledby="id" style=" max-height: 25rem;overflow:auto">
    <!-- <slot name="menu"></slot> -->

    <!-- <li class="dropdown-item" v-for="(opt, i) in options" :ref="el => { menu[i] = el }"> -->
    <!--   asd -->
      <!--   </li> -->
      <li v-for="(opt, i) in menu_options" class="dropdown-item">
	<VNode :content="opt"></VNode>
      </li>
  </ul>
</div>
</template>

<script setup>
import { ref, onMounted, computed, watch, h } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { useSlots, render, getCurrentInstance, nextTick } from 'vue';
import { render_component } from "./ntop_utils.js";
import { default as VNode } from "./vue_node.vue";

const instance = getCurrentInstance();
const slots = useSlots();

const options = ref([]);
const menu = ref([]);
const menu_options = ref([]);
const dropdown = ref(null);
const dropdown_button = ref(null);

const emit = defineEmits([])

const props = defineProps({
    id: String,
    auto_load: Boolean,
    button_class: String,
    f_on_open: Function,
    f_on_close: Function,
});

let default_overflow = null;
onMounted(() => {
    default_overflow = 	$(dropdown.value).parent().closest('div').css('overflow');
    if (props.auto_load == true) {
	load_menu();
    }
    let el = { dropdown: dropdown.value, dropdown_button: dropdown_button.value };
    $(dropdown.value).on('show.bs.dropdown', function () {
	$(dropdown.value).parent().closest('div').css('overflow', "visible");
	if (props.f_on_open != null) {
	    props.f_on_open(el);
	}
    });
    $(dropdown.value).on('hide.bs.dropdown', function () {
	$(dropdown.value).parent().closest('div').css('overflow', default_overflow);
	if (props.f_on_close != null) {
	    props.f_on_close(el);
	}
    });
});

const button_class_2 = computed(() => {
    if (props.button_class != null) { return props.button_class; }
    return "btn-link";
})

function open_close() {
    // let el = { dropdown: dropdown.value, dropdown_button: dropdown_button.value };
    // if (!$(dropdown.value).find('.dropdown-menu').is(":hidden")){
    // 	$(dropdown_button.value).dropdown('hide');
    // 	$(dropdown.value).parent().closest('div').css('overflow', "visible");
    // 	$(dropdown_button.value).dropdown('show');
    // 	if (props.f_on_open != null) {
    // 	    props.f_on_open(el);
    // 	}
    // } else {
    // 	$(dropdown.value).parent().closest('div').css('overflow', default_overflow);
    // 	// emit('close', el);
    // }
}

async function load_menu() {
    options.value = [];
    if (slots == null || slots.menu == null) { return; }
    let m_options = slots.menu();
    if (m_options == null || m_options.length == 0) { return; }
    if (typeof m_options[0].type === 'symbol') {
	m_options = m_options[0].children;
    }
    menu_options.value = [];
    m_options.forEach((opt_slot) => {
	let node = opt_slot;
	menu_options.value.push(node);
	// let element = $("<div></div>")[0];
	// const { vNode, el } = render_component(node, { app:  instance?.appContext?.app, element });
	// options.value.push(el);
    });
    await nextTick();
    // nextTick(() => {
    // 	options.value.forEach((opt, i) => {
    // 	    let html_element = menu.value[i];
    // 	    $(html_element).append(opt);
    // 	});
    // });
}

defineExpose({ load_menu });

</script>
