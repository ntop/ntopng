<!-- (C) 2022 - ntop.org     -->
<template>

<!-- PerPage -->
<div class="row" style="margin-left:-2px;margin-right:-2px;margin-top:1rem;margin-bottom:-1rem;">
  <!-- div col-md-5 -->
  <div class="col-sm-12 col-md-5">
    <div class="dataTables_info" role="status" aria-live="polite">{{text}}
    </div>
  </div> <!-- div col-md-5 -->
  
  <!-- start div col-sm-12 -->
  <div v-show="total_pages > 0" class="col-sm-12 col-md-7">
    <div class="dataTables_paginate paging_simple_numbers" style="display:flex; justify-content:flex-end;">
      <ul class="pagination">
	<li v-show="enable_first_page" class="paginate_button page-item previous">
	  <a href="javascript:void(0);" @click="change_active_page(0, 0)" aria-controls="default-datatable" data-dt-idx="0" tabindex="0" class="page-link">
	    «
	  </a>
	</li>
	<li class="paginate_button page-item previous" :class="{ 'disabled': active_page == 0}">
	  <a href="javascript:void(0);" @click="back_page()" aria-controls="default-datatable" data-dt-idx="0" tabindex="0" class="page-link">
	    &lt;
	  </a>
	</li>
	<li v-for="n in num_page_buttons" @click="change_active_page(start_page_button + n - 1)" :class="{'active': active_page == start_page_button + n - 1 }" class="paginate_button page-item"><a href="javascript:void(0);" aria-controls="default-datatable" data-dt-idx="1" tabindex="0" class="page-link" >{{start_page_button + n}}</a>
	  <!--  :key="total_rows"-->
	  </li>
	<li class="paginate_button page-item next" :class="{ 'disabled': active_page == total_pages - 1}" id="default-datatable_next">
	  <a href="javascript:void(0);" @click="next_page()" aria-controls="default-datatable" data-dt-idx="7" tabindex="0" class="page-link">
	    &gt;
	  </a>
	</li>
	<li v-show="enable_last_page" class="paginate_button page-item previous">
	  <a href="javascript:void(0);" @click="change_active_page(total_pages - 1, total_pages - num_page_buttons)" aria-controls="default-datatable" data-dt-idx="0" tabindex="0" class="page-link">
	    »
	  </a>
	</li>
      </ul>
    </div>
  </div> <!-- end div col-md-7 -->
</div> <!-- PerPage -->

</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount } from "vue";

const props = defineProps({
    total_rows: Number,
    per_page: Number,
});

const emit = defineEmits(['change_active_page']);

const default_per_page = 10;
const max_page_buttons = 6;

const start_page_button = ref(0);
const num_page_buttons = ref(0);

const total_pages = ref(0);
const active_page = ref(0);

const text_template = "Showing page %active_page of %total_pages: total %total_rows rows";
const text = ref("");

onMounted(() => {
    calculate_pages();
});

watch(() => [props.total_rows, props.per_page], (cur_value, old_value) => {
    calculate_pages();
}, { flush: 'pre'});

function calculate_pages() {
    if (props.total_rows == null) { return; }
    let per_page = props.per_page;
    total_pages.value = Number.parseInt((props.total_rows + per_page - 1) / per_page);
    if (active_page.value >= total_pages.value && total_pages.value > 0) {
	active_page.value = total_pages.value - 1;
    }

    num_page_buttons.value = max_page_buttons;
    start_page_button.value = 0;
    if (total_pages.value < num_page_buttons.value) {
	num_page_buttons.value = total_pages.value;
    }
    set_text();
}

const enable_first_page = computed(() => {
    if (total_pages.value < max_page_buttons) {
	return false;
    }
    return active_page.value >= num_page_buttons.value - 1;
});

const enable_last_page = computed(() => {
    if (total_pages.value < max_page_buttons) {
	return false;
    }
    return active_page.value < total_pages.value - num_page_buttons.value + 1;
});


function next_page() {
    change_active_page(active_page.value + 1);
}

function back_page() {
    change_active_page(active_page.value - 1);
}

function change_active_page(new_active_page, new_start_page_button) {
    active_page.value = new_active_page;
    // console.log(`new active page: ${new_active_page}`);
    // console.log(`new start page button: ${new_start_page_button}`);

    if (new_start_page_button != null) {
	start_page_button.value = new_start_page_button;
    }
    if (active_page.value == start_page_button.value && start_page_button.value > 0) {
	start_page_button.value -= 1;
    }

    let end_page_button = start_page_button.value + num_page_buttons.value - 1;
    if (active_page.value == end_page_button && total_pages.value - 1 > end_page_button) {
	start_page_button.value += 1;	
    }
    // console.log(`active page: ${active_page.value}`);
    // console.log(`start page button: ${start_page_button.value}`);
    set_text();
    emit('change_active_page', active_page.value);
}

function set_text() {
    text.value = text_template.replace("%active_page", format_number(`${active_page.value + 1}`))
	.replace("%total_pages", format_number(`${total_pages.value}`))
	.replace("%total_rows", format_number(`${props.total_rows}`))
	.replace("%per_page", format_number(`${props.per_page}`))
	;
    // console.log(text.value);
    // console.log(active_page.value);
}

function format_number(s) {
    return s.replace(/(.)(?=(\d{3})+$)/g,'$1,');
}

</script>

<style scoped>
</style>
