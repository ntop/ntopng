<h4 class='mb-2'>Top Application Protocols</h4>
<div class='my-2'>
   <div class="pie-chart m-auto" id="topApplicationProtocols"></div>
</div>
<span class="help-block">Click on the application for more information.</span>
<div class='my-3'></div>
<script type='text/javascript'>
window.onload = () => {
   //interface.getStats()
   let refresh = 3000 /* ms */;
   do_pie("#topApplicationProtocols", '@HTTP_PREFIX@/lua/rest/v2/get/interface/l7/stats.lua', { ndpistats_mode: "sinceStartup", ifid: interfaceID}, "", refresh);
}
</script>
