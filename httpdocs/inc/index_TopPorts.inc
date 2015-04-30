
<table border=0>
<tr><td>
<h4>Top Client Ports</h4>
<div class="pie-chart" id="topClientPorts"></div>
<span class="help-block" style="color: #dddddd;">Click on the port for more information.</span>
</td>
<td>&nbsp;</td>
<td>
<h4>Top Server Ports</h4>
<div class="pie-chart" id="topServerPorts"></div>
<span class="help-block" style="color: #dddddd;">Click on the port for more information.</span>
</td></tr>
</table>

<script type='text/javascript'>

window.onload=function() {
   var refresh = 3000 /* ms */;

   do_pie("#topClientPorts", '@HTTP_PREFIX@/lua/iface_ports_list.lua', { mode: "client" }, "", refresh);
   do_pie("#topServerPorts", '@HTTP_PREFIX@/lua/iface_ports_list.lua', { mode: "server" }, "", refresh);
}

</script>


