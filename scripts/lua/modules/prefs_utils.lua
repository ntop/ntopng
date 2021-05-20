--
-- (C) 2014-21 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = false
local prefs = ntop.getPrefs()
local info = ntop.getInfo()
local menu_subpages = require "prefs_menu"
show_advanced_prefs_key = "ntopng.prefs.show_advanced_prefs"
local have_nedge = ntop.isnEdge()
local skip_redis = false

-- ############################################

--
-- A menu is a list of menu entries
-- A menu entry is composed by the following fields:
--    - id: the subpage id
--    - label: a label to be shown into the menu
--    - entries: a list subpages (see belo)
--
-- The following optional fields can be specified
--
--    - advanced: if true, it should be only shown when advanced settings are enabled
--    - pro_only: if true, it should be only shown in ntopng pro version
--    - enterprise_only: if true, it should be only shown in ntopng enterprise version
--    - disabled: if true, the entry is hidden
--
-- A subpage is composed by the following fields:
--    - title: the subpage title
--    - description: the subpage description
--    - hidden: (optional) if true, this subpage is hidden
--

-- ############################################

DNS_PRESETS = {
  {id="comodo_secure", label="Comodo Secure DNS", url="https://www.comodo.com/secure-dns/", primary_dns="8.26.56.26", secondary_dns="8.20.247.20"},
  {id="dyn_internet_guide", label="Dyn Internet Guide", url="http://dyn.com/labs/dyn-internet-guide/", primary_dns="216.146.35.35", secondary_dns="216.146.36.36"},
  --{id="fool_dns", label="FoolDNS", url="http://www.fooldns.com/fooldns-community/english-version/", primary_dns="87.118.111.215", secondary_dns="213.187.11.62"},
  --{id="greenteam_internet", label="GreenTeam Internet", url="http://members.greentm.co.uk/", primary_dns="81.218.119.11", secondary_dns="209.88.198.133"},
  {id="opendns", label="OpenDNS", url="https://www.opendns.com/", primary_dns="208.67.222.222", secondary_dns="208.67.220.220"},
  {id="opendns_familyshield", label="OpenDNS - FamilyShield", url="https://www.opendns.com/setupguide/?url=familyshield", primary_dns="208.67.222.123", secondary_dns="208.67.220.123", child_safe=true},
  {id="quad9_security", label="Quad 9: Security", url="https://quad9.net", primary_dns="9.9.9.9", secondary_dns=""},
  {id="google", label="Google DNS", url="https://developers.google.com/speed/public-dns", primary_dns="8.8.8.8", secondary_dns="8.8.4.4"},
  {id="cloudflare", label="Cloudflare DNS", url="https://www.cloudflare.com/learning/dns/what-is-1.1.1.1", primary_dns="1.1.1.1", secondary_dns="1.0.0.1"},
  {id="cleanbrowsing_security", label="CleanBrowsing - Security", url="https://cleanbrowsing.org",  primary_dns="185.228.168.9", secondary_dns="185.228.169.9"},
  {id="cleanbrwosing_adult", label="CleanBrowsing - Adult Filter", url="https://cleanbrowsing.org",  primary_dns="185.228.168.168", secondary_dns="185.228.169.168", child_safe=true},
  {id="yandex_safe", label="Yandex - Safe", url="https://dns.yandex.com", primary_dns="77.88.8.88", secondary_dns="77.88.8.2"},
  {id="yandex_family", label="Yandex - Family", url="https://dns.yandex.com", primary_dns="77.88.8.7", secondary_dns="77.88.8.3", child_safe=true},
}

function isSubpageAvailable(subpage, show_advanced_prefs)
  if show_advanced_prefs == nil then
    show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
  end
  if (subpage.hidden) or
     ((subpage.advanced) and (not show_advanced_prefs)) or
     ((subpage.pro_only) and (not ntop.isPro())) or
     (subpage.enterprise_l_only and (not info["version.enterprise_l_edition"])) or
     ((subpage.enterprise_only) and (not info["version.enterprise_edition"]) and (not have_nedge)) or
     (subpage.nedge_hidden) and (have_nedge) then
    return false
  end

  return true
