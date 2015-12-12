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

function prefsInputField(label, comment, key, value)
  if(_GET[key] ~= nil) then
    k = "ntopng.prefs."..key
    v_s = _GET[key]
    v = tonumber(v_s)
    if(v ~= nil and (v > 0) and (v < 86400)) then
      -- print(k.."="..v)
      ntop.setCache(k, tostring(v))
      value = v
    elseif (v_s ~= nil) then
      ntop.setCache(k, v_s)
      value = v_s
    end
    -- least but not last we ascynchronously notify the runtime ntopng instance for changes
    notifyNtopng(key)
  end

  print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  print [[
	   <td class="input-group col-lg-3" align=right><form class="navbar-form navbar-right">]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[
 <div class="input-group" >
      <div >
        <input type="text" class="form-control" name="]] print(key) print [[" value="]] print(value.."") print [[">
      <span class="input-group-btn">
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
  print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
  print('<input type=hidden name='..submit_field..' value='..rev_value..'>\n')
  print('<button type="submit" '..disabled..' class="btn btn-sm  '..on_active..'">'..on_label..'</button>')
  print('<button '..disabled..' class="btn btn-sm '..off_active..'">'..off_label..'</button></div>\n')
  print('</form>\n')
  if(label ~= "") then print('</td></tr>') end

  return(value)
end

