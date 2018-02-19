-- A script to sort a localization file

local persistance = require("persistence")
local community_base_path = "../../scripts/locales"
local pro_base_path = "../../pro/scripts/locales"

if (#arg ~= 1) and (#arg ~= 2) then
  print([[Usage: lua ]] .. arg[0] .. [[ localization_code [merge_strings]

The merge_strings parameter can be used to load additional strings to merge into
the localization. The strings should be a list similar to this:

  lang.manage_users.add_new_user = "Add New User"
  lang.manage_users.expires_after = "Expires after"

Example: ]] .. arg[0] .. [[ en"]])

  os.exit(1)
end

local lang_code = arg[1]
local merge_strings_file = arg[2]

local base_path

local function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

if file_exists(community_base_path.."/"..lang_code..".lua") then
  base_path = community_base_path
else
  base_path = pro_base_path
end

package.path = base_path .. "/?.lua;" .. package.path
local lang_file = base_path .. "/" .. lang_code .. ".lua"

local lang = require(lang_code)

if merge_strings_file then
  local f = assert(io.open(merge_strings_file, "r"))
  local lines = f:read("*all")
  f:close()

  for line in lines:gmatch("[^\r\n]+") do
    local k, v = line:gmatch("%s*([^%s]+)%s*=%s*\"([^\"]+)\"")()
    print(k)

    -- merge
    if (k ~= nil) and (v ~= nil) then
      local t = lang
      local prev_t = t
      local prev_k = nil

      for part in k:gmatch("[^%.]+") do
        part = part:gmatch("%[\"([^\"]+)\"%]")() or part

        if not ((t == lang) and (part == "lang")) then
          if t[part] == nil then
            t[part] = {}
          end

          prev_t = t
          t = t[part]
          prev_k = part
        end
      end

      if prev_k ~= nil then
        prev_t[prev_k] = v
      end
    end
  end

  
end

persistence.store(lang_file, lang)
