<template>
<nav class="navbar navbar-shadow navbar-expand-lg navbar-light bg-light px-2 mb-2">
  <span class="me-1 text-nowrap" style="font-size: 1.1rem;">
    <i :class="main_title.icon"></i>
    <a v-if="main_title.href" :href="main_title.href" :title="main_title.title"> {{main_title.label}}</a>  
    <span v-else :title="main_title.title"> {{main_title.label}}</span>    
    <template v-for="item in secondary_title_list"> / 
      <a v-if="item.href" :href="item.href" :title="item.title">{{item.label}}</a>  
      <span v-else :title="item.title">{{item.label}}</span>
    </template>
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
	main_title: Object,
  secondary_title_list: Array,
	help_link: String,
	items_table: Array,
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
