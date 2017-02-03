            <h4>Top Flow Talkers: Live</h4>
	    <div class="pie-chart" id="topSenders"></div>
<span class="help-block" style="color: #dddddd;">Click on the host for more information.</span>
<script type='text/javascript'>

window.onload=function() {
   var refresh = 3000 /* ms */;

   do_pie("#topSenders", '@HTTP_PREFIX@/lua/top_generic.lua?module=top_talkers', { mode : "senders" }, "", refresh);
}

</script>
