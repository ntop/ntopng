<h4>Top Talker ASNs</h4>
<div class="pie-chart" id="topASN"></div>

<script type='text/javascript'>

window.onload=function() {
   var refresh = 3000 /* ms */;

   do_pie("#topASN", '@HTTP_PREFIX@/lua/top_generic.lua?m=top_asn&param=senders', { mode : "senders" }, "", refresh);
}

</script>
