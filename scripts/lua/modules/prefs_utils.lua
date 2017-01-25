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

local options_script_loaded = false
local options_ctr = 0

function prefsResolutionButtons(fmt, value)
  local fmt_to_data = {
    ["s"] = {label="Secs",  value=1},
    ["m"] = {label="Mins",  value=60},
    ["h"] = {label="Hours", value=3600},
    ["d"] = {label="Days",  value=3600*24},
  }

  local ctrl_id = "options_group_" .. options_ctr
  options_ctr = options_ctr + 1

  local res = makeResolutionButtons(fmt_to_data, ctrl_id, fmt, value, {classes={"pull-right"}})

  print(res.html)
  print("<script>")
  if not options_script_loaded then
    print(res.init)
    options_script_loaded = true
  end
  print(res.js)
  print("</script>")

  return res.value
end

-- ############################################

-- Runtime preference

function prefsInputFieldPrefs(label, comment, prekey, key, default_value, _input_type, showEnabled, disableAutocomplete, allowURLs, extra)
  extra = extra or {}

  if(string.ends(prekey, ".")) then
    k = prekey..key
  else
    k = prekey.."."..key
  end

  if(_POST[key] ~= nil) then
    v_s = _POST[key]
    v = tonumber(v_s)

    v_cache = ntop.getPref(k)
    value = v_cache
    if ((v_cache==nil) or (v ~= v_cache)) then

      if(v ~= nil and (v > 0) and (v <= 86400)) then
        ntop.setPref(k, tostring(v))
        value = v
      elseif (v_s ~= nil) then
      	if(allowURLs) then
	        v_s = string.gsub(v_s, "ldaps:__", "ldaps://")
        	v_s = string.gsub(v_s, "ldap:__", "ldap://")
		v_s = string.gsub(v_s, "http:__", "http://")
		v_s = string.gsub(v_s, "https:__", "https://")
	end
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

  local attributes = {}

  if extra.min ~= nil then
    if extra.tformat ~= nil then
      attributes["data-min"] = extra.min
    else
      attributes["min"] = extra.min
    end
  end

  if extra.max ~= nil then
    if extra.tformat ~= nil then
      attributes["data-max"] = extra.max
    else
      attributes["max"] = extra.max
    end
  end

  if (_input_type == "number") then
    attributes["required"] = "required"
  end

  local input_type = "text"
  if _input_type ~= nil then input_type = _input_type end
  print('<tr id="'..key..'" style="display: '..showEnabled..';"><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  local style = {}
  style["text-align"] = "right"
  style["margin-bottom"] = "0.5em"

  print [[
    <td align=right>
      <table class="form-group" style="margin-bottom: 0;">
        <tr>
          <td style="vertical-align:top;">]]
      if extra.tformat ~= nil then
        value = prefsResolutionButtons(extra.tformat, value)
      end

      if extra.width == nil then
        if _input_type == "number" then
          style["width"] = "8em"
        else
          style["width"] = "18em"
        end
        style["margin-left"] = "auto"
      else
        style["width"] = "15em"
      end
      style["margin-left"] = "auto"

      style = table.merge(style, extra.style)
      attributes = table.merge(attributes, extra.attributes)

      print[[
          </td>
          <td style="vertical-align:top; padding-left: 2em;">
            <input id="id_input_]] print(key) print[[" type="]] print(input_type) print [[" class="form-control" ]] print(table.tconcat(attributes, "=", " ", nil, '"')) print[[ name="]] print(key) print [[" style="]] print(table.tconcat(style, ":", "; ", ";")) print[[" value="]] print(value..'"')
          if disableAutocomplete then print(" autocomplete=\"off\"") end
        print [[/>
          </td>
        </tr>
        <tr>
          <td colspan="2" style="padding:0;">
            <div class="help-block with-errors text-right" style="height:1em;"></div>
          </td>
        </tr>
      </table>
  </td></tr>
]]

end

function toggleTableButton(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field, redis_key, disabled)
  if(_POST[submit_field] ~= nil) then
    ntop.setPref(redis_key, _POST[submit_field])
    value = _POST[submit_field]
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
  print('<form method="post">\n<div class="btn-group btn-toggle">')
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
  if(_POST[submit_field] ~= nil) then
    if ( (value == nil) or (value ~= _POST[submit_field])) then
      ntop.setPref(redis_key, _POST[submit_field])
      value = _POST[submit_field]
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

    $("#]] print(submit_field) print [[_input").val("]] print(on_value) print[[").trigger('change');]]
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
    $("#]] print(submit_field) print [[_input").val("]]print(off_value) print[[").trigger('change');]]
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
  if(_POST[submit_field] ~= nil) then
    ntop.setPref(redis_key, _POST[submit_field])
    value = _POST[submit_field]
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
        local color
        if type(selected_color) == "table" then
          color = selected_color[nameCount]
        else
          color = selected_color
        end
        type_button = "btn-"..color.."  active"
      end
      print('<button id="id_'..array_values[nameCount]..'" value="'..array_values[nameCount]..'" type="button" class="btn btn-sm '..type_button..'" data-toggle="button">'..array_labels[nameCount]..'</button>\n')
    end
    print('</div>\n')
    print('<input type="hidden" id="id-toggle-'..submit_field..'" name="'..submit_field..'" value="'..value..'" />\n')
    print('<script>\n')
    for nameCount = 1, #array_labels do
      print('$("#id_'..array_values[nameCount]..'").click(function() {\n')
      print(' var field = $(\'#id-toggle-'..submit_field..'\');\n')
      print(' var oldval = field.val(); ')
      print(' field.val("'..array_values[nameCount]..'").trigger("change");\n')

      for indexLabel = 1, #array_labels do
        local color
        if type(selected_color) == "table" then
          color = selected_color[indexLabel]
        else
          color = selected_color
        end

        print[[ var class_]] print(array_values[indexLabel]) print[[ = document.getElementById("id_]] print(array_values[indexLabel]) print [[");
        class_]] print(array_values[indexLabel]) print[[.removeAttribute("class");]]
        if(array_values[indexLabel] == array_values[nameCount]) then
          print[[class_]] print(array_values[indexLabel]) print[[.setAttribute("class", "btn btn-sm btn-]]print(color) print[[ active");]]
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

  if(_POST[submit_field] ~= nil) then
    ntop.setCache(redis_key, _POST[submit_field])
    value = _POST[submit_field]
    notifyNtopng(submit_field, _POST[submit_field])
  else
    value = ntop.getCache(redis_key)
  end

  if value == "" or value == nil then
     value = "normal"
  end

  local logging_values = {"trace", "debug", "info", "normal", "warning", "error"}
  local color_map = {"default", "success", "info", "primary", "warning", "danger"}
  local logging_keys = {}
  local color = "default"

  for i,v in ipairs(logging_values) do logging_keys[i] = firstToUpper(v) end

  multipleTableButtonPrefs("Log level", "Choose the runtime logging level.",
          logging_keys, logging_values, value, color_map, submit_field, redis_key)

  return(value)
end
