<h4 class='mb-2'>Top Hosts (Send+Receive)</h4>
<div class="my-2">
   <div class="pie-chart m-auto" id="topHosts">
   </div>
</div>
<span class="help-block">Click on the host for more information.</span>
<div class='my-3'></div>
<script type='text/javascript'>
window.onload = () => {
   let refresh = 3000 /* ms */;
   do_pie("#topHosts", '@HTTP_PREFIX@/lua/iface_hosts_list.lua', {  }, "", refresh);
}
</script>