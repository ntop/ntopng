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
    end
end

-- ############################################
-- Runtime preference

function prefsInputField(label, comment, key, value, _input_type)
  if(_GET[key] ~= nil) then
    k = "ntopng.prefs."..key
    v_s = _GET[key]
    v = tonumber(v_s)
    if(v ~= nil and (v > 0) and (v <= 86400)) then
      ntop.setCache(k, tostring(v))
      value = v
    elseif (v_s ~= nil) then
      ntop.setCache(k, v_s)
      value = v_s
    end
    -- least but not last we ascynchronously notify the runtime ntopng instance for changes
    notifyNtopng(key)
  end
  local input_type = "text"
  if _input_type ~= nil then input_type = _input_type end
  print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  print [[
	   <td class="input-group col-lg-3" align=right><form class="navbar-form navbar-right">]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[
 <div class="input-group" >
      <div >
      <span class="input-group-btn">
        <input type="]] print(input_type) print [[" class="form-control" name="]] print(key) print [[" value="]] print(value.."") print [[">

        <button class="btn btn-default" type="submit">Save</button>
      </span>
      </div>
    </div><!-- /input-group -->
</form></td></tr>
]]

end

function toggleTableButton(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field, redis_key, disabled)
  if(_GET[submit_field] ~= nil) then
    ntop.setCache(redis_key, _GET[submit_field])
    value = _GET[submit_field]
    notifyNtopng(submit_field)
  else
    value = ntop.getCache(redis_key)
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
  print('<input type=hidden name='..submit_field..' value='..rev_value..'>\n')
  print('</form>\n')
  if(label ~= "") then print('</td></tr>') end

  return(value)
end

function multipleTableButton(label, comment, array_labels, array_values, default_value, selected_color, submit_field, redis_key, disabled)
  if(_GET[submit_field] ~= nil) then
    ntop.setCache(redis_key, _GET[submit_field])
    value = _GET[submit_field]
    notifyNtopng(submit_field)
  else
    value = ntop.getCache(redis_key)
    if(value == "") then
      if(default_value ~= nil) then
        ntop.setCache(redis_key, default_value)
        value = default_value
      end
    end
  end

  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  if(value ~= nil) then
    if(label ~= "") then print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
    print('<form id="form-'..submit_field..'">\n<div class="btn-group" data-toggle="buttons-radio" data-toggle-name="'..submit_field..'">')

    for nameCount = 1, #array_labels do
      local type_button = "btn-default"
      if(value == array_values[nameCount]) then
        type_button = "btn-"..selected_color.."  active"
      end
      print('<button id="id_'..array_values[nameCount]..'" value="'..array_values[nameCount]..'" type="button" class="btn btn-sm '..type_button..'" data-toggle="button">'..array_labels[nameCount]..'</button>\n')
    end
    print('</div>\n')
    print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
    print('<input type="hidden" id="id-toggle-'..submit_field..'" name="'..submit_field..'" value="'..value..'" />\n')
    print('</form>\n')
    print('<script>\n')
    for nameCount = 1, #array_labels do

    print('$("#id_'..array_values[nameCount]..'").click(function() {\n')
    print('  $(\'#id-toggle-'..submit_field..'\').val("'..array_values[nameCount]..'");\n')
    print('  $(\'#form-'..submit_field..'\').submit();\n')
    print('});\n')

    end
    print('</script>\n')
    if(label ~= "") then print('</td></tr>') end
  end

  return(value)
end

function prefsInputFieldWithParamCheck(label, comment, pre_key, key, value, _input_type, js_body_funtion_check)
  if(_GET[key] ~= nil) then
    k = pre_key.."."..key
    v_s = _GET[key]
    v = tonumber(v_s)
    if(v ~= nil and (v > 0) and (v <= 86400)) then
      ntop.setCache(k, tostring(v))
      value = v
    elseif (v_s ~= nil) then
      -- fix for ldap preference
      v_s = string.gsub(v_s, "ldap:__", "ldap://")
      ntop.setCache(k, v_s)
      value = v_s
    end
    -- least but not last we ascynchronously notify the runtime ntopng instance for changes
    notifyNtopng(key)
  end
  local input_type = "text"
  if _input_type ~= nil then input_type = _input_type end
  print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  print [[
	   <td class="input-group col-lg-3" align=right><form id="form-]] print(key) print [[" class="navbar-form navbar-right">]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[
 <div class="input-group" >
      <div >
      <span class="input-group-btn">
        <input id="input_]] print(key) print [[" type="]] print(input_type) print [[" class="form-control" name="]] print(key) print [[" value="]] print(value.."") print [[">

        <button id="button_]] print(key) print [[" class="btn btn-default" type="button">Save</button>
      </span>
      </div>
    </div><!-- /input-group -->
    <script>
]]

  print('function check_field_'..key..'(field){\n')
if (js_body_funtion_check ~= nil and js_body_funtion_check ~= "") then
  print(js_body_funtion_check)
else
  print("return \"\";\n")
end
  print('}\n')

  print('$("#button_'..key..'").click(function() {\n')
  print('  var result = check_field_'..key..'($("#input_'..key..'").val());\n')
  print('  if(result!=""){\n')
  print('    alert(result);\n')
  print('    return;\n')
  print('  }\n')
  print('  $(\'#form-'..key..'\').submit();\n')
  print('});\n')

print [[    </script>
</form>
</td></tr>
]]

end
