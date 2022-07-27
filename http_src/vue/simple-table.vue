<!-- (C) 2022 - ntop.org     -->
<template>
<div>
  Hello World
{{max_sent}} {{70}}
<table  class="table table-borderless graph-statistics mb-2" style="">
    <thead class="text-center">
        <tr>
            <th class="graph-val-total-title fs-6" style="border-left-width: 1px; border-top-width: 1px;"> Total:</th>
            <th class="graph-val-95percentile-title fs-6" style="border-left-width: 1px; border-top-width: 1px;">95th <a href="https://en.wikipedia.org/wiki/Percentile">Percentile</a>:</th>
            <th class="graph-val-average-title fs-6" style="border-left-width: 1px; border-top-width: 1px;">Average:</th>
            <th class="graph-val-max-title fs-6" style="border-left-width: 1px; border-top-width: 1px; border-right-width: 1px;">Max:</th>
        </tr>
    </thead>
    <tbody><tr>
   <td class="graph-val-total text-center" style="border-width: 1px;"> <span>62.57 MB</span></td>
   <td class="graph-val-95percentile text-center" style="border-top-width: 1px; border-right-width: 1px; border-bottom-width: 1px;"> <span>388.04 Kbit/s [Sent]<br>97.09 Kbit/s [Rcvd]</span></td>
   <td class="graph-val-average text-center" style="border-top-width: 1px; border-right-width: 1px; border-bottom-width: 1px;"> <span>{{max_sent}} Kbit/s [Sent]<br>54.98 Kbit/s [Rcvd]</span></td>
   <!-- <td class="graph-val-min" style="display:none;border-bottom-width: 1px;border-top-width: 1px;border-right-width: 1px;">nil: <span></span></td> -->
   <td class="graph-val-max text-center" style="border-bottom-width: 1px; border-top-width: 1px; border-right-width: 1px;"> <span>2.07 Mbit/s [Sent] (27/07/2022 10:25:41)<br>135.55 Kbit/s [Rcvd] (27/07/2022 10:34:31)</span></td>
</tr></tbody></table>

</div>
</template>

<script>
export default {
    components: {
    },
    props: {
	chart_options: Object,
    },
    watch: {
	"chart_options": function(val, oldVal) {
	    this.reloaded_table();
	}
    },
    emits: [],
    /** This method is the first method of the component called, it's called before html template creation. */
    created() {
    },
    data() {
	return {
	    max_sent: 0,
	    max_rcvd: 0,
	};
    },
    /** This method is the first method called after html template creation. */
    async mounted() {
	console.log("Mounted Simple table");
    },
    methods: {
	reloaded_table: function() {
	    console.log("reloaded table called");
	    console.log(this.chart_options);
	    this.max_sent = 100;
	},
    },
};
</script>
