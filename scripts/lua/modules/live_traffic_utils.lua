--
-- (C) 2014-18 - ntop.org
--

local live_traffic_utils = {}

function live_traffic_utils.printLiveTrafficForm(ifid, host_info)
print[[
<form id="live-capture-form" class="form-inline" action="]] print(ntop.getHttpPrefix().."/lua/live_traffic.lua") print [[" method="GET">
  <input type=hidden name=ifid value="]] print(ifid.."") print [[">]]
  if host_info then
    print[[<input type=hidden name=host value="]] print(hostinfo2hostkey(host_info)) print [[">]]
  end

  print[[<div class="form-group mb-2">
    <label for="duration" class="sr-only">]] print(i18n("duration")) print[[</label>
      <select class="form-control" id="duration" name=duration>
      <option value=10>10 sec</option>
      <option value=30>30 sec</option>
      <option value=60 selected>1 min</option>
      <option value=300>5 min</option>
      <option value=600>10 min</option>
    </select>
  </div>
  <div class="form-group mx-sm-3 mb-2">
    <label for="bpf_filter" class="sr-only">]] print(i18n("db_explorer.filter_bpf")) print[[</label>
    <input type="text" class="form-control" id="bpf_filter" name="bpf_filter" placeholder="]] print(i18n("db_explorer.filter_bpf")) print[["></input>
  </div>
  <button type="submit" class="btn btn-default mb-2">]] print(i18n("download_x", {what="pcap"})) print[[</button>
</form>
]] 

end

return live_traffic_utils