end

function prefsGetActiveSubpage(show_advanced_prefs, tab)
  local subpage_active = nil

  for _, subpage in ipairs(menu_subpages) do
    if not isSubpageAvailable(subpage, show_advanced_prefs) then
      subpage.hidden = true

      if subpage.id == tab then
        -- will set to default
        tab = nil
      end
    elseif subpage.id == tab then
      subpage_active = subpage
    end
  end

  -- default subpage
  if isEmptyString(tab) then
    -- Pick the first available subpage
    for _, subpage in ipairs(menu_subpages) do
      if isSubpageAvailable(subpage, show_advanced_prefs) then
        subpage_active = subpage
        tab = subpage.id
        break
      end
    end
  end

  return subpage_active, tab
end

function printMenuSubpages(tab)

  for _, subpage in ipairs(menu_subpages) do
    if not subpage.hidden then
      local url = ternary(subpage.disabled, "#", ntop.getHttpPrefix() .. [[/lua/admin/prefs.lua?tab=]] .. (subpage.id))
      print[[<a href="]] print(url) print[[" class="list-group-item list-group-item-action]]

      if(tab == subpage.id) then
        print(" active")
      elseif subpage.disabled then
        print(" disabled")
      end

      print[[">]] print(subpage.label) print[[</a>]]
    end
  end
end

-- ############################################

--- Notify ntopng upon preference changes
function notifyNtopng(key, value)
    if key == nil then return end
    -- notify runtime ntopng configuration changes
    if string.starts(key, 'toggle_logging_level') then
        if verbose then io.write('notifying ntopng upon logging level pref change\n') end
        ntop.setLoggingLevel(value)
    end
end

-- ############################################

local options_script_loaded = false
local options_ctr = 0

function prefsResolutionButtons(fmt, value, fixed_id, format_spec, max_val)
  local ctrl_id
  if fixed_id ~= nil then
    ctrl_id = fixed_id
  else
    ctrl_id = "options_group_" .. options_ctr
    options_ctr = options_ctr + 1
  end

  local res = makeResolutionButtons(format_spec or FMT_TO_DATA_TIME, ctrl_id, fmt, value, {classes={"float-right"}}, max_val)

  res.value = truncate(res.value)

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

 if not skip_redis then
  if(_POST[key] ~= nil) then
    v_s = _POST[key]
    v = tonumber(v_s)

    v_cache = ntop.getPref(k)
    value = v_cache
    if ((v_cache==nil) or (v_s ~= v_cache)) then
      if(v ~= nil and (v > 0) and (v <= 86400)) then
        ntop.setPref(k, tostring(v))
        value = v
      elseif (v_s ~= nil) then
      	if(allowURLs or (extra.pattern == getURLPattern())) then
	        v_s = string.gsub(v_s, "ldaps:__", "ldaps://")
        	v_s = string.gsub(v_s, "ldap:__", "ldap://")
		v_s = string.gsub(v_s, "http:__", "http://")
		v_s = string.gsub(v_s, "https:__", "https://")
		v_s = string.gsub(v_s, "smtp:__", "smtp://")
		v_s = string.gsub(v_s, "smtps:__", "smtps://")
	end
        ntop.setPref(k, v_s)
        value = v_s
      end
      -- least but not last we asynchronously notify the runtime ntopng instance for changes
      notifyNtopng(key)
    end
  else
    local v_s = nil
    if not isEmptyString(prekey) then
      v_s = ntop.getPref(k)
    end
    value = v_s
    if((v_s==nil) or (v_s=="") or (v_s=="nil")) then
      value = default_value
      if not isEmptyString(prekey) and (ntop.getPref(k) ~= tostring(default_value)) then
        ntop.setPref(k, tostring(default_value))
        notifyNtopng(key)
      end
    end
  end
 else
   value = default_value
 end -- skip_redis

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

  if extra.minlength ~= nil then
    if extra.tformat ~= nil then
      attributes["data-minlength"] = extra.minlength
    else
      attributes["minlength"] = extra.minlength
    end
  end

  if extra.maxlength ~= nil then
    if extra.tformat ~= nil then
      attributes["data-maxlength"] = extra.maxlength
    else
      attributes["maxlength"] = extra.maxlength
    end
  end

  if extra.step ~= nil then
    if extra.tformat ~= nil then
      attributes["data-step"] = extra.step
    else
      attributes["step"] = extra.step
    end
  end

  if extra.disabled == true then attributes["disabled"] = "disabled" end
  if extra.required == true then attributes["required"] = "" end
  if extra.pattern ~= nil then attributes["pattern"] = extra.pattern end

  if (_input_type == "number") then
    attributes["required"] = "required"
  elseif (_input_type == "password") then
    -- disable chrome autocomplete
    attributes["autocomplete"] = "new-password"
  end

  local input_type = "text"
  if _input_type ~= nil then input_type = _input_type end
  print('<tr id="'..key..'" style="display: '..showEnabled..';"><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  local style = {}
  style["text-align"] = "right"
  style["margin-bottom"] = "0.5em"

  print [[
    <td align=right>
      <table class="table table-borderless form-group mb-3" style="margin-bottom: 0; min-width:22em;">
        <tr>
          <td width="100%;"></td>
          <td style="vertical-align:top;">]]
      if extra.tformat ~= nil then
        value = prefsResolutionButtons(extra.tformat, value, nil, extra.format_spec, extra.max)
      end

      if extra.width == nil then
        if _input_type == "number" then
          style["width"] = "8em"
        else
          style["width"] = "20em"
        end
        style["margin-left"] = "auto"
      else
        style["width"] = "15em"
      end
      style["margin-left"] = "auto"
      style["display"] = "inline"

      style = table.merge(style, extra.style)
      attributes = table.merge(attributes, extra.attributes)

      print[[
          </td>
          <td style="vertical-align:top; padding-left: 2em; white-space: nowrap;">
            <input id="id_input_]] print(key) print[[" type="]] print(input_type) print [[" class="form-control" ]] print(table.tconcat(attributes, "=", " ", nil, '"')) print[[ name="]] print(key) print [[" style="]] print(table.tconcat(style, ":", "; ", ";")) print[[" value="]] print(value..'"')
          if disableAutocomplete then print(" autocomplete=\"off\"") end
        print [[/>]] print(extra.append or "") print[[
          </td>
        </tr>
        <tr>
          <td colspan="3" style="padding:0;">
            <div class="help-block with-errors text-end" style="height:1em;"></div>
          </td>
        </tr>
      </table>
  </td></tr>
]]

end

-- ############################################

function prefsDropdownFieldPrefs(label, comment, key, values, default_value, showEnabled, extra)
  extra = extra or {}

  if extra.save_pref and table.len(_POST) > 0 and isEmptyString(_POST[key]) == false and isEmptyString(extra.pref_key) == false then
     ntop.setPref(extra.pref_key, _POST[key])
     default_value = _POST[key]
  end

  if ((showEnabled == nil) or (showEnabled == true)) then
    showEnabled = "table-row"
  else
    showEnabled = "none"
  end

  local attributes = {}

  if extra.disabled == true then attributes["disabled"] = "disabled" end
  if extra.required == true then attributes["required"] = "" end

  local input_type = "text"

  print('<tr id="'..key..'" style="display: '..showEnabled..';"><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  local style = {}
  style["text-align"] = "right"
  style["margin-bottom"] = "0.5em"

  print [[
    <td align=right>
      <table class="form-group mb-3" style="margin-bottom: 0; min-width:22em;">
        <tr>
          <td width="100%;"></td>]]

      if extra.width == nil then
	 style["width"] = "20em"
	 style["margin-left"] = "auto"
      else
        style["width"] = "15em"
      end
      style["margin-left"] = "auto"

      style = table.merge(style, extra.style)
      attributes = table.merge(attributes, extra.attributes)

      print[[
          <td style="vertical-align:top; padding-left: 2em;">
            <select id="id_input_]] print(key)  print [[" class="form-select" ]] print(table.tconcat(attributes, "=", " ", nil, '"')) print[[ name="]] print(key) print [[" style="]] print(table.tconcat(style, ":", "; ", ";")) print[[" value="]] print((value or '')..'"') print[[>]]
      if extra.keys == nil then
         for _, optname in pairs(values) do
	 print("<option " .. ternary(optname == default_value, "selected", "") .. ">"..optname.."</option>")
         end
      else
         for idx, _ in pairs(values) do
            local key = extra.keys[idx]
            local val = values[idx]
            print("<option value=".. key .." " .. ternary(key == default_value, "selected", "") .. ">"..val.."</option>")
         end
      end
      print[[
            </select>
          </td>
        </tr>
        <tr>
          <td colspan="3" style="padding:0;">
            <div class="help-block with-errors text-end" style="height:1em;"></div>
          </td>
        </tr>
      </table>
  </td></tr>
]]

end

-- ############################################

function prefsInformativeField(label, comment, showEnabled, extra)
  local extra = extra or {}
  extra["style"] = extra["style"] or {}
  extra["style"]["display"] = "none"
  prefsInputFieldPrefs(label, comment, "", "", "", nil, showEnabled, nil, nil, extra)
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
    on_active  = "btn-secondary"
    off_active = "btn-"..off_color.." active"
  else
    rev_value  = off_value
    on_active  = "btn-"..on_color.." active"
    off_active = "btn-secondary"
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

local function printNestedToSwitchLogic(nested_to_switch, submit_field)
  if((type(nested_to_switch) ~= "table") or (table.empty(nested_to_switch))) then
    return
  end

  for _, item in ipairs(nested_to_switch) do
    print[[
      if(($("#]] print(submit_field) print[[").val() == "]] print(item.pref_enabled_value or "1") print[[") &&
         ($("#]] print(item.parent) print[[").val() == "]] print(item.parent_enabled_value) print[["))
        $("#]] print(item.input) print[[").css("display", "table-row");
      else
        $("#]] print(item.input) print[[").css("display", "none");
    ]]
  end
end

local function toggleTableButtonPrefs(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field,
                                redis_key, default_value, disabled, elementToSwitch, hideOn, showElement, nested_to_switch)


 local value

 if not skip_redis then
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
 else
   value = default_value
 end

  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  -- Read it anyway to
  if(value ~= off_value) then
    value = on_value
  end

  local objRow = ""
  if ((showElement ~= nil) and (showElement == false)) then
    objRow = " style=\"display:none\""
  else
    objRow = " style=\"display:table-row\""
  end
  if(label ~= "") then print('<tr id="row_'..submit_field..'"'..objRow..'><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end

  print([[
    <div class="form-switch">
      <input ]].. (value == off_value and '' or 'checked') ..[[ type="checkbox" class="form-check-input" id="check-]].. submit_field ..[[">
      <label class="form-check-label" for="check-]].. submit_field ..[["></label>
      <input hidden id="input-]].. submit_field ..[[" name="]].. submit_field ..[[" value="]].. value ..[[">
  ]])
  print([[</div>]])
  if(label ~= "") then print('</td></tr>') end
  print('<script type="text/javascript">')

  print([[
    $("#check-]].. submit_field.. [[").change(function(e) {

      const value = $(this).is(":checked");

      if (value) {
        ]]..submit_field..[[_functionOn();
      }
      else {
        ]]..submit_field..[[_functionOff();
      }
    });
  ]])

  print[[function ]] print(submit_field) print [[_functionOn(){]]
    print([[$(`#input-]].. submit_field ..[[`).val("]].. on_value ..[[");]])

    if elementToSwitch ~= nil then
      for element = 1, #elementToSwitch do
        if ((hideOn == nil) or (hideOn == false)) then
          print('$("#'..elementToSwitch[element]..'").css("display","table-row");')
        else
          print('$("#'..elementToSwitch[element]..'").css("display","none");')
        end
      end
    end

    printNestedToSwitchLogic(nested_to_switch, "input-" .. submit_field)

    print[[
  }
  ]]
  print[[
  function ]] print(submit_field) print [[_functionOff(){]]

    print([[$(`#input-]].. submit_field ..[[`).val("]].. off_value ..[["); ]])

    if elementToSwitch ~= nil then
      for element = 1, #elementToSwitch do
        if ((hideOn == nil) or (hideOn == false)) then
          print('$("#'..elementToSwitch[element]..'").css("display","none");')
        else
          print('$("#'..elementToSwitch[element]..'").css("display","table-row");')
        end
      end
    end

    printNestedToSwitchLogic(nested_to_switch, "input-" .. submit_field)

    print [[
  }]]
  print('</script>\n')
  return(value)
end

local function get_pref_redis_key(options)
  local prefix = options.redis_prefix or "ntopng.prefs."
  return prefix .. ternary(options.pref ~= nil, options.pref, options.field)
end

function prefsToggleButton(subpage_active, params)
  local defaults = {
    to_switch = {},             -- a list of elements to be switched on or off
    on_text = "On",             -- The text when the button is on
    on_value = "1",             -- The value when the button is on
    on_class = "success",       -- The css class when the button is on
    off_text = "Off",           -- The text when the button is off
    off_value = "0",            -- The value when the button is off
    off_class = "danger",       -- The css class when the button is off
    reverse_switch = false,     -- If true, elements are hidden when the item is enabled
    nested_to_switch = {},      -- Similar to "to_switch" but for nested items
  }

  local options = table.merge(defaults, params)
  local redis_key = get_pref_redis_key(options)

  -- used for debugging purpose:
  -- if (subpage_active.entries[options.field] ~= nil) then
  --  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing entry '" .. options.field .. "' inside entries field")
  -- end

  return toggleTableButtonPrefs(params.title or subpage_active.entries[options.field].title,
    (params.description or subpage_active.entries[options.field].description) .. (params.content or subpage_active.entries[options.field].content or ""),
    options.on_text, options.on_value, options.on_class,
    options.off_text, options.off_value, options.off_class,
    options.field, redis_key,
    options.default, options.disabled, options.to_switch, options.reverse_switch, not options.hidden, options.nested_to_switch)
end

function multipleTableButtonPrefs(label, comment, array_labels, array_values, default_value, selected_color,
                                  submit_field, redis_key, disabled, elementToSwitch, showElementArray,
                                  nested_to_switch, showElement, initialValue, toggleElementArray)
  local value
  local disabled_attr

  if not skip_redis then
   if(_POST[submit_field] ~= nil) then
    local old_v = ntop.getPref(redis_key)
    value = _POST[submit_field]

    if old_v ~= _POST[submit_field] then
      ntop.setPref(redis_key, _POST[submit_field])
      notifyNtopng(submit_field)
    end
   else
    value = initialValue or ntop.getPref(redis_key)

    if(value == "") then
      if(default_value ~= nil) then
        ntop.setPref(redis_key, default_value)
        value = default_value
      end
    end
   end
  else
    value = default_value
  end

  if (disabled == true) then
    disabled = "disabled"
    disabled_attr = ' disabled="disabled"'
  else
    disabled = ""
    disabled_attr = ""
  end

  local objRow = ""
  if ((showElement ~= nil) and (showElement == false)) then
    objRow = " style=\"display:none\""
  else
    objRow = " style=\"display:table-row\""
  end
  if(value ~= nil) then
    if(label ~= "") then print('<tr id="row_'..submit_field..'"'..objRow..'><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
    print('<div class="btn-group" data-bs-toggle="buttons-radio" data-bs-toggle-name="'..submit_field..'">')

    for nameCount = 1, #array_labels do
      local type_button = "btn-secondary"
      if(value == array_values[nameCount]) then
        local color
        if type(selected_color) == "table" then
          color = selected_color[nameCount]
        else
          color = selected_color
        end
        type_button = "btn-"..color.."  active"
      end
      print('<button id="id_'..submit_field..'_'..array_values[nameCount]..'" value="'..array_values[nameCount]..'" type="button" class="btn btn-sm '..type_button..' ' .. disabled .. '"'.. disabled_attr ..' data-bs-toggle="button">'..array_labels[nameCount]..'</button>\n')
    end
    print('</div>\n')
    print('<input type="hidden" id="id-toggle-'..submit_field..'" name="'..submit_field..'" value="'..value..'" />\n')
    print('<script>\n')

    -- showElementArray can be either:
    --  1. a simple table (e.g. {true, false}): it affects all the elements in elementToSwitch
    --  2. a nested table (e.g. {{true, false}, {false, false}}): each element in the table
    --     affects the corresponding element in the elementToSwitch (e.g. {true, false} affects
    --     elementToSwitch[1], whereas {false, false} affects elementToSwitch[2])
    if(showElementArray and (type(showElementArray[1]) ~= "table")) then
      -- This is simple table (case 1.) above, convert it to case 2 to handle
      -- both cases consinstenly below.
      showElementArray = {showElementArray, }
    end

    for nameCount = 1, #array_labels do
      print('$("#id_'..submit_field..'_'..array_values[nameCount]..'").click(function() {\n')
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

        print[[ var class_]] print(array_values[indexLabel]) print[[ = document.getElementById("id_]] print(submit_field..'_') print(array_values[indexLabel]) print [[");
        class_]] print(array_values[indexLabel]) print[[.removeAttribute("class");]]
        if(array_values[indexLabel] == array_values[nameCount]) then
          print[[class_]] print(array_values[indexLabel]) print[[.setAttribute("class", "btn btn-sm btn-]]print(color) print[[ active");]]
        else
          print[[class_]] print(array_values[indexLabel]) print[[.setAttribute("class", "btn btn-sm btn-secondary");]]
        end
      end

      -- Show/Hide all the elementToSwitch items at once
      if (showElementArray ~= nil) then
        for indexSwitch = 1, #showElementArray[1] do
          if (indexSwitch == nameCount) then
            if elementToSwitch ~= nil then
              for element = 1, #elementToSwitch do
                -- Try to get the element-specific configuration if available,
                -- otherwise fallback to the default configuration (at index 1)
                local to_apply = showElementArray[element] or showElementArray[1]

                if (to_apply[indexSwitch] == true) then
                  -- NOTE: this is executed into the js change callback
                  print('$("#'..elementToSwitch[element]..'").css("display","table-row");\n')
                else
                  -- NOTE: this is executed into the js change callback
                  print('$("#'..elementToSwitch[element]..'").css("display","none");\n')
                end
              end
            end
          end
        end
      -- Show/Hide all the elementToSwitch selectively
      elseif (toggleElementArray ~= nil) then
        for indexSwitch = 1, #toggleElementArray do
          if (indexSwitch == nameCount) then
            if elementToSwitch ~= nil then
              for element = 1, #elementToSwitch do
                if (toggleElementArray[indexSwitch][element] == true) then
                  -- NOTE: this is executed into the js change callback
                  print('$("#'..elementToSwitch[element]..'").css("display","table-row");\n')
                else
                  -- NOTE: this is executed into the js change callback
                  print('$("#'..elementToSwitch[element]..'").css("display","none");\n')
                end
              end
            end
          end
        end
      end

      printNestedToSwitchLogic(nested_to_switch, "id-toggle-" .. submit_field)

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
  local color_map = {"secondary", "success", "info", "primary", "warning", "danger"}
  local logging_keys = {}
  local color = "secondary"

  for i,v in ipairs(logging_values) do logging_keys[i] = firstToUpper(v) end

  multipleTableButtonPrefs("Log level", "Choose the runtime logging level.",
          logging_keys, logging_values, value, color_map, submit_field, redis_key)

  return(value)
end

function printPageSection(section_name)
   print('<thead class="table-primary"><tr><th colspan=2 class="info">'..section_name..'</th></tr></thead>')
end

function printSaveButton(some_content)
  print('<tr><td colspan=2 style="text-align:right;">' .. (some_content or "") .. '<button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></td></tr>')
end

function prefsSkipRedis(skip)
  skip_redis = skip
end
