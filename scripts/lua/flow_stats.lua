--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

local json = require ("dkjson")

flow_key = _GET["flow_key"]
if(flow_key == nil) then
 flow = nil
else
 interface.select(ifname)
 flow = interface.findFlowByKey(tonumber(flow_key))
end

throughput_type = getThroughputType()

sendHTTPHeader('text/html; charset=iso-8859-1')
--sendHTTPHeader('application/json')

if(flow == nil) then
 print('{}')
else

 diff0 = os.time()-flow["seen.first"]
 diff = os.time()-flow["seen.last"]
   -- Default values
   thpt = 0
   thpt_display = bitsToSize(0)
   if (throughput_type == "bps") then
    thpt = 8*flow["throughput_bps"]
    thpt_display = bitsToSize(thpt)
    top_thpt_display = bitsToSize(8*flow["top_throughput_bps"])
    
    elseif (throughput_type == "pps") then
      thpt = flow["throughput_pps"]
      thpt_display = pktsToSize(thpt)
      top_thpt_display = pktsToSize(flow["top_throughput_pps"])
    end
    print('{ ' .. '"seen.last": "'.. formatEpoch(flow["seen.last"]) .. ' ['.. secondsToTime(diff) .. ' ago]", ' 
    .. '"seen.first": "'.. formatEpoch(flow["seen.first"]) .. ' ['.. secondsToTime(diff0) .. ' ago]"' 
    .. ', "bytes": ' .. flow["bytes"] .. ', "goodput_bytes": ' .. flow["goodput_bytes"] .. ', "cli2srv.packets": ' .. flow["cli2srv.packets"] .. ', "srv2cli.packets": ' .. flow["srv2cli.packets"] .. ', "cli2srv.bytes": ' .. flow["cli2srv.bytes"] .. ', "srv2cli.bytes": ' .. flow["srv2cli.bytes"].. ', "throughput": "' .. thpt_display..'", "top_throughput_display": "'.. top_thpt_display ..'", "throughput_raw": ' .. thpt)

    if(flow["proto.l4"] == "TCP") then
       print(', "c2sOOO":'.. flow["cli2srv.out_of_order"] )
       print(', "c2slost":'..flow["cli2srv.lost"] )
       print(', "c2sretr":'..flow["cli2srv.retransmissions"] )
       print(', "s2cOOO":'.. flow["srv2cli.out_of_order"] )
       print(', "s2clost":'..flow["srv2cli.lost"] )
       print(', "s2cretr":'..flow["srv2cli.retransmissions"] )
    end

    -- Processes information
    show_processes = false
    if ((flow.client_process ~= nil) or (flow.server_process ~= nil) )then show_processes= true end
    
    if (show_processes)then print (', "processes": {') end

    if(flow.client_process ~= nil) then

      proc = flow.client_process
      print ('"'..proc.pid..'": {')
     
      if(proc.actual_memory > 0) then
        -- average_cpu_load
        print('"average_cpu_load": "')
	load = round(proc.average_cpu_load, 2)
        if(proc.average_cpu_load < 33) then
          if(proc.average_cpu_load == 0) then proc.average_cpu_load = "< 1" end
          print("<font color=green>"..load.." %</font>")
        elseif(proc.average_cpu_load < 66) then
          print("<font color=orange><b>"..load.." %</b></font>")
        else
          print("<font color=red><b>"..load.." %</b></font>")
        end
        print('"')
        -- memory
        print(', "memory": "'.. bytesToSize(proc.actual_memory) .. " / ".. bytesToSize(proc.peak_memory) .. " [" .. round((proc.actual_memory*100)/proc.peak_memory, 1) ..'%]"')
        -- page faults
        print(', "page_faults": ')
        if(proc.num_vm_page_faults > 0) then
          print('"<font color=red><b>'..proc.num_vm_page_faults..'</b></font>"')
        else
          print('"<font color=green><b>'..proc.num_vm_page_faults..'</b></font>"')
        end
      end

      print ('}')
    end

    if(flow.server_process ~= nil) then
      if (flow.client_process ~= nil) then print (',') end

      proc = flow.server_process
      print ('"'..proc.pid..'": {')

      if(proc.actual_memory > 0) then
        -- average_cpu_load
        load = round(proc.average_cpu_load, 2)
        print('"average_cpu_load": "')
        if(proc.average_cpu_load < 33) then
          if(proc.average_cpu_load == 0) then proc.average_cpu_load = "< 1" end
          print("<font color=green>"..load.." %</font>")
        elseif(proc.average_cpu_load < 66) then
          print("<font color=orange><b>"..load.." %</b></font>")
        else
          print("<font color=red><b>"..load.." %</b></font>")
        end
        print('"')

        print(', "memory": "'.. bytesToSize(proc.actual_memory) .. " / ".. bytesToSize(proc.peak_memory) .. " [" .. round((proc.actual_memory*100)/proc.peak_memory, 1) ..'%]"')
        
        print(', "page_faults": ')
        if(proc.num_vm_page_faults > 0) then
          print('"<font color=red><b>'..proc.num_vm_page_faults..'</b></font>"')
        else
          print('"<font color=green><b>'..proc.num_vm_page_faults..'</b></font>"')
        end
      end

      print ('}')
    end

    if (show_processes)then print ('}') end

    if (flow["moreinfo.json"] ~= nil) then
      local info, pos, err = json.decode(flow["moreinfo.json"], 1, nil)
      sip_found = isThereProtocol("SIP", info)
      if(sip_found == 1) then
        local called_party = ""
        local calling_party = ""
        local sip_rtp_src_addr = 0
        local sip_rtp_dst_addr = 0
        print(', "sip.call_id":"'..getFlowValue(info, "SIP_CALL_ID")..'"')
        called_party = getFlowValue(info, "SIP_CALLED_PARTY")
        calling_party = getFlowValue(info, "SIP_CALLING_PARTY")
        if(((called_party == nil) or (called_party == "")) and ((calling_party == nil) or (calling_party == ""))) then
          print(', "sip.calling_called_party":"'..getFlowValue(info, "SIP_CALLING_PARTY") .. ' ' .. getFlowValue(info, "SIP_CALLED_PARTY")..'"')
        else
          print(', "sip.calling_called_party":"'..getFlowValue(info, "SIP_CALLING_PARTY") .. ' <i class=\\\"fa fa-exchange fa-lg\\\"></i> ' .. getFlowValue(info, "SIP_CALLED_PARTY")..'"')
        end

        print(', "sip.rtp_codecs":"'..getFlowValue(info, "SIP_RTP_CODECS")..'"')
        time, time_epoch = getFlowValue(info, "SIP_INVITE_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_invite":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_invite":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_TRYING_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_trying":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_trying":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_RINGING_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_ringing":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_ringing":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_INVITE_OK_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_invite_ok":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_invite_ok":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_INVITE_FAILURE_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_invite_failure":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_invite_failure":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_BYE_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_bye":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_bye":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_BYE_OK_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_bye_ok":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_bye_ok":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_CANCEL_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_cancel":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_cancel":""')
        end
        time, time_epoch = getFlowValue(info, "SIP_CANCEL_OK_TIME")
        if(time_epoch ~= "0") then
          print(', "sip.time_cancel_ok":"'..time ..' [' .. secondsToTime(os.time()-time_epoch) .. ' ago]"')
        else
          print(', "sip.time_cancel_ok":""')
        end

        print(', "sip.rtp_stream":"');
        if((getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")~="")) then
          sip_rtp_src_addr = 1
          print(getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR"))
        end
        if((getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~="") and (sip_rtp_src_addr == 1)) then
          print(':'..getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR"))
        end
        if((sip_rtp_src_addr == 1) or ((getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=""))) then
          print(' <i class=\\\"fa fa-exchange fa-lg\\\"></i> ')
        end
        if((getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~="")) then
          sip_rtp_dst_addr = 1
          print(getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR"))
        end
        if((getFlowValue(info, "SIP_RTP_L4_DST_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_DST_PORT")~="") and (sip_rtp_dst_addr == 1)) then
          print(':'..getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR"))
        end
        print('"');


        print(', "sip.response_code":"'..getFlowValue(info, "SIP_RESPONSE_CODE")..'"')
        val, val_original = getFlowValue(info, "SIP_REASON_CAUSE")
        if(val_original ~= "0") then
          print(', "sip.reason_cause":"'..val..'"')
        else
          print(', "sip.reason_cause":""')
        end
        print(', "sip.c_ip":"'..getFlowValue(info, "SIP_C_IP")..'"')
        print(', "sip.call_state":"'..getFlowValue(info, "SIP_CALL_STATE")..'"')
      end

      rtp_found = isThereProtocol("RTP", info)
      if(rtp_found == 1) then
        print(', "rtp.sync_source_id":"'..getFlowValue(info, "RTP_SSRC")..'"')
        print(', "rtp.first_flow_timestamp":"<i class=\\\"fa fa-clock-o fa-lg\\\"></i>  '..getFlowValue(info, "RTP_FIRST_TS")..'"' )
        print(', "rtp.last_flow_timestamp":"<i class=\\\"fa fa-clock-o fa-lg\\\"></i>  '..getFlowValue(info, "RTP_LAST_TS")..'"' )
        print(', "rtp.first_flow_sequence":"'..getFlowValue(info, "RTP_FIRST_SEQ")..'"' )
        print(', "rtp.last_flow_sequence":"'..getFlowValue(info, "RTP_LAST_SEQ")..'"' )
        print(', "rtp.jitter_in":"'..getFlowValue(info, "RTP_IN_JITTER")..'"' )
        print(', "rtp.jitter_out":"'..getFlowValue(info, "RTP_OUT_JITTER")..'"' )
        print(', "rtp.packet_lost_in":"'..getFlowValue(info, "RTP_IN_PKT_LOST")..'"' )
        print(', "rtp.packet_lost_out":"'..getFlowValue(info, "RTP_OUT_PKT_LOST")..'"' )
        print(', "rtp.packet_discarded_in":"'..getFlowValue(info, "RTP_IN_PKT_DROP")..'"' )
        print(', "rtp.packet_discarded_out":"'..getFlowValue(info, "RTP_OUT_PKT_DROP")..'"' )
        print(', "rtp.payload_type_in":"'..getFlowValue(info, "RTP_IN_PAYLOAD_TYPE")..'"' )
        print(', "rtp.payload_type_out":"'..getFlowValue(info, "RTP_OUT_PAYLOAD_TYPE")..'"' )
        print(', "rtp.max_delta_time_in":"'..getFlowValue(info, "RTP_IN_MAX_DELTA")..'"' )
        print(', "rtp.max_delta_time_out":"'..getFlowValue(info, "RTP_OUT_MAX_DELTA")..'"' )
        print(', "rtp.rtp_sip_call_id":"'..getFlowValue(info, "RTP_SIP_CALL_ID")..'"' )
        print(', "rtp.mos_average":"'..getFlowValue(info, "RTP_MOS")..'"' )
        print(', "rtp.r_factor_average":"'..getFlowValue(info, "RTP_R_FACTOR")..'"' )
        print(', "rtp.mos_in":"'..getFlowValue(info, "RTP_IN_MOS")..'"' )
        print(', "rtp.r_factor_in":"'..getFlowValue(info, "RTP_IN_R_FACTOR")..'"' )
        print(', "rtp.mos_out":"'..getFlowValue(info, "RTP_OUT_MOS")..'"' )
        print(', "rtp.r_factor_out":"'..getFlowValue(info, "RTP_OUT_R_FACTOR")..'"' )
        print(', "rtp.rtp_transit_in":"'..getFlowValue(info, "RTP_IN_TRANSIT")..'"' )
        print(', "rtp.rtp_transit_in":"'..getFlowValue(info, "RTP_OUT_TRANSIT")..'"' )
        print(', "rtp.rtp_rtt":"'..getFlowValue(info, "RTP_RTT")..'"' )
        print(', "rtp.dtmf_tones":"'..getFlowValue(info, "RTP_DTMF_TONES")..'"' )
      end
  end

  print (' }\n')
end
