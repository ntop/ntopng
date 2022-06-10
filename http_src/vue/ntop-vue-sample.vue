<template>
  <div class="ntop-vue-sample">
  </div>
</template>

<script>
import { defineComponent } from 'vue';

export default /*#__PURE__*/defineComponent({
    name: 'NtopVueSample', // vue component name
    component: {
    },
    data() {
	return {
	    counter: 5,
	    initCounter: 5,
	    message: {
		action: null,
		amount: null,
	    },
	};
    },
    computed: {
	changedBy() {
	    const { message } = this;
	    if (!message.action) return 'initialized';
	    return `${message.action} ${message.amount || ''}`.trim();
	},
    },
    methods: {
	increment(arg) {
	    const amount = (typeof arg !== 'number') ? 1 : arg;
	    this.counter += amount;
	    this.message.action = 'incremented by';
	    this.message.amount = amount;
	},
	decrement(arg) {
	    const amount = (typeof arg !== 'number') ? 1 : arg;
	    this.counter -= amount;
	    this.message.action = 'decremented by';
	    this.message.amount = amount;
	},
	reset() {
	    this.counter = this.initCounter;
	    this.message.action = 'reset';
	    this.message.amount = null;
	},
    },
});
</script>

<style scoped>
  .ntop-vue-sample {
    display: block;
    width: 400px;
    margin: 25px auto;
    border: 1px solid #ccc;
    background: #eaeaea;
    text-align: center;
    padding: 25px;
  }
  .ntop-vue-sample p {
    margin: 0 0 1em;
  }
</style>
