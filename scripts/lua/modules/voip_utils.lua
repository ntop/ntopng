--
-- (C) 2013-18 - ntop.org
--

-- ########################################################
-- require "flow_utils"


local payload_type = 0


function isVoip(key,value)
  key_label = getFlowKey(key)

  if (key_label == "Total number of exported flows") then return 1 end

  if (key_label =='Rtp Voice Quality') then
   print("<tr><th width=30%>" .. key_label .. '</th><td colspan=2>')
   print(MosPercentageBar(value))
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
rtp_payload_type = {
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
   if(flags == nil) then return("") end
   
   flags = tonumber(flags)

   if(rtp_payload_type[flags] ~= nil) then
      return(rtp_payload_type[flags])
   end

   return flags;
end

-- ########################################################

function MosPercentageBar(value)
   local ret_bar = ""
   value = tonumber(value)

   if (value >= 4.0)  then
      ret_bar = '<span class="label label-success">'..value..' '..i18n("flow_details.desirable_label")..'</span>'
   elseif ((value >= 3.6) and (value < 4.0)) then
      ret_bar = '<span class="label label-info">'..value..' '..i18n("flow_details.acceptable_label")..'</span>'
   elseif ((value >= 2.6) and (value < 3.6)) then
      ret_bar = '<span class="label label-warning">'..value..' '..i18n("flow_details.reach_connection_label")..'</span>'
   elseif ((value > 0) and (value < 2.6)) then
      ret_bar = '<span class="label label-danger">'..value..' '..i18n("flow_details.not_recommended_label")..'</span>'
   end

   return ret_bar
end

-- ########################################################

function RFactorPercentageBar(value)
   local ret_bar = ""
   value = tonumber(value)

   if (value >= 80.0)  then
      ret_bar = '<span class="label label-success">'..value..' '..i18n("flow_details.desirable_label")..'</span>'
   elseif ((value >= 70.0) and (value < 80.0)) then
      ret_bar = '<span class="label label-info">'..value..' '..i18n("flow_details.acceptable_label")..'</span>'
   elseif ((value >= 50.0) and (value < 70.0)) then
      ret_bar = '<span class="label label-warning">'..value..' '..i18n("flow_details.reach_connection_label")..'</span>'
   elseif ((value >= 0) and (value < 50.0)) then
      ret_bar = '<span class="label label-danger">'..value..' '..i18n("flow_details.not_recommended_label")..'</span>'
   end

   return ret_bar
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

-- ######################################
-- RTP functions
-- ######################################
function printSyncSourceFields ()
print [[
  var sync_source_id_tr = document.getElementById('sync_source_id_tr').style;
  if( rsp["rtp.sync_source_id"] && (rsp["rtp.sync_source_id"] != "") ){
    $('#sync_source_id').html(rsp["rtp.sync_source_id"]);
    sync_source_id_tr.display = 'table-row';
  } else {
    $('#sync_source_id').html("");
    sync_source_id_tr.display = 'none';
  }
]]
end

-- ######################################
function printFirstLastFlowSequenceFields ()
print [[
  var first_last_flow_sequence_id_tr = document.getElementById('first_last_flow_sequence_id_tr').style;
  if( (rsp["rtp.first_flow_sequence"] && (rsp["rtp.first_flow_sequence"] != "")) ||
      (rsp["rtp.last_flow_sequence"] && (rsp["rtp.last_flow_sequence"] != ""))){
    first_last_flow_sequence_id_tr.display = 'table-row';
  }

  if( rsp["rtp.first_flow_sequence"] && (rsp["rtp.first_flow_sequence"] != "") ){
    $('#first_flow_sequence').html(rsp["rtp.first_flow_sequence"]);
  } else {
    $('#first_flow_sequence').html("-");
  }
  if( rsp["rtp.last_flow_sequence"] && (rsp["rtp.last_flow_sequence"] != "") ){
    $('#last_flow_sequence').html(rsp["rtp.last_flow_sequence"]);
  } else {
    $('#last_flow_sequence').html("-");
  }
]]
end

-- ######################################
function printJitterFields ()
print [[
  var jitter_id_tr = document.getElementById('jitter_id_tr').style;
  if( (rsp["rtp.jitter_in"] && (rsp["rtp.jitter_in"] != "")) ||
      (rsp["rtp.jitter_out"] && (rsp["rtp.jitter_out"] != ""))){
    jitter_id_tr.display = 'table-row';
  }

  if( rsp["rtp.jitter_in"] && (rsp["rtp.jitter_in"] != "") ){
    $('#jitter_in').html(rsp["rtp.jitter_in"]+" ms");
    if(jitter_in_trend){
      if(rsp["rtp.jitter_in"] > jitter_in_trend){
          $('#jitter_in_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.jitter_in"] < jitter_in_trend){
          $('#jitter_in_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#jitter_in_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#jitter_in_trend').html("<i class=\"fa fa-minus\"></i>");
    }
    jitter_in_trend = rsp["rtp.jitter_in"];
  } else {
    $('#jitter_in').html("-");
    $('#jitter_in_trend').html("");
  }

  if( rsp["rtp.jitter_out"] && (rsp["rtp.jitter_out"] != "") ){
    $('#jitter_out').html(rsp["rtp.jitter_out"]+" ms");
    if(jitter_out_trend){
      if(rsp["rtp.jitter_out"] > jitter_out_trend){
          $('#jitter_out_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.jitter_out"] < jitter_out_trend){
          $('#jitter_out_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#jitter_out_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#jitter_out_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#jitter_out').html("-");
    $('#jitter_out_trend').html("");
  }
  jitter_out_trend = rsp["rtp.jitter_out"];
]]
end

-- ######################################
function printPacketLostFields ()
print [[
  var rtp_packet_loss_id_tr = document.getElementById('rtp_packet_loss_id_tr').style;
  if( (rsp["rtp.packet_lost_in"] && (rsp["rtp.packet_lost_in"] != "")) ||
      (rsp["rtp.packet_lost_out"] && (rsp["rtp.packet_lost_out"] != ""))){
    rtp_packet_loss_id_tr.display = 'table-row';
  }

  if( rsp["rtp.packet_lost_in"] && (rsp["rtp.packet_lost_in"] != "") ){
    $('#packet_lost_in').html(formatPackets(rsp["rtp.packet_lost_in"]));
    if(packet_lost_in_trend){
      if(rsp["rtp.packet_lost_in"] > packet_lost_in_trend){
          $('#packet_lost_in_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else {
          $('#packet_lost_in_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#packet_lost_in_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#packet_lost_in').html("-");
    $('#packet_lost_in_trend').html("");
  }
  packet_lost_in_trend = rsp["rtp.packet_lost_in"];

  if( rsp["rtp.packet_lost_out"] && (rsp["rtp.packet_lost_out"] != "") ){
    $('#packet_lost_out').html(formatPackets(rsp["rtp.packet_lost_out"]));
    if(packet_lost_out_trend){
      if(rsp["rtp.packet_lost_out"] > packet_lost_out_trend){
          $('#packet_lost_out_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else {
          $('#packet_lost_out_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#packet_lost_out_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#packet_lost_out').html("-");
    $('#packet_lost_out_trend').html("");
  }
  packet_lost_out_trend = rsp["rtp.packet_lost_out"];
]]
end

-- ######################################
function printPacketDropFields ()
print [[
  var packet_drop_id_tr = document.getElementById('packet_drop_id_tr').style;
  if( (rsp["rtp.packet_drop_in"] && (rsp["rtp.packet_drop_in"] != "")) ||
      (rsp["rtp.packet_drop_out"] && (rsp["rtp.packet_drop_out"] != ""))){
    packet_drop_id_tr.display = 'table-row';
  }

  if( rsp["rtp.packet_drop_in"] && (rsp["rtp.packet_drop_in"] != "") ){
    $('#packet_drop_in').html(formatPackets(rsp["rtp.packet_drop_in"]));
    if(packet_drop_in_trend){
      if(rsp["rtp.packet_drop_in"] > packet_drop_in_trend){
          $('#packet_drop_in_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else {
          $('#packet_drop_in_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#packet_drop_in_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#packet_drop_in').html("-");
    $('#packet_drop_in_trend').html("");
  }
  packet_drop_in_trend = rsp["rtp.packet_drop_in"];

  if( rsp["rtp.packet_drop_out"] && (rsp["rtp.packet_drop_out"] != "") ){
    $('#packet_drop_out').html(formatPackets(rsp["rtp.packet_drop_out"]));
    if(packet_drop_out_trend){
      if(rsp["rtp.packet_drop_out"] > packet_drop_out_trend){
          $('#packet_drop_out_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else {
          $('#packet_drop_out_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#packet_drop_out_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#packet_drop_out').html("-");
    $('#packet_drop_out_trend').html("");
  }
  packet_drop_out_trend = rsp["rtp.packet_drop_out"];
]]
end


-- ######################################
function printPayloadTypeInOutFields ()
  print [[
  var payload_id_tr = document.getElementById('payload_id_tr').style;
  if( (rsp["rtp.payload_type_in"] && (rsp["rtp.payload_type_in"] != "")) ||
      (rsp["rtp.payload_type_out"] && (rsp["rtp.payload_type_out"] != ""))){
    payload_id_tr.display = 'table-row';
  }

  if( rsp["rtp.payload_type_in"] && (rsp["rtp.payload_type_in"] != "") ){
    $('#payload_type_in').html(rsp["rtp.payload_type_in"]);
  } else {
    $('#payload_type_in').html("-");
  }
  if( rsp["rtp.payload_type_out"] && (rsp["rtp.payload_type_out"] != "") ){
    $('#payload_type_out').html(rsp["rtp.payload_type_in"]);
  } else {
    $('#payload_type_out').html("-");
  }
  ]]
end

-- ######################################
function printDeltaTimeInOutFields ()
print [[
  var delta_time_id_tr = document.getElementById('delta_time_id_tr').style;
  if( (rsp["rtp.max_delta_time_in"] && (rsp["rtp.max_delta_time_in"] != "")) ||
      (rsp["rtp.max_delta_time_out"] && (rsp["rtp.max_delta_time_out"] != ""))){
    delta_time_id_tr.display = 'table-row';
  }

  if( rsp["rtp.max_delta_time_in"] && (rsp["rtp.max_delta_time_in"] != "") ){
    $('#max_delta_time_in').html(rsp["rtp.max_delta_time_in"]+" ms");
    if(max_delta_time_in_trend){
      if(rsp["rtp.max_delta_time_in"] > max_delta_time_in_trend){
          $('#max_delta_time_in_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.max_delta_time_in"] < max_delta_time_in_trend){
          $('#max_delta_time_in_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#max_delta_time_in_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#max_delta_time_in_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#max_delta_time_in').html("-");
    $('#max_delta_time_in_trend').html("");
  }
  max_delta_time_in_trend = rsp["rtp.max_delta_time_in"];

  if( rsp["rtp.max_delta_time_out"] && (rsp["rtp.max_delta_time_out"] != "") ){
    $('#max_delta_time_out').html(rsp["rtp.max_delta_time_out"]+" ms");
    if(max_delta_time_out_trend){
      if(rsp["rtp.max_delta_time_out"] > max_delta_time_out_trend){
          $('#max_delta_time_out_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.max_delta_time_out"] < max_delta_time_out_trend){
          $('#max_delta_time_out_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#max_delta_time_out_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#max_delta_time_out_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#max_delta_time_out').html("-");
    $('#max_delta_time_out_trend').html("");
  }
  max_delta_time_out_trend = rsp["rtp.max_delta_time_out"];
]]
end

-- ######################################
function printSipCallIdFields ()
print [[
  var sip_call_id_tr = document.getElementById('sip_call_id_tr').style;
  if( rsp["rtp.rtp_sip_call_id"] && (rsp["rtp.rtp_sip_call_id"] != "")){
    sip_call_id_tr.display = 'table-row';
    $('#rtp_sip_call_id').html(rsp["rtp.rtp_sip_call_id"]);
  } else {
    $('#rtp_sip_call_id').html("-");
  }
]]
end

-- ######################################
function printQualityAverageFields ()
  print [[
  var quality_average_id_tr = document.getElementById('quality_average_id_tr').style;
  if( (rsp["rtp.mos_average"] && (rsp["rtp.mos_average"] != "")) ||
      (rsp["rtp.r_factor_average"] && (rsp["rtp.r_factor_average"] != "")) ){
    quality_average_id_tr.display = 'table-row';
  }

  if( (rsp["rtp.mos_average"] && (rsp["rtp.mos_average"] != ""))  || (rsp["rtp.r_factor_average"] && (rsp["rtp.r_factor_average"] != ""))){
    if( rsp["rtp.mos_average"] && (rsp["rtp.mos_average"] != "")) {
      if( rsp["rtp.mos_average"] < 2) {
        $('#mos_average_signal').html("<i class='fa fa-signal' style='color:red'></i> ");
      }
      if ( (rsp["rtp.mos_average"] > 2) && (rsp["rtp.mos_average"] < 3)) {
        $('#mos_average_signal').html("<i class='fa fa-signal' style='color:orange'></i> ");
      }
      if( rsp["rtp.mos_average"] > 3) {
        $('#mos_average_signal').html("<i class='fa fa-signal' style='color:green'></i> ");
      }
    } else {
      $('#mos_average_signal').html("<i class='fa fa-signal'></i> ");
    }
  } else {
    $('#mos_average_signal').html("");
  }
  if( rsp["rtp.mos_average"] && (rsp["rtp.mos_average"] != "") ){
    $('#mos_average').html(rsp["rtp.mos_average"]);
    if(mos_average_trend){
      if(rsp["rtp.mos_average"] > mos_average_trend){
          $('#mos_average_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.mos_average"] < mos_average_trend){
          $('#mos_average_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#mos_average_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#mos_average_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#mos_average').html("-");
    $('#mos_average_trend').html("");
  }
  mos_average_trend = rsp["rtp.mos_average"];

  if( rsp["rtp.mos_average"] && (rsp["rtp.mos_average"] != "") ){
    $('#mos_average_slash').html(" / ");
    $('#r_factor_average').html(rsp["rtp.r_factor_average"]);
    if(r_factor_average_trend){
      if(rsp["rtp.r_factor_average"] > r_factor_average_trend){
          $('#r_factor_average_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.r_factor_average"] < r_factor_average_trend){
          $('#r_factor_average_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#r_factor_average_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#r_factor_average_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#mos_average_slash').html("");
    $('#r_factor_average').html("");
    $('#r_factor_average_trend').html("");
  }
  r_factor_average_trend = rsp["rtp.r_factor_average"];

  ]]
end

-- ######################################
function printQualityMosFields ()
print [[
  var quality_mos_id_tr = document.getElementById('quality_mos_id_tr').style;
  if( (rsp["rtp.mos_in"] && (rsp["rtp.mos_in"] != "")) ||
      (rsp["rtp.r_factor_in"] && (rsp["rtp.r_factor_in"] != "")) ||
      (rsp["rtp.mos_out"] && (rsp["rtp.mos_out"] != "")) ||
      (rsp["rtp.r_factor_out"] && (rsp["rtp.r_factor_out"] != "")) ){
    quality_mos_id_tr.display = 'table-row';
  }

  if( (rsp["rtp.mos_in"] && (rsp["rtp.mos_in"] != ""))  || (rsp["rtp.r_factor_in"] && (rsp["rtp.r_factor_in"] != ""))){
    if( rsp["rtp.mos_in"] && (rsp["rtp.mos_in"] != "")) {
      if( rsp["rtp.mos_in"] < 2) {
        $('#mos_in_signal').html("<i class='fa fa-signal' style='color:red'></i> ");
      }
      if ( (rsp["rtp.mos_in"] > 2) && (rsp["rtp.mos_in"] < 3)) {
        $('#mos_in_signal').html("<i class='fa fa-signal' style='color:orange'></i> ");
      }
      if( rsp["rtp.mos_in"] > 3) {
        $('#mos_in_signal').html("<i class='fa fa-signal' style='color:green'></i> ");
      }
    } else {
      $('#mos_in_signal').html("<i class='fa fa-signal'></i> ");
    }
  } else {
    $('#mos_in_signal').html("-");
  }
  if( rsp["rtp.mos_in"] && (rsp["rtp.mos_in"] != "") ){
    $('#mos_in').html(rsp["rtp.mos_in"]);
    if(mos_in_trend){
      if(rsp["rtp.mos_in"] > mos_in_trend){
          $('#mos_in_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.mos_in"] < mos_in_trend){
          $('#mos_in_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#mos_in_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#mos_in_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#mos_in').html("-");
    $('#mos_in_trend').html("");
  }
  mos_in_trend = rsp["rtp.mos_in"];

  if( rsp["rtp.r_factor_in"] && (rsp["rtp.r_factor_in"] != "") ){
    $('#mos_in_slash').html(" / ");
    $('#r_factor_in').html(rsp["rtp.r_factor_in"]);
    if(r_factor_in_trend){
      if(rsp["rtp.r_factor_in"] > r_factor_in_trend){
          $('#r_factor_in_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.r_factor_in"] < r_factor_in_trend){
          $('#r_factor_in_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#r_factor_in_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#r_factor_in_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#mos_in_slash').html("");
    $('#r_factor_in').html("");
    $('#r_factor_in_trend').html("");
  }
  r_factor_in_trend = rsp["rtp.r_factor_in"];

  if( (rsp["rtp.mos_out"] && (rsp["rtp.mos_out"] != ""))  || (rsp["rtp.r_factor_out"] && (rsp["rtp.r_factor_out"] != ""))){
    if( rsp["rtp.mos_out"] && (rsp["rtp.mos_out"] != "")) {
      if( rsp["rtp.mos_out_signal"] < 2) {
        $('#mos_out_signal').html("<i class='fa fa-signal' style='color:red'></i> ");
      }
      if ( (rsp["rtp.mos_out_signal"] > 2) && (rsp["rtp.mos_out_signal"] < 3)) {
        $('#mos_out_signal').html("<i class='fa fa-signal' style='color:orange'></i> ");
      }
      if( rsp["rtp.mos_out_signal"] > 3) {
        $('#mos_out_signal').html("<i class='fa fa-signal' style='color:green'></i> ");
      }
    } else {
      $('#mos_out_signal').html("<i class='fa fa-signal'></i> ");
    }
  } else {
    $('#mos_out_signal').html("-");
  }
  if( rsp["rtp.mos_out"] && (rsp["rtp.mos_out"] != "") ){
    $('#mos_out').html(rsp["rtp.mos_out"]);
    if(mos_out_trend){
      if(rsp["rtp.mos_out"] > mos_out_trend){
          $('#mos_out_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.mos_out"] < mos_out_trend){
          $('#mos_out_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#mos_out_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#mos_out_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#mos_out').html("-");
    $('#mos_out_trend').html("");
  }
  mos_out_trend = rsp["rtp.mos_out"];

  if( rsp["rtp.r_factor_out"] && (rsp["rtp.r_factor_out"] != "") ){
    $('#mos_out_slash').html(" / ");
    $('#r_factor_out').html(rsp["rtp.r_factor_out"]);
    if(r_factor_out_trend){
      if(rsp["rtp.r_factor_out"] > r_factor_out_trend){
          $('#r_factor_out_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.r_factor_out"] < r_factor_out_trend){
          $('#r_factor_out_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#r_factor_out_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#r_factor_out_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#mos_out_slash').html("");
    $('#r_factor_out').html("");
    $('#r_factor_out_trend').html("");
  }
  r_factor_out_trend = rsp["rtp.r_factor_out"];

]]
end

-- ######################################
function printTransitIFields ()
print [[
  var rtp_transit_id_tr = document.getElementById('rtp_transit_id_tr').style;
  if( (rsp["rtp.rtp_transit_in"] && (rsp["rtp.rtp_transit_in"] != "")) ||
      (rsp["rtp.rtp_transit_out"] && (rsp["rtp.rtp_transit_out"] != "")) ){
    rtp_transit_id_tr.display = 'table-row';
  }

  if( rsp["rtp.rtp_transit_in"] && (rsp["rtp.rtp_transit_in"] != "") ){
    $('#rtp_transit_in').html(rsp["rtp.rtp_transit_in"]);
  } else {
    $('#rtp_transit_in').html("-");
  }
  if( rsp["rtp.rtp_transit_out"] && (rsp["rtp.rtp_transit_out"] != "") ){
    $('#rtp_transit_out').html(rsp["rtp.rtp_transit_out"]);
  } else {
    $('#rtp_transit_out').html("-");
  }
]]
end

-- ######################################
function printRrtFields ()
  print [[
  var rtt_id_tr = document.getElementById('rtt_id_tr').style;
  if( rsp["rtp.rtp_rtt"] && (rsp["rtp.rtp_rtt"] != "")){
    rtt_id_tr.display = 'table-row';
  }

  if( rsp["rtp.rtp_rtt"] && (rsp["rtp.rtp_rtt"] != "") ){
    $('#rtp_rtt').html(rsp["rtp.rtp_rtt"]+ " ms");
    if(rtp_rtt_trend){
      if(rsp["rtp.rtp_rtt"] > rtp_rtt_trend){
          $('#rtp_rtt_trend').html("<i class=\"fa fa-arrow-up\"></i>");
      } else if(rsp["rtp.rtp_rtt"] < rtp_rtt_trend){
          $('#rtp_rtt_trend').html("<i class=\"fa fa-arrow-down\"></i>");
      } else {
          $('#rtp_rtt_trend').html("<i class=\"fa fa-minus\"></i>");
      }
    }else{
      $('#rtp_rtt_trend').html("<i class=\"fa fa-minus\"></i>");
    }
  } else {
    $('#rtp_rtt').html("-");
    $('#rtp_rtt_trend').html("");
  }
  rtp_rtt_trend = rsp["rtp.rtp_rtt"];
  ]]
end

-- ######################################
function printDtmfFields ()
  print [[
  var dtmf_id_tr = document.getElementById('dtmf_id_tr').style;
  if( (rsp["rtp.rtp_transit_in"] && (rsp["rtp.rtp_transit_in"] != "")) ||
      (rsp["rtp.rtp_transit_out"] && (rsp["rtp.rtp_transit_out"] != "")) ){
    dtmf_id_tr.display = 'table-row';
  }

  if( rsp["rtp.dtmf_tones"] && (rsp["rtp.dtmf_tones"] != "") ){
    $('#dtmf_tones').html(rsp["rtp.dtmf_tones"]);
  } else {
    $('#dtmf_tones').html("-");
  }
  ]]
end

-- ######################################
function updatePrintRtp ()
  printFirstLastFlowSequenceFields()
  printJitterFields()
  printPacketLostFields()
  printPacketDropFields()
  printPayloadTypeInOutFields()
  printDeltaTimeInOutFields()
  printSipCallIdFields()
  printTransitIFields()
  printRrtFields()
  printDtmfFields()
print [[


]]
end

-- ######################################
-- SIP functions
-- ######################################

function printCallIdFields ()
  print[[
  var call_id_tr = document.getElementById('call_id_tr').style;
  if( rsp["sip.call_id"] && (rsp["sip.call_id"] != "") ){
    $('#call_id').html(rsp["sip.call_id"]);
    call_id_tr.display = 'table-row';
  } else {
    $('#call_id').html("-");
  }
  ]]
end

-- ######################################
function printCalledCallingFields ()
print[[
  var called_calling_tr = document.getElementById('called_calling_tr').style;
  if( rsp["sip.calling_called_party"] && (rsp["sip.calling_called_party"] != "") ){
    $('#calling_called_party').html(rsp["sip.calling_called_party"]);
    called_calling_tr.display = 'table-row';
  } else {
    $('#calling_called_party').html("");
    called_calling_tr.display = 'none';
  }
]]
end

-- ######################################
function printCodecsFields ()
print[[
  var rtp_codecs_tr = document.getElementById('rtp_codecs_tr').style;
  if( rsp["sip.rtp_codecs"] && (rsp["sip.rtp_codecs"] != "") ){
    $('#rtp_codecs').html(rsp["sip.rtp_codecs"]);
    rtp_codecs_tr.display = 'table-row';
  } else {
    $('#rtp_codecs').html("");
    rtp_codecs_tr.display = 'none';
  }
]]
end

-- ######################################
function printInviteFields ()
print[[
  var invite_time_tr = document.getElementById('invite_time_tr').style;
  if( rsp["sip.time_invite"] && (rsp["sip.time_invite"] != "") ){
    $('#time_invite').html(rsp["sip.time_invite"]);
    invite_time_tr.display = 'table-row';
  } else {
    $('#time_invite').html("");
    invite_time_tr.display = 'none';
  }
]]
end

-- ######################################
function printTryingTimeFields ()
print[[
  var trying_time_tr = document.getElementById('trying_time_tr').style;
  if( rsp["sip.time_trying"] && (rsp["sip.time_trying"] != "") ){
    $('#time_trying').html(rsp["sip.time_trying"]);
    trying_time_tr.display = 'table-row';
  } else {
    $('#time_trying').html("");
    trying_time_tr.display = 'none';
  }
]]
end

-- ######################################
function printRingingTimeFields ()
print[[
  var ringing_time_tr = document.getElementById('ringing_time_tr').style;
  if( rsp["sip.time_ringing"] && (rsp["sip.time_ringing"] != "") ){
    $('#time_ringing').html(rsp["sip.time_ringing"]);
    ringing_time_tr.display = 'table-row';
  } else {
    $('#time_ringing').html("");
    ringing_time_tr.display = 'none';
  }
]]
end

-- ######################################
function printInviteOkFailureTimeFields ()
print[[
  if( rsp["sip.time_invite_ok"] && (rsp["sip.time_invite_ok"] != "") ){
    $('#time_invite_ok').html(rsp["sip.time_invite_ok"]);
  } else {
    $('#time_invite_ok').html("");
  }
  if( rsp["sip.time_invite_failure"] && (rsp["sip.time_invite_failure"] != "") ){
    $('#time_invite_failure').html(rsp["sip.time_invite_failure"]);
  } else {
    $('#time_invite_failure').html("");
  }
  var invite_ok_tr = document.getElementById('invite_ok_tr').style;
  if ( (rsp["sip.time_invite_ok"] && (rsp["sip.time_invite_ok"] != "")) || (rsp["sip.time_invite_failure"] && (rsp["sip.time_invite_failure"] != "")) )
    invite_ok_tr.display = 'table-row';
  else
    invite_ok_tr.display = 'none';

]]
end

-- ######################################
function printByeByeOkTimeFields ()
print[[
  if( rsp["sip.time_bye"] && (rsp["sip.time_bye"] != "") ){
    $('#time_bye').html(rsp["sip.time_bye"]);
  } else {
    $('#time_bye').html("");
  }

  if( rsp["sip.time_bye_ok"] && (rsp["sip.time_bye_ok"] != "") ){
    $('#time_bye_ok').html(rsp["sip.time_bye_ok"]);
  } else {
    $('#time_bye_ok').html("");
  }

  var time_bye_tr = document.getElementById('time_bye_tr').style;
  if ( (rsp["sip.time_bye"] && (rsp["sip.time_bye"] != "")) || (rsp["sip.time_bye_ok"] && (rsp["sip.time_bye_ok"] != "")) )
    time_bye_tr.display = 'table-row';
  else
    time_bye_tr.display = 'none';

]]
end

-- ######################################
function printCancelCancelOkTimeFields ()
print[[
  if( rsp["sip.time_cancel"] && (rsp["sip.time_cancel"] != "") ){
    $('#time_cancel').html(rsp["sip.time_cancel"]);
  } else {
    $('#time_cancel').html("");
  }

  if( rsp["sip.time_cancel_ok"] && (rsp["sip.time_cancel_ok"] != "") ){
    $('#time_cancel_ok').html(rsp["sip.time_cancel_ok"]);
  } else {
    $('#time_cancel_ok').html("");
  }

  var time_failure_tr = document.getElementById('time_failure_tr').style;
  if ( (rsp["sip.time_cancel"] && (rsp["sip.time_cancel"] != "")) || (rsp["sip.time_cancel_ok"] && (rsp["sip.time_cancel_ok"] != "")) )
    time_failure_tr.display = 'table-row';
  else
    time_failure_tr.display = 'none';
]]
end

-- ######################################
function printRtpStreamFields ()
print[[
  var rtp_stream_tr = document.getElementById('rtp_stream_tr').style;
  if( rsp["sip.rtp_stream"] && (rsp["sip.rtp_stream"] != "") ){
    $('#rtp_stream').html(rsp["sip.rtp_stream"]);
    rtp_stream_tr.display = 'table-row';
  } else {
    $('#rtp_stream').html("");
    rtp_stream_tr.display = 'none';
  }
]]
end

-- ######################################
function printFailureResponseCodeFields ()
print[[
  var failure_resp_code_tr = document.getElementById('failure_resp_code_tr').style;
  if( rsp["sip.response_code"] && (rsp["sip.response_code"] != "") ){
    $('#response_code').html(rsp["sip.response_code"]);
    failure_resp_code_tr.display = 'table-row';
  } else {
    $('#response_code').html("");
    failure_resp_code_tr.display = 'none';
  }
]]
end

-- ######################################
function printCbfReasonCauseFields ()
print[[
  var cbf_reason_cause_tr = document.getElementById('cbf_reason_cause_tr').style;
  if( rsp["sip.reason_cause"] && (rsp["sip.reason_cause"] != "") ){
    $('#reason_cause').html(rsp["sip.reason_cause"]);
    cbf_reason_cause_tr.display = 'table-row';
  } else {
    $('#reason_cause').html("");
    cbf_reason_cause_tr.display = 'none';
  }
]]
end

-- ######################################
function printSipCIpFields ()
  print[[
  var sip_c_ip_tr = document.getElementById('sip_c_ip_tr').style;
  if( rsp["sip.c_ip"] && (rsp["sip.c_ip"] != "") ){
    $('#c_ip').html(rsp["sip.c_ip"]);
    sip_c_ip_tr.display = 'table-row';
  } else {
    $('#c_ip').html("");
    sip_c_ip_tr.display = 'none';
  }
  ]]
end

-- ######################################
function printCallStateFields ()
print[[
  var sip_call_state_tr = document.getElementById('sip_call_state_tr').style;
  if( rsp["sip.call_state"] && (rsp["sip.call_state"] != "") ){
    $('#call_state').html(rsp["sip.call_state"]);
    sip_call_state_tr.display = 'table-row';
  } else {
    $('#call_state').html("");
    sip_call_state_tr.display = 'none';
  }
]]
end

-- ######################################
function updatePrintSip ()
  printCallIdFields()
  printCalledCallingFields()
  printCodecsFields()
  printInviteFields()
  printTryingTimeFields()
  printRingingTimeFields()
  printInviteOkFailureTimeFields()
  printByeByeOkTimeFields()
  printCancelCancelOkTimeFields()
  printRtpStreamFields()
  printFailureResponseCodeFields()
  printCbfReasonCauseFields()
  printSipCIpFields()
  printCallStateFields()
end
