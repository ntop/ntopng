{#
  (C) 2022 - ntop.org
  This template is used by the `Service Map` page inside the `Hosts` menu.    
#}

<template>
  <div class="card-header mb-2">
    <ul class="nav nav-tabs card-header-tabs" role="tablist">
      <template v-for="tab in tab_list">
	      <template v-if="tab.active">
	        <li  @click="this.$emit('click_item', tab)" :class="{ 'active': tab.active }" class="nav-item nav-link">
            {{ tab.title }}
          </li>
	      </template>
	      <template v-else>
	        <a @click="this.$emit('click_item', tab)" href="#" class="nav-item nav-link">
	          {{ tab.title }}
	        </a>
	      </template>
      </template>
    </ul>
  </div>
</template>

<script>
import { defineComponent } from 'vue';

export default defineComponent({
  components: {
  },
  props: {
    id: String,
    tab_list: Array,
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
