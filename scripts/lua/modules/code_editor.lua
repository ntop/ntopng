--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
local info = ntop.getInfo()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local code_editor = {}
local os_utils = require "os_utils"
local template_utils = require("template_utils")

-- ################################################################

-- Given absolute plugin and plugin file paths, this function strips out their absolute parts
-- to create pseudo-paths that are safe to be passed as parameters to an url
local function file_url(plugin_path, plugin_file_path)
   plugin_path = string.sub(plugin_path, string.len(dirs.scriptdir) + 1)
   plugin_file_path = string.sub(plugin_file_path, string.len(dirs.scriptdir) + 1)
   return string.format("%s/lua/code_viewer.lua?plugin_file_path=%s&plugin_path=%s", ntop.getHttpPrefix(), plugin_file_path, plugin_path)
end

-- ################################################################

-- Flat the subdirs hierarchy in one array
local function flat_subdirs(subdir, elements)

   if (subdir.subdirs == nil) then
      table.insert(elements, { title = subdir.title, active = subdir.active, href = subdir.href, })
      return
   end

   for _, dir in ipairs(subdir.subdirs) do
      flat_subdirs(dir, elements)
   end
end

-- ################################################################

-- This recursive function is in charge of printing dropdown menu entries for all the plugin files (except manifest.lua in the root)
-- All the plugin subdirectories are navigated recursively, and their files printed as menu entries.
-- @param string plugin_file_path The path to the plugin file as received from the original caller (never changes during recursion)
-- @param string plugin_path The path to the plugin as received from the original caller (never changes during recursion)
-- @param string subdir_path The path to the current working directory (changes during recursion)
-- @param string subdir_level The current level of recursion (starts from 1)
-- @param string subdir_header The header printed as dropdown-header for the current subdir_path
local function plugin_subdir_files_dropdown(plugin_file_path, plugin_path, subdir_path, subdir_level, subdir_header)

   local tree = {}
   local plugin_contents = ntop.readdir(subdir_path)

   for plugin_content, _ in pairsByKeys(plugin_contents) do

      if plugin_content then

         local leaf = {}
         local subdir_path = os_utils.fixPath(string.format("%s/%s", subdir_path, plugin_content))

         if ntop.isdir(subdir_path) then
            -- If this is a directory, and the recursion level is 1, then a dropdown-header is printed.
            -- Headers are not printed at every recursion level to keep the dropdown as simple as possible
            if subdir_level == 1 then
               leaf = { header = plugin_content }
               -- The dropdown-header is also propagated
               subdir_header = subdir_path
            end

            -- Do the actual recursive call
            leaf.subdirs = plugin_subdir_files_dropdown(plugin_file_path, plugin_path, subdir_path, subdir_level + 1, subdir_header)
            tree[#tree+1] = leaf

         elseif subdir_level > 1 then
            -- If this is a file and is not on the root (files in the root are not shown in this function)...
            local label = subdir_path:gsub(subdir_header, '')
            label = label:gsub('^/+', '')

            leaf.active = (string.ends(subdir_path, plugin_file_path))
            leaf.href = file_url(plugin_path, subdir_path)
            leaf.title = label
            tree[#tree+1] = leaf
         end
      end
   end

   return tree
end

-- ################################################################

local function plugin_files_dropdown(plugin_file_path, plugin_path)

   return {
      class_dropdown_item = ternary(string.ends(plugin_file_path, 'manifest.lua'), "active", ''),
      href_dropdown_item = file_url(plugin_path, os_utils.fixPath(string.format("%s/%s", plugin_path, 'manifest.lua'))),
      elements = plugin_subdir_files_dropdown(plugin_file_path, plugin_path, plugin_path, 1)
   }
end

-- ################################################################

function code_editor.editor(plugin_file_path, plugin_path, referarl_script_page)

   local plugin_file_url

   if starts(plugin_file_path, "/plugins/") then
      plugin_file_url = string.gsub(plugin_file_path, "/plugins/", "/plugins-src/")
   end

   -- Sanity check, never go outside the plugins directory
   if starts(plugin_path, "/plugins/") then
      plugin_path = os_utils.fixPath(string.format("%s/%s", dirs.scriptdir, plugin_path))
   else
      plugin_path = nil
   end

   local context = {
      monaco_editor = {
         plugin_file_url = plugin_file_url,
         plugin_file_path = plugin_file_path,
         plugin_path = plugin_path,
         referarl_script_page = referarl_script_page,
         dropdown = plugin_files_dropdown(plugin_file_path, plugin_path)
      }
   }

   -- Flat the subdirs hierarchy
   for _, tree in ipairs(context.monaco_editor.dropdown.elements) do

      local flatten = {}
      for _, dir in ipairs(tree.subdirs) do
         flat_subdirs(dir, flatten)
      end
      tree.flatten_subdirs = flatten
   end

   print(template_utils.gen('pages/components/monaco-editor.template', context))
end

-- #################################

return code_editor