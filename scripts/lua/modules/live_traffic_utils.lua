--
-- (C) 2014-21 - ntop.org
--

local live_traffic_utils = {}

function live_traffic_utils.printLiveTrafficForm(ifid, host_info)
   local has_vlan = (host_info and (tonumber(host_info["vlan"]) or 0) > 0)

   if has_vlan then
      local template = require "template_utils"

      print(
	 template.gen("modal_confirm_dialog.html", {
			 dialog = {
			    id      = "live_traffic_download_modal",
			    action  = "live_traffic_download_submit()",
			    title   = i18n("live_traffic.modal_vlan_tagged_with_bpf_title"),
			    message = i18n("live_traffic.modal_vlan_tagged_with_bpf_confirmation",
					   {vlan = host_info["vlan"]}),
			    confirm = i18n("live_traffic.modal_vlan_tagged_with_bpf_continue")
			 }
	 })
      )
   end

   print[[
<form id="live-capture-form" class="form-inline" action="]] print(ntop.getHttpPrefix().."/lua/live_traffic.lua") print [[" method="GET">
  <input type=hidden id="live-capture-ifid" name=ifid value="]] print(ifid.."") print [[">]]
   if host_info then
      print[[<input type=hidden id="live-capture-host" name=host value="]] print(hostinfo2hostkey(host_info)) print [[">]]
   end

   print[[
<div class="input-group mb-1">
    <select class="btn border bg-white" id="duration" name=duration>
      <option value=10>10 sec</option>
      <option value=30>30 sec</option>
      <option value=60 selected>1 min</option>
      <option value=300>5 min</option>
      <option value=600>10 min</option>
    </select>
&nbsp;
  <label for="bpf_filter" class="sr-only">]] print(i18n("db_explorer.filter_bpf")) print[[</label>
  <input type="text" class="form-control" id="live-capture-bpf-filter" name="bpf_filter" placeholder="]] print(i18n("db_explorer.filter_bpf")) print[["></input>
  <button type="submit" class="btn btn-secondary" onclick="return live_capture_download_show_modal();">]] print(i18n("download_x", {what="pcap"})) print[[</button>
</div>
</form>

<script type='text/javascript'>
]]

   if not has_vlan then
      print[[
var live_capture_download_show_modal = function() {
   /* resume submit */
   return true;
}
]]
   else
      print[[
var live_capture_download_show_modal = function(){
  if($('#live-capture-bpf-filter').val() == '' || 
     $('#live-capture-bpf-filter').val().includes('vlan')) {
    /* Resume submit, nothing to show (the user didn't specify any BPF or VLAN is specified) */
    return true;
  }

  $('#live_traffic_download_modal').modal('show');

  /* Abort submit */
  return false;
};

var live_traffic_download_submit = function() {
  /* Now it's time to do the actual submit... */

  $('#live_traffic_download_modal').modal('hide');
  $('#live-capture-form').submit();
};
]]
   end
   print[[
</script>
]]

end

return live_traffic_utils
