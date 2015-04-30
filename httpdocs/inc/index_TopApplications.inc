<h4>Top Application Protocols</h4>
<div class="pie-chart" id="topApplicationProtocols"></div>
<span class="help-block" style="color: #dddddd;">Click on the application for more information.</span>
<script type='text/javascript'>

window.onload=function() {
   var refresh = 3000 /* ms */;

   do_pie("#topApplicationProtocols", '@HTTP_PREFIX@/lua/iface_ndpi_stats.lua', {  }, "", refresh);
}

</script>
