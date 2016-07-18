--
-- (C) 2014-15 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = false

-- notify ntopng upon preference changes
function notifyNtopng(key)
    if key == nil then return end
    -- notify runtime ntopng configuration changes
    if string.starts(key, 'nagios') then
        if verbose then io.write('notifying ntopng upon nagios pref change\n') end
        ntop.reloadNagiosConfig()
    elseif string.starts(key, 'toggle_logging_level') then
        if verbose then io.write('notifying ntopng upon logging level pref change\n') end 
        ntop.setLoggingLevel(value)
    end
end

-- ############################################
-- Runtime preference

function prefsInputFieldPrefs(label, comment, prekey, key, default_value, _input_type, showEnabled)

  k = prekey..key

  if(_GET[key] ~= nil) then
    v_s = _GET[key]
    v = tonumber(v_s)

    v_cache = ntop.getPref(k)
    value = v_cache
    if ((v_cache==nil) or (v ~= v_cache)) then

      if(v ~= nil and (v > 0) and (v <= 86400)) then
        ntop.setPref(k, tostring(v))
        value = v
      elseif (v_s ~= nil) then
        v_s = string.gsub(v_s, "ldaps:__", "ldaps://")
        v_s = string.gsub(v_s, "ldap:__", "ldap://")
        ntop.setPref(k, v_s)
        value = v_s
      end
      -- least but not last we ascynchronously notify the runtime ntopng instance for changes
      notifyNtopng(key)
    end
  else
    v_s = ntop.getPref(k)
    value = v_s
    if((v_s==nil) or (v_s=="")) then
      ntop.setPref(k, tostring(default_value))
      value = default_value
      notifyNtopng(key)
    end
  end

  if ((showEnabled == nil) or (showEnabled == true)) then
    showEnabled = "table-row"
  else
    showEnabled = "none"
  end

  local input_type = "text"
  if _input_type ~= nil then input_type = _input_type end
  print('<tr id="'..key..'" style="display: '..showEnabled..';"><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  print [[
	   <td class="input-group col-lg-3" align=right>]]
print [[
    <div class="input-group" >
      <div >
        <input id="id_input_]] print(key) print[["type="]] print(input_type) print [[" class="form-control" name="]] print(key) print [[" style="text-align:right;" value="]] print(value.."") print [[">
      </div>
    </div><!-- /input-group -->
  </td></tr>
]]

end

function toggleTableButton(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field, redis_key, disabled)
  if(_GET[submit_field] ~= nil) then
    ntop.setPref(redis_key, _GET[submit_field])
    value = _GET[submit_field]
    notifyNtopng(submit_field)
  else
    value = ntop.getPref(redis_key)
  end
  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  -- Read it anyway to
  if(value == off_value) then
    rev_value  = on_value
    on_active  = "btn-default"
    off_active = "btn-"..off_color.." active"
  else
    rev_value  = off_value
    on_active  = "btn-"..on_color.." active"
    off_active = "btn-default"
  end

  if(label ~= "") then print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
  print('<form>\n<div class="btn-group btn-toggle">')
  print('<button type="submit" '..disabled..' class="btn btn-sm  '..on_active..'">'..on_label..'</button>')
  print('<button '..disabled..' class="btn btn-sm '..off_active..'">'..off_label..'</button></div>\n')
  print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
  print('<input type=hidden name='..submit_field..' value='..rev_value..' />\n')
  print('</form>\n')
  if(label ~= "") then print('</td></tr>') end

  return(value)
end

