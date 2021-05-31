--
-- (C) 2021 - ntop.org
--

local categories_utils = {}

-- NOTE: lists_utils.reloadLists() to apply changes

-- ##############################################

local function getCustomCategoryKey()
  return "ntopng.prefs.custom_categories_hosts"
end

-- ##############################################

function categories_utils.updateCustomCategoryHosts(category_id, hosts)
  local k = getCustomCategoryKey()

  if not table.empty(hosts) then
    ntop.setHashCache(k, tostring(category_id), table.concat(hosts, ","))
  else
    ntop.delHashCache(k, tostring(category_id))
  end

  return true
end

-- ##############################################

function categories_utils.addCustomCategoryHost(category_id, host)
  local category_hosts = categories_utils.getCustomCategoryHosts(category_id)

  -- Uniqueness Check
  for _, existing_host in pairs(category_hosts) do
    if existing_host == host then
      return false
    end
  end

  category_hosts[#category_hosts + 1] = host

  return categories_utils.updateCustomCategoryHosts(category_id, category_hosts)
end

-- ##############################################

function categories_utils.clearCustomCategoryHosts(category_id)
  local k = getCustomCategoryKey()
  ntop.delHashCache(k, category_id)
end

-- ##############################################

function categories_utils.getCustomCategoryHosts(category_id)
  local k = getCustomCategoryKey()
  local rv = ntop.getHashCache(k, tostring(category_id))

  if not isEmptyString(rv) then
    return split(rv, ",")
  end

  return {}
end

-- ##############################################

-- @brief Return a comma-separated list of protocols belonging to `cat_id`
--        If protocols are more than 5, an hyperlink with the whole list is shown.
function categories_utils.get_category_protocols_list(cat_id)
   local res = {}
   local max_protocols_in_list = 5

   for proto_name, proto_id in pairsByKeys(interface.getnDPIProtocols(cat_id), asc_insensitive) do
      res[#res + 1] = proto_name
   end

   local overflown_protos
   if #res > max_protocols_in_list then -- maximum number of entries shown
      overflown_protos = #res - max_protocols_in_list
   else
      max_protocols_in_list = #res
   end

   local res_str = table.concat(res, ', ', 1, max_protocols_in_list)

   if overflown_protos then
      res_str = string.format("%s <a href='%s/lua/admin/edit_categories.lua?tab=protocols&category=cat_%i'>%s</a>", res_str, ntop.getHttpPrefix(), cat_id, i18n("and_x_more", {num = overflown_protos}))
   end

   return res_str
end

-- ##############################################

function categories_utils.getAllCustomCategoryHosts()
  local k = getCustomCategoryKey()
  local cat_to_hosts = ntop.getHashAllCache(k) or {}
  local custum_categories = {}

  for cat, hosts_list in pairs(cat_to_hosts) do
    if tonumber(cat) ~= nil then
      custum_categories[tonumber(cat)] = split(hosts_list, ",")
    end
  end

  return custum_categories
end

-- ##############################################

function categories_utils.getSuggestedHostName(full_url)
  local parts = split(full_url, "%.")

  if #parts > 1 then
    if starts(parts[1], "http://") then
      parts[1] = string.sub(parts[1], 8)
    elseif starts(parts[1], "https://") then
      parts[1] = string.sub(parts[1], 9)
    end

    if parts[1] == "www" then
      table.remove(parts, 1)
    end

    local last_part = parts[#parts]
    if ends(last_part, "%") then
      -- fix
      parts[#parts] = string.sub(last_part, 1, #last_part-1)
    end

    if #parts > 2 and string.len(parts[2]) > 3 then
      -- E.g. static.somesite.net -> somesite.net
      return parts[#parts - 1] .. "." .. parts[#parts]
    elseif #parts > 3 then
      -- E.g. video.somesite.net.uk -> somesite.net.uk
      return parts[#parts - 2] .. "." .. parts[#parts - 1] .. "." .. parts[#parts]
    end

    return table.concat(parts, ".")
  end

  return full_url
end

-- ##############################################

return categories_utils
