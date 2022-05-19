<!-- (C) 2022 - ntop.org     -->
<template>
<div class="modal fade" ref="modal_id" tabindex="-1" role="dialog" aria-labelledby="dt-add-filter-modal-title"
     aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">
	  <slot name="title"></slot>
	</h5>
        <div class="modal-close">
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
          </button>
        </div>
      </div>
      <div class="modal-body">
	<slot name="body"></slot>
      </div>
      <div class="modal-footer">
        <div class="mr-auto">
        </div>
	<slot name="footer"></slot>
        <div class="alert alert-info test-feedback w-100" style="display: none;">
        </div>
      </div>
    </div>
  </div>
</div>
</template>

<script>
export default {
    components: {
    },
    props: {
	id: String,
    },
    emits: ["apply", "hidden", "showed"],
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
	let me = this;
	$(this.$refs["modal_id"]).on('shown.bs.modal', function (e) {
	    me.$emit("showed");
	});
	$(this.$refs["modal_id"]).on('hidden.bs.modal', function (e) {
	    me.$emit("hidden");
	});
	// notifies that component is ready
	ntopng_sync.ready(this.$props["id"]);
    },
    methods: {
	show: function() {
	    $(this.$refs["modal_id"]).modal("show");
	},
	apply: function() {
	    $(this.$refs["modal_id"]).modal("hide");
	    this.$emit("apply");
	},
	close: function() {
	    $(this.$refs["modal_id"]).modal("hide");
	},
    },
}
</script>
