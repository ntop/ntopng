{#
  (C) 2022 - ntop.org
  This template is used by the `Service Map` page inside the `Hosts` menu.    
#}

{
  
}
<template>
  <div class="dropdown<">
    <button class="btn btn-link dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
      {{ active_element.label }} <i :class="(filter_icon || '')"></i>
    </button> 
    <div class="dropdown-menu dropdown-menu-end scrollable-dropdown">
      <a type="button" v-for="element in list" @click="change_filter(element)" :class="{ 'active': (element.currently_active == true) }" class="dropdown-item"><i :class="(element.icon || '')"></i> {{ element.label }}</a>
    </div>
  </div>
</template>

<script>
import { defineComponent } from 'vue';

const filtering_icon = 'fas fa-filter'

export default defineComponent({
  components: {
  },
  props: {
    id: Number,
    dropdown_list: Array,
    url_param: String,
    active_element: Object,
  },
  emits: ["click_item"],
  /** This method is the first method of the component called, it's called before html template creation. */
  created() {
    this.list = this.$props.dropdown_list; 
  },
  data() {
    return {
      list: [],
      filter_icon: '',
    };
  },
  /** This method is the first method called after html template creation. */
  mounted() {
    (this.$props.active_element.filter_icon == false) ? this.filter_icon = '' : this.filter_icon = filtering_icon
    ntopng_sync.ready(this.$props["ref"]);
  },
  methods: {
    change_filter: function(element) {
      (element.filter_icon == false) ? this.filter_icon = '' : this.filter_icon = filtering_icon
      this.list.forEach((el) => { el.currently_active = false });
      element.currently_active = true;
      this.$emit('click_item', element, this.$props.url_param, this.$props.id)
    }
  },
});
</script>
