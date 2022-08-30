<template>
<div>
  <div class="form-group ms-2 me-2 mt-3 row">
    <div class="col-11">
      <label class="col-form-label" >
	<b>{{title}}</b>
      </label>
    </div>
    <div class="col-1" v-if="show_delete_button" @click="delete_ts">
      <button type="button" class="btn border">
	<span>
	  <i class="fas fa-trash"></i>
	</span>
      </button>
    </div>
  </div>
  <div v-for="item in timeseries" class="form-group custom-ms me-2 mt-1">
    <div class="inline-block">
      <input type="checkbox" class="custom-control-input whitespace form-check-input" @change="update_timeseries" v-model="item.raw">
      
      <label class="custom-control-label ms-1 form-check-label">{{item.label}}</label>
    </div>
    <div class="inline-block">
      <input type="checkbox" class="custom-control-input whitespace form-check-input" @change="update_timeseries" v-model="item.avg">
      
      <label class="custom-control-label ms-1 form-check-label">Avg {{item.label}}</label>
    </div>
    <div class="inline-block">
      <input type="checkbox" class="custom-control-input whitespace form-check-input" @change="update_timeseries" v-model="item.perc_95">
      
      <label class="custom-control-label ms-1 form-check-label">95th Perc {{item.label}}</label>
    </div>
  </div>
</div>
</template>

<script setup>
const props = defineProps({
    id: String,
    timeseries: Array,
    title: String,
    show_delete_button: Boolean,
});

const emit = defineEmits(['delete_ts', 'update:timeseries'])

function update_timeseries() {
    console.log(props.timeseries);
    emit('update:timeseries', props.timeseries);
}

function delete_ts() {
    emit('delete_ts', props.id);
}
</script>

<style scoped>
  .custom-ms {
  margin-left: 2rem !important;
  }
.inline-block {
    display: inline-block;
    margin-right: 1rem;
}
.border {
    border-style: solid !important;
}
</style>
