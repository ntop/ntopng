<h4>Top Hosts (Send+Receive)</h4>
<div class="pie-chart" id="topHosts"></div>
<span class="help-block" style="color: #dddddd;">Click on the host for more information.</span>
<script type='text/javascript'>

window.onload=function() {
   var refresh = 3000 /* ms */;

   do_pie("#topHosts", '@HTTP_PREFIX@/lua/iface_hosts_list.lua', {  }, "", refresh);
}

</script>