function toggleTableButtonPrefs(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field,
                                redis_key, default_value, disabled, elementToSwitch, hideOn, showElement)

  value = ntop.getPref(redis_key)
  if(_GET[submit_field] ~= nil) then
    if ( (value == nil) or (value ~= _GET[submit_field])) then
      ntop.setPref(redis_key, _GET[submit_field])
      value = _GET[submit_field]
      notifyNtopng(submit_field)
    end
  else
    if ((value == nil) or (value == "")) then
      if (default_value ~= nil) then
        value = default_value
      else
        value = off_value
      end
      ntop.setPref(redis_key, value)
      notifyNtopng(submit_field)
    end
  end

  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  -- Read it anyway to
  if(value == off_value) then
    on_active  = "btn-default"
    off_active = "btn-"..off_color.." active"
  else
    value = on_value
    on_active  = "btn-"..on_color.." active"
    off_active = "btn-default"
  end

  local objRow = ""
  if ((showElement ~= nil) and (showElement == false)) then
    objRow = " style=\"display:none\""
  else
    objRow = " style=\"display:table-row\""
  end
  if(label ~= "") then print('<tr id="row_'..submit_field..'"'..objRow..'><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
  print('<div class="btn-group btn-toggle">')
  print('<button type="button" onclick="'..submit_field..'_functionOn()" id="'..submit_field..'_on_id" '..disabled..' class="btn btn-sm  '..on_active..'">'..on_label..'</button>')
  print('<button type="button" onclick="'..submit_field..'_functionOff()" id="'..submit_field..'_off_id" '..disabled..' class="btn btn-sm '..off_active..'">'..off_label..'</button></div>\n')
  print('<input type=hidden id="'..submit_field..'_input" name='..submit_field..' value="'..value..'"/>\n')
  if(label ~= "") then print('</td></tr>') end
  print('\n')
  print('<script>\n')
  print[[function ]] print(submit_field) print [[_functionOn(){
    var classOn = document.getElementById("]] print(submit_field) print [[_on_id");
    var classOff = document.getElementById("]] print(submit_field) print [[_off_id");
    classOn.removeAttribute("class");
    classOff.removeAttribute("class");
    classOn.setAttribute("class", "btn btn-sm btn-]]print(on_color) print[[ active");
    classOff.setAttribute("class", "btn btn-sm btn-default");
    $("#]] print(submit_field) print [[_input").val("]] print(on_value) print[[");]]
    if elementToSwitch ~= nil then
      for element = 1, #elementToSwitch do
        if ((hideOn == nil) or (hideOn == false)) then
          print('$("#'..elementToSwitch[element]..'").css("display","table-row");')
        else
          print('$("#'..elementToSwitch[element]..'").css("display","none");')
        end
      end
    end
    print[[
  }
  ]]
  print[[
  function ]] print(submit_field) print [[_functionOff(){
    var classOn = document.getElementById("]] print(submit_field) print [[_on_id");
    var classOff = document.getElementById("]] print(submit_field) print [[_off_id");
    classOn.removeAttribute("class");
    classOff.removeAttribute("class");
    classOn.setAttribute("class", "btn btn-sm btn-default");
    classOff.setAttribute("class", "btn btn-sm btn-]]print(off_color) print[[ active");
    $("#]] print(submit_field) print [[_input").val("]]print(off_value) print[[");]]
    if elementToSwitch ~= nil then
      for element = 1, #elementToSwitch do
        if ((hideOn == nil) or (hideOn == false)) then
          print('$("#'..elementToSwitch[element]..'").css("display","none");')
        else
          print('$("#'..elementToSwitch[element]..'").css("display","table-row");')
        end
      end
    end
    print [[
  }]]
  print('</script>\n')
  return(value)
end

function multipleTableButtonPrefs(label, comment, array_labels, array_values, default_value, selected_color,
                                  submit_field, redis_key, disabled, elementToSwitch, showElementArray,
                                  javascriptAfterSwitch, showElement)
  if(_GET[submit_field] ~= nil) then
    ntop.setPref(redis_key, _GET[submit_field])
    value = _GET[submit_field]
    notifyNtopng(submit_field)
  else
    value = ntop.getPref(redis_key)
    if(value == "") then
      if(default_value ~= nil) then
        ntop.setPref(redis_key, default_value)
        value = default_value
      end
    end
  end

  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  local objRow = ""
  if ((showElement ~= nil) and (showElement == false)) then
    objRow = " style=\"display:none\""
  else
    objRow = " style=\"display:table-row\""
  end
  if(value ~= nil) then
    if(label ~= "") then print('<tr id="row_'..submit_field..'"'..objRow..'><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
    print('<div class="btn-group" data-toggle="buttons-radio" data-toggle-name="'..submit_field..'">')

    for nameCount = 1, #array_labels do
      local type_button = "btn-default"
      if(value == array_values[nameCount]) then
        type_button = "btn-"..selected_color.."  active"
      end
      print('<button id="id_'..array_values[nameCount]..'" value="'..array_values[nameCount]..'" type="button" class="btn btn-sm '..type_button..'" data-toggle="button">'..array_labels[nameCount]..'</button>\n')
    end
    print('</div>\n')
    print('<input type="hidden" id="id-toggle-'..submit_field..'" name="'..submit_field..'" value="'..value..'" />\n')
    print('<script>\n')
    for nameCount = 1, #array_labels do
      print('$("#id_'..array_values[nameCount]..'").click(function() {\n')
      print('  $(\'#id-toggle-'..submit_field..'\').val("'..array_values[nameCount]..'");\n')

      for indexLabel = 1, #array_labels do
        print[[ var class_]] print(array_values[indexLabel]) print[[ = document.getElementById("id_]] print(array_values[indexLabel]) print [[");
        class_]] print(array_values[indexLabel]) print[[.removeAttribute("class");]]
        if(array_values[indexLabel] == array_values[nameCount]) then
          print[[class_]] print(array_values[indexLabel]) print[[.setAttribute("class", "btn btn-sm btn-]]print(selected_color) print[[ active");]]
        else
          print[[class_]] print(array_values[indexLabel]) print[[.setAttribute("class", "btn btn-sm btn-default");]]
        end
      end

      if (showElementArray ~= nil) then
      for indexSwitch = 1, #showElementArray do
        if (indexSwitch == nameCount) then
          if elementToSwitch ~= nil then
            for element = 1, #elementToSwitch do
              if (showElementArray[indexSwitch] == true) then
                print('$("#'..elementToSwitch[element]..'").css("display","table-row");\n')
              else
                print('$("#'..elementToSwitch[element]..'").css("display","none");\n')
              end
            end
          end
        end
      end
      end

      if javascriptAfterSwitch ~= nil then
        print(javascriptAfterSwitch)
      end

      print('});\n')
    end
    print('</script>\n')
    if(label ~= "") then print('</td></tr>') end
  end

  return(value)
end

function loggingSelector(label, comment, submit_field, redis_key)
  prefs = ntop.getPrefs()
  if prefs.has_cmdl_trace_lvl then return end

  if(_GET[submit_field] ~= nil) then
    ntop.setCache(redis_key, _GET[submit_field])
    value = _GET[submit_field]
    notifyNtopng(submit_field, _GET[submit_field])
  else
    value = ntop.getCache(redis_key)
  end

  if value == "" or value == nil then
     value = "normal"
  end

  if(value == "trace") then color = "default"
  elseif(value == "debug") then color = "success"
  elseif(value == "info") then color = "info"
  elseif(value == "normal") then color = "primary"
  elseif(value == "warning") then color = "warning"
  elseif(value == "error") then color = "danger"
  else color = "default"
  end



  if(label ~= "") then print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
  print[[
     <input id="]] print(submit_field) print[[" name="]] print(submit_field) print[[" type="hidden">
     <div class="dropdown">
      <button class="btn btn-]] print(color) print[[ dropdown-toggle" type="button" data-toggle="dropdown">]] print(value:gsub("^%l", string.upper))
  print[[
      <span class="caret"></span></button>
      <ul class="dropdown-menu dropdown-menu-right">
        <li onclick="$('#]] print(submit_field) print[[').val('trace');"><a href="#">Trace</a></li>
        <li onclick="$('#]] print(submit_field) print[[').val('debug');"><a href="#">Debug</a></li>
        <li onclick="$('#]] print(submit_field) print[[').val('info');"><a href="#">Info</a></li>
        <li onclick="$('#]] print(submit_field) print[[').val('normal');"><a href="#">Normal</a></li>
        <li onclick="$('#]] print(submit_field) print[[').val('warning');"><a href="#">Warning</a></li>
        <li onclick="$('#]] print(submit_field) print[[').val('error');"><a href="#">Error</a></li>
      </ul>
    </div>
    
    <script type="text/javascript">
      $(".dropdown-menu li a").click(function(){
        $(this).parents('.btn-group').find('.dropdown-toggle').html($(this).text()+'<span class="caret"></span>');
        $(".btn:first").removeClass("btn-default");
        $(".btn:first").removeClass("btn-success");
        $(".btn:first").removeClass("btn-info");
        $(".btn:first").removeClass("btn-primary");
        $(".btn:first").removeClass("btn-warning");
        $(".btn:first").removeClass("btn-danger");
        switch($(this).text()){
            case "Trace":
                $(".btn:first").addClass("btn-default");
                $(".btn:first").html("Trace "+'<span class="caret"></span>');
                break;
            case "Debug":
                $(".btn:first").addClass("btn-success");
                $(".btn:first").html("Debug "+'<span class="caret"></span>');
                break;
            case "Info":
                $(".btn:first").addClass("btn-info");
                $(".btn:first").html("Info "+'<span class="caret"></span>');
                break;
            case "Normal":
                $(".btn:first").addClass("btn-primary");
                $(".btn:first").html("Normal "+'<span class="caret"></span>');
                break;
            case "Warning":
                $(".btn:first").addClass("btn-warning");
                $(".btn:first").html("Warning "+'<span class="caret"></span>');
                break;
            case "Error":
                $(".btn:first").addClass("btn-danger");
                $(".btn:first").html("Error "+'<span class="caret"></span>');
                break;
            default:
                $(".btn:first").addClass("btn-default");
        }
      });
    </script>
  ]]
  if(label ~= "") then print('</td></tr>') end

  return(value)
end
