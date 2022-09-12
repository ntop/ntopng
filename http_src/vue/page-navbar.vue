<template>
<nav class="navbar navbar-shadow navbar-expand-lg navbar-light bg-light px-2 mb-2">
  <span class="me-1 text-nowrap" style="font-size: 1.1rem;">
    <i :class="main_icon"></i>
    {{main_title}}
    <a :href="a_first_title_href" >{{a_first_title_label}}</a>
    {{a_second_title}}
  </span>
  <span class="text-muted ms-1 d-none d-lg-inline d-md-none">|</span>
  <button class="navbar-toggler" type="button">
    <span class="navbar-toggler-icon"></span>
  </button>
  <div class="collapse navbar-collapse scroll-x" id="navbarNav">
    <ul class="navbar-nav">
      <template v-for="item in items_table">
	<template v-if="item.active">
	  <li  @click="this.$emit('click_item', item)" :class="{ 'active': item.active }" class="nav-item nav-link">
	    <span v-if="item.badge_num > 0" class="badge rounded-pill bg-dark" style="float:right;margin-bottom:-10px;">{{ item.badge_num }}</span>
	    <b><i :class="item.icon"></i>
	      {{item.label}}
	    </b>
	  </li>
	</template>
	<template v-else>
	  <a @click="this.$emit('click_item', item)" href="#" class="nav-item nav-link">
	    <span v-if="item.badge_num > 0" class="badge rounded-pill bg-dark" style="float:right;margin-bottom:-10px;">{{ item.badge_num }}</span>
	    <i :class="item.icon"></i>
	      {{item.label}}
	  </a>
	</template>
	
	
      </template>
      </ul>
      <ul class="navbar-nav ms-auto">
        <a href="javascript:history.back()" class="nav-item nav-link text-muted">
          <i class="fas fa-arrow-left"></i>
	</a>
        <a target="_newtab" :href="help_link" class="nav-item nav-link text-muted">
          <i class="fas fa-question-circle"></i>
        </a>
      </ul>
    </div>
  </nav>
</template>

<script>
import { defineComponent } from 'vue';
export default defineComponent({
    components: {
    },
    props: {
	id: String,
	main_title: String,
	main_icon: String,
	help_link: String,
	items_table: Array,
  a_first_title_href: String,
  a_first_title_label: String,
  a_second_title: String,
    },
    emits: ["click_item"],
    /** This method is the first method of the component called, it's called before html template creation. */
    created() {
      },
    data() {
	return {
	    //i18n: (t) => i18n(t),
	};
    },
    /** This method is the first method called after html template creation. */
    mounted() {
	ntopng_sync.ready(this.$props["id"]);
    },
    methods: {
    },
});
</script>
