--
-- (C) 2013-16 - ntop.org
--

-- ########################################################
require "flow_utils"


local payload_type = 0


function isVoip(key,value)
  key_label = getFlowKey(key)
  
  if (key_label == "Total number of exported flows") then return 1 end

  if (key_label =='Rtp Voice Quality') then
   print("<tr><th width=30%>" .. key_label .. '</th><td colspan=2>')
   MosPercentageBar(value)
   print("</td></tr>\n")
   return 1

   elseif (key_label=='Sip Call State') then 
     print("<tr><th width=30%>" .. key_label .. "</th><td colspan=2>")
     SipCallStatePercentageBar(value)
     print("</td></tr>\n") 
     return 1

     elseif ((key_label == 'Rtp Out Coming Payload Type') or (key_label == "Rtp Incoming Payload Type")) then
      if (payload_type == 0) then
        payload_type = 1
        print("<tr><th width=30%>Rtp Payload Type</th><td colspan=2>"..formatRtpPayloadType(value).."</td></tr>\n")
      end

      return 1

      elseif ((key_label == 'Rtp Out Coming Packet Delay Variation') or (key_label == "Rtp Incoming Packet Delay Variation")) then
        print("<tr><th width=30%>" .. key_label .. "</th><td colspan=2>"..((value/1000)/1000).." ms</td></tr>\n")
        return 1
        elseif ((key_label == 'SIP_CALLED_PARTY') or (key_label == "SIP_CALLING_PARTY")) then
          print("<tr><th width=30%>" .. key_label .. "</th><td colspan=2>"..spiltSipID(value).."</td></tr>\n")
          return 1
        end

        return 0
      end



function spiltSipID( id )
  id = string.gsub(id, "<sip:", "")
  id = string.gsub(id, ">", "")
  port = split(id,":")
  sip_party = split(port[1],"@")
  host = interface.getHostInfo(sip_party[2])
  if (host ~= nil) then
    return('<A HREF="'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='.. sip_party[2]..'">'.. id.. '</A>')
  end
  return(id)
end

-- RTP
local rtp_payload_type = {
[0] = 'PCMU', 
[1] = 'reserved', 
[2] = 'reserved',
[3] = 'GSM', 
[4] = 'G723', 
[5] = 'DVI4', 
[6] = 'DVI4', 
[7] = 'LPC',
[8] = 'PCMA', 
[9] = 'G722', 
[10] = 'L16', 
[11] = 'L16', 
[12] = 'QCELP',     
[13] = 'CN', 
[14] = 'MPA', 
[15] = 'G728', 
[16] = 'DVI4', 
[17] = 'DVI4', 
[18] = 'G729', 
[25] = 'CELB', 
[26] = 'JPEG', 
[28] = 'NV', 
[31] = 'H261',
[32] = 'MPV',
[33] = 'MP2T', 
[34] = 'H263',
[35] = 'unassigned',
[71] = 'unassigned',
[76] = 'Reserved for RTCP conflict avoidance',
[72] = 'Reserved for RTCP conflict avoidance', 
[73] = 'Reserved for RTCP conflict avoidance', 
[74] = 'Reserved for RTCP conflict avoidance', 
[75] = 'Reserved for RTCP conflict avoidance', 
[76] = 'Reserved for RTCP conflict avoidance', 
[95] = 'unassigned',
[96] = 'dynamic',
[127] = 'dynamic'
}

-- ########################################################

function formatRtpPayloadType(flags)
 flags = tonumber(flags)

 if(rtp_payload_type[flags] ~= nil) then

  return(rtp_payload_type[flags])

end

return flags;
end

-- ########################################################

function MosPercentageBar(value)
 total = 5
 bar_class =  "bar-info"
 value = value /100
 value_type = ""

 pctg = round((value * 100) / total, 0)

 if ((value >= 4.0) and (value <= 5.0)) then 
  print('<span class="label label-success">'..value..' MOS - Desirable</span>')
  end
if ((value >= 3.6) and (value < 4.0)) then 
  print('<span class="label label-info">'..value..' MOS - Acceptable</span>')
end

if ((value >= 2.6) and (value < 3.6)) then 
  print('<span class="label label-warning">'..value..' MOS - Reach Connection</span>')
end

if ((value > 0) and (value < 2.6)) then
  print('<span class="label label-danger">'..value..' MOS - Not Recommended</span>')
end

end

-- ########################################################

function SipCallStatePercentageBar(state)
  -- Wireshark use different state http://wiki.wireshark.org/VoIP_calls
  label_class =  "label-default"

  if (state == "REGISTER") then
    label_class = "label-info"  
  end

  if (state == "CALL_STARTED") then
    label_class = "label-info"  
  end

  if (state == "CALL_IN_PROGRESS") then
    label_class = "label-progress"  
  end

  if (state == "CALL_COMPLETED") then
    label_class = "label-success"  
  end

  if (state == "CALL_ERROR") then
    label_class = "label-danger"  
  end

  if (state == "CALL_CANCELED") then
    label_class = "label-warning"  
  end

  if (state == "UNKNOWN") then
    label_class = "bar-warning"  
  end

  print('<span class="label '..label_class..'">'..state..'</span>')
end
