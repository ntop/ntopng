<template>
<div>
  <div class="form-group ms-2 me-2 mt-3 row">
    <label class="col-form-label" >
      <b>{{title}}</b>
    </label>
  </div>
  <div v-for="item in timeseries" class="form-group ms-4 me-2 mt-1 row">
    <div class="">
      <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="item.raw">
      
      <label class="custom-control-label ms-1 form-check-label">{{item.label}}</label>
    </div>
    <div class="">
      <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="item.avg">
      
      <label class="custom-control-label ms-1 form-check-label">Avg {{item.label}}</label>
    </div>
    <div class="">
      <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="item.perc_95">
      
      <label class="custom-control-label ms-1 form-check-label">95th Perc {{item.label}}</label>
    </div>
  </div>
</div>
</template>

<script setup>
const props = defineProps({
    timeseries: Array,
    title: String,
});
</script>
