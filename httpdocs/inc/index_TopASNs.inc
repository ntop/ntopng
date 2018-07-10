<h4>Top Talker ASNs</h4>
<div class="pie-chart" id="topASN"></div>
<span class="help-block" style="color: #dddddd;">Click on the ASN for more information.</span>
<script type='text/javascript'>

window.onload=function() {
   var refresh = 3000 /* ms */;

   do_pie("#topASN", '@HTTP_PREFIX@/lua/get_top_realtime.lua?module=top_asn', { senders_receivers : "senders" }, "", refresh);
}

</script>
