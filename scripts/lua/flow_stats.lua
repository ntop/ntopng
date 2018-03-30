--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
require "voip_utils"

local json = require ("dkjson")

flow_key = _GET["flow_key"]
if(flow_key == nil) then
 flow = nil
else
 interface.select(ifname)
 flow = interface.findFlowByKey(tonumber(flow_key))
end

throughput_type = getThroughputType()

sendHTTPContentTypeHeader('text/html')
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

    local ifstats = interface.getStats()

    if ntop.isPro() and ifstats.inline and (flow["cli.pool_id"] ~= nil) and (flow["srv.pool_id"] ~= nil) then
      print(', "cli2srv_quota":'.. "\"")
      printFlowQuota(ifstats.id, flow, true --[[ client ]])
      print("\"" )
      print(', "srv2cli_quota":'.. "\"")
      printFlowQuota(ifstats.id, flow, false --[[ server ]])
      print("\"" )
    end

    if(flow["proto.l4"] == "TCP") then
       print(', "c2sOOO":'.. flow["cli2srv.out_of_order"] )
       print(', "c2slost":'..flow["cli2srv.lost"] )
       print(', "c2skeep_alive":'..flow["cli2srv.keep_alive"] )
       print(', "c2sretr":'..flow["cli2srv.retransmissions"] )
       print(', "s2cOOO":'.. flow["srv2cli.out_of_order"] )
       print(', "s2clost":'..flow["srv2cli.lost"] )
       print(', "s2ckeep_alive":'..flow["srv2cli.keep_alive"] )
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
        sip_found = isThereSIPCall(info)
      end

      if(sip_found == 1) then
        local called_party = ""
        local calling_party = ""
        local sip_rtp_src_addr = 0
        local sip_rtp_dst_addr = 0
        local print_second = 0
        local print_second_2 = 0

        print(', "sip.call_id":"'..getFlowValue(info, "SIP_CALL_ID")..'"')
        called_party = getFlowValue(info, "SIP_CALLED_PARTY")
        calling_party = getFlowValue(info, "SIP_CALLING_PARTY")
        called_party = extractSIPCaller(called_party)
        calling_party = extractSIPCaller(calling_party)
        if(((called_party == nil) or (called_party == "")) and ((calling_party == nil) or (calling_party == ""))) then
          print(', "sip.calling_called_party":"'..calling_party .. ' ' .. called_party..'"')
        else
          print(', "sip.calling_called_party":"'..calling_party .. ' <i class=\\\"fa fa-exchange fa-lg\\\"></i> ' .. called_party..'"')
        end

        print(', "sip.rtp_codecs":"'..getFlowValue(info, "SIP_RTP_CODECS")..'"')

        time_invite, time_epoch_invite = getFlowValue(info, "SIP_INVITE_TIME")
        time_trying, time_epoch_trying = getFlowValue(info, "SIP_TRYING_TIME")
        time_ringing, time_epoch_ringing = getFlowValue(info, "SIP_RINGING_TIME")
        time_invite_ok, time_epoch_invite_ok = getFlowValue(info, "SIP_INVITE_OK_TIME")
        time_invite_failure, time_epoch_invite_failure = getFlowValue(info, "SIP_INVITE_FAILURE_TIME")
        time_bye, time_epoch_bye = getFlowValue(info, "SIP_BYE_TIME")
        time_bye_ok, time_epoch_bye_ok = getFlowValue(info, "SIP_BYE_OK_TIME")
        time_cancel, time_epoch_cancel = getFlowValue(info, "SIP_CANCEL_TIME")
        time_cancel_ok, time_epoch_cancel_ok = getFlowValue(info, "SIP_CANCEL_OK_TIME")

        -- get delta invite
        local delta_invite = ""
        if(time_epoch_invite ~= "0") then
          if(time_epoch_ringing ~= "0") then
            if((tonumber(time_epoch_ringing) - tonumber(time_epoch_invite)) >= 0 ) then
              delta_invite = tonumber(time_epoch_ringing) - tonumber(time_epoch_invite)
              if (delta_invite == 0) then
                delta_invite = "< 1"
              end
              print_second = 1
            end
          else
            delta_invite = secondsToTime(os.time()-tonumber(time_epoch_invite))
            print_second = 0
          end
        end
        print(', "sip.time_invite":"')
        if(time_epoch_invite ~= "0") then
          print(delta_invite.."")
          if (print_second == 1) then print(' sec') end
        end
        print('"')

        local delta_trying = ""
        print_second = 0
        if(time_epoch_trying ~= "0") then
          if(time_epoch_ringing ~= "0") then
            if((tonumber(time_epoch_ringing) - tonumber(time_epoch_trying)) >= 0 ) then
              delta_trying = tonumber(time_epoch_ringing) - tonumber(time_epoch_trying)
              if (delta_trying == 0) then
                delta_trying = "< 1"
              end
              print_second = 1
            end
          else
            delta_trying = secondsToTime(os.time()-tonumber(time_epoch_trying))
            print_second = 0
          end
        end
        print(', "sip.time_trying":"')
        if(time_epoch_trying ~= "0") then
          print(delta_trying.."")
          if (print_second == 1) then print(' sec') end
        end
        print('"')

        local delta_ringing = ""
        print_second = 0
        if(time_epoch_ringing ~= "0") then
          if(time_epoch_invite_ok ~= "0") then
            if((tonumber(time_epoch_invite_ok) - tonumber(time_epoch_ringing)) >= 0 ) then
              delta_ringing = tonumber(time_epoch_invite_ok) - tonumber(time_epoch_ringing)
              if (delta_ringing == 0) then
                delta_ringing = "< 1"
              end
              print_second = 1
            end
          else
            if(time_epoch_invite_failure ~= "0") then
              if((tonumber(time_epoch_invite_failure) - tonumber(time_epoch_ringing)) >= 0 ) then
                delta_ringing = tonumber(time_epoch_invite_failure) - tonumber(time_epoch_ringing)
                if (delta_ringing == 0) then
                  delta_ringing = "< 1"
                end
                print_second = 1
              end
            else
              if(time_epoch_cancel_ok ~= "0") then
                if((tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_ringing)) >= 0 ) then
                  delta_ringing = tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_ringing)
                  if (delta_ringing == 0) then
                    delta_ringing = "< 1"
                  end
                  print_second = 1
                end
              else
                delta_ringing = secondsToTime(os.time()-tonumber(time_epoch_ringing))
                print_second = 0
              end
            end
          end
        end

        print(', "sip.time_ringing":"')
        if(time_epoch_ringing ~= "0") then
          print(delta_ringing.."")
          if (print_second == 1) then print(' sec') end
        end
        print('"')

        local delta_invite_ok = ""
        print_second = 0
        if(time_epoch_invite_ok ~= "0") then
          if(time_epoch_bye ~= "0") then
            if((tonumber(time_epoch_bye) - tonumber(time_epoch_invite_ok)) >= 0 ) then
              delta_invite_ok = tonumber(time_epoch_bye) - tonumber(time_epoch_invite_ok)
              if (delta_invite_ok == 0) then
                delta_invite_ok = "< 1"
              end
              print_second = 1
            end
          else
            delta_invite_ok = secondsToTime(os.time()-tonumber(time_epoch_invite_ok))
            print_second = 0
          end
        end

        print(', "sip.time_invite_ok":"')
        if(time_epoch_invite_ok ~= "0") then
          print(delta_invite_ok.."")
          if (print_second == 1) then print(' sec') end
        end
        print('"')

        local delta_invite_failure = ""
        print_second_2 = 0
        if(time_epoch_invite_failure ~= "0") then
          if(time_epoch_bye ~= "0") then
            if((tonumber(time_epoch_bye) - tonumber(time_epoch_invite_failure)) >= 0 ) then
              delta_invite_failure = tonumber(time_epoch_bye) - tonumber(time_epoch_invite_failure)
              if (delta_invite_failure == 0) then
                delta_invite_failure = "< 1"
              end
              print_second_2 = 1
            end
          else
            delta_invite_ok = secondsToTime(os.time()-tonumber(time_epoch_invite_failure))
            print_second_2 = 0
          end
        end

        print(', "sip.time_invite_failure":"')
        if(time_epoch_invite_failure ~= "0") then
          print(delta_invite_failure.."")
          if (print_second == 1) then print(' sec') end
        end
        print('"')


        local delta_bye = ""
        print_second = 0
        if(time_epoch_bye ~= "0") then
          if(time_epoch_bye_ok ~= "0") then
            if((tonumber(time_epoch_bye_ok) - tonumber(time_epoch_bye)) >= 0 ) then
              delta_bye = tonumber(time_epoch_bye_ok) - tonumber(time_epoch_bye)
              if (delta_bye == 0) then
                delta_bye = "< 1"
              end
              print_second = 1
            end
          else
            delta_bye = secondsToTime(os.time()-tonumber(time_epoch_bye_ok))
            print_second = 0
          end
        end

        print(', "sip.time_bye":"')
        if(time_epoch_bye ~= "0") then
          print(delta_bye.."")
          if (print_second == 1) then print(' sec') end
        end
        print('"')

        local delta_bye_ok = ""
        if(time_epoch_bye_ok ~= "0") then
            delta_bye_ok = secondsToTime(os.time()-tonumber(time_epoch_bye_ok))
        end

        print(', "sip.time_bye_ok":"')
        if(time_epoch_bye_ok ~= "0") then
          print(delta_bye_ok.."")
        end
        print('"')

        local delta_cancel = ""
        print_second = 0
        if(time_epoch_cancel ~= "0") then
          if(time_epoch_cancel_ok ~= "0") then
            if((tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_cancel)) >= 0 ) then
              delta_cancel = tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_cancel)
              if (delta_cancel == 0) then
                delta_cancel = "< 1"
              end
              print_second = 1
            end
          else
            delta_cancel = secondsToTime(os.time()-tonumber(time_epoch_cancel_ok))
            print_second = 0
          end
        end

        print(', "sip.time_cancel":"')
        if(time_epoch_cancel ~= "0") then
          print(delta_cancel.."")
          if (print_second == 1) then print(' sec') end
        end
        print('"')


        local delta_cancel_ok = ""
        if(time_epoch_cancel_ok ~= "0") then
            delta_cancel_ok = secondsToTime(os.time()-tonumber(time_epoch_cancel_ok))
        end

        print(', "sip.time_cancel_ok":"')
        if(time_epoch_cancel_ok ~= "0") then
          print(delta_cancel_ok.."")
        end
        print('"')

        print(', "sip.rtp_stream":"');
        if((getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")~="")) then
          sip_rtp_src_addr = 1
          local address_ip = getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")
          if (address_ip ~= "0.0.0.0") then
            interface.select(ifname)
            rtp_host = interface.getHostInfo(address_ip)
            if(rtp_host ~= nil) then
              print('<A HREF=\\\"'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='..address_ip.. '\\\">')
              print(address_ip)
              print('</A>')
            end
          else
            print(address_ip)
          end
        end
        if((getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~="") and (sip_rtp_src_addr == 1)) then
          --print(':'..getFlowValue(info, "SIP_RTP_L4_SRC_PORT"))
          print(':<A HREF=\\\"'..ntop.getHttpPrefix()..'/lua/port_details.lua?port='..getFlowValue(info, "SIP_RTP_L4_SRC_PORT").. '\\\">')
          print(getFlowValue(info, "SIP_RTP_L4_SRC_PORT"))
          print('</A>')
        end
        if((sip_rtp_src_addr == 1) or ((getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=""))) then
          print(' <i class=\\\"fa fa-exchange fa-lg\\\"></i> ')
        end
        if((getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~="")) then
          sip_rtp_dst_addr = 1
          local address_ip = getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")
          if (address_ip ~= "0.0.0.0") then
            interface.select(ifname)
            rtp_host = interface.getHostInfo(address_ip)
            if(rtp_host ~= nil) then
              print('<A HREF=\\\"'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='..address_ip.. '\\\">')
              print(address_ip)
              print('</A>')
            end
          else
            print(address_ip)
          end
        end
        if((getFlowValue(info, "SIP_RTP_L4_DST_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_DST_PORT")~="") and (sip_rtp_dst_addr == 1)) then
          --print(':'..getFlowValue(info, "SIP_RTP_L4_DST_PORT"))
          print(':<A HREF=\\\"'..ntop.getHttpPrefix()..'/lua/port_details.lua?port='..getFlowValue(info, "SIP_RTP_L4_DST_PORT").. '\\\">')
          print(getFlowValue(info, "SIP_RTP_L4_DST_PORT"))
          print('</A>')
        end
        print('"');

        fail_resp_code_string = getFlowValue(info, "SIP_RESPONSE_CODE")
        fail_resp_code_string = map_failure_resp_code(fail_resp_code_string)
        print(', "sip.response_code":"'..fail_resp_code_string..'"')
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
        --print(', "rtp.first_flow_timestamp":"'..getFlowValue(info, "RTP_FIRST_TS")..'"' )
        --print(', "rtp.last_flow_timestamp":"'..getFlowValue(info, "RTP_LAST_TS")..'"' )
        print(', "rtp.first_flow_sequence":"'..getFlowValue(info, "RTP_FIRST_SEQ")..'"' )
        print(', "rtp.last_flow_sequence":"'..getFlowValue(info, "RTP_LAST_SEQ")..'"' )
        print(', "rtp.jitter_in":"'..getFlowValue(info, "RTP_IN_JITTER")..'"' )
        print(', "rtp.jitter_out":"'..getFlowValue(info, "RTP_OUT_JITTER")..'"' )
        print(', "rtp.packet_lost_in":"'..getFlowValue(info, "RTP_IN_PKT_LOST")..'"' )
        print(', "rtp.packet_lost_out":"'..getFlowValue(info, "RTP_OUT_PKT_LOST")..'"' )
        print(', "rtp.packet_drop_in":"'..getFlowValue(info, "RTP_IN_PKT_DROP")..'"' )
        print(', "rtp.packet_drop_out":"'..getFlowValue(info, "RTP_OUT_PKT_DROP")..'"' )
	print(', "rtp.payload_type_in":"'..formatRtpPayloadType(getFlowValue(info, "RTP_IN_PAYLOAD_TYPE"))..'"' )
        print(', "rtp.payload_type_out":"'..formatRtpPayloadType(getFlowValue(info, "RTP_OUT_PAYLOAD_TYPE"))..'"' )
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
