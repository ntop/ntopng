--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
local info = ntop.getInfo()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local code_editor = {}
local os_utils = require "os_utils"

-- ################################################################

-- Given absolute plugin and plugin file paths, this function strips out their absolute parts
-- to create pseudo-paths that are safe to be passed as parameters to an url
local function file_url(plugin_path, plugin_file_path)
   plugin_path = string.sub(plugin_path, string.len(dirs.scriptdir) + 1)
   plugin_file_path = string.sub(plugin_file_path, string.len(dirs.scriptdir) + 1)
   return string.format("%s/lua/code_viewer.lua?plugin_file_path=%s&plugin_path=%s", ntop.getHttpPrefix(), plugin_file_path, plugin_path)
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
   local plugin_contents = ntop.readdir(subdir_path)

   for plugin_content, _ in pairsByKeys(plugin_contents) do
      if plugin_content then
	 local subdir_path = os_utils.fixPath(string.format("%s/%s", subdir_path, plugin_content))

	 if ntop.isdir(subdir_path) then
	    -- If this is a directory, and the recursion level is 1, then a dropdown-header is printed.
	    -- Headers are not printed at every recursion level to keep the dropdown as simple as possible
	    if subdir_level == 1 then
	       print[[
  <h6 class="dropdown-header">]] print(plugin_content) print[[</h6>
]]
	       -- The dropdown-header is also propagated
	       subdir_header = subdir_path
	    end

	    -- Do the actual recursive call
	    plugin_subdir_files_dropdown(plugin_file_path, plugin_path, subdir_path, subdir_level + 1, subdir_header)
	 elseif subdir_level > 1 then
	    -- If this is a file and is not on the root (files in the root are not shown in this function)...
	    local label = subdir_path:gsub(subdir_header, '')
	    label = label:gsub('^/+', '')

	    local active = ''
	    if string.ends(subdir_path, plugin_file_path) then
	       active = 'active'
	    end

	    print[[
  <a class="dropdown-item ]] print(active) print[[" href="]] print(file_url(plugin_path, subdir_path)) print[[">]] print(label) print[[</a>
]]
	 end
      end
   end
end

-- ################################################################

local function plugin_files_dropdown(plugin_file_path, plugin_path)
   print[[
<div class="dropdown">
  <button class="btn btn-secondary dropdown-toggle" type="button" id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
    ]] print(i18n("plugin_contents")) print[[
  </button>
  <div class="dropdown-menu scrollable-dropdown" aria-labelledby="dropdownMenuButton">
  <a class="dropdown-item ]] print(ternary(string.ends(plugin_file_path, 'manifest.lua'), "active", '')) print[[" href="]] print(file_url(plugin_path, os_utils.fixPath(string.format("%s/%s", plugin_path, 'manifest.lua')))) print[[">manifest.lua</a>
]]

   plugin_subdir_files_dropdown(plugin_file_path, plugin_path, plugin_path, 1)

   print[[

  </div>
</div>
]]
end

-- ################################################################

function code_editor.editor(plugin_file_path, plugin_path)
   local plugin_file_url

   print [[<H3>]] print(i18n("plugin_browser", {plugin_name = plugin_path})) print [[</H3>]]

   if starts(plugin_file_path, "/plugins/") then
      plugin_file_url = string.gsub(plugin_file_path, "/plugins/", "/plugins-src/")
   end

   -- Sanity check, never go outside the plugins directory
   if starts(plugin_path, "/plugins/") then
      plugin_path = os_utils.fixPath(string.format("%s/%s", dirs.scriptdir, plugin_path))
   else
      plugin_path = nil
   end

   plugin_files_dropdown(plugin_file_path, plugin_path)

   print[[
<br>
<p><i class="fas fa-lg fa-binoculars"></i> ]] print(plugin_file_path) print [[</p>
<p>
<script>var require = { paths: { 'vs': ']] print(ntop.getHttpPrefix()) print[[/monaco-editor/min/vs' } };</script>
<script src="]] print(ntop.getHttpPrefix()) print[[/monaco-editor/min/vs/loader.js"></script>
<script src="]] print(ntop.getHttpPrefix()) print[[/monaco-editor/min/vs/editor/editor.main.nls.js"></script>
<script src="]] print(ntop.getHttpPrefix()) print[[/monaco-editor/min/vs/editor/editor.main.js"></script>


<div id="container" style="width:1200px;height:600px;border:1px solid grey"></div>
<script>

function getSourceFile(theURL) {
  var strReturn = "";

  jQuery.ajax({
    url: theURL,
    success: function(html) {
      strReturn = html;
    },
    async:false
  });

  return strReturn;
}

var src = "";
]]

   if plugin_file_url then
      print [[
   src = getSourceFile(']] print(plugin_file_url) print[[')
]]
   end

   print [[
console.log(src);
    require.config({ paths: { 'vs': ']] print(ntop.getHttpPrefix()) print[[/monaco-editor/min/vs' }});
    require(['vs/editor/editor.main'], function() {
	var editor = monaco.editor.create(document.getElementById('container'), {
	    value: src,
	    readOnly: true,
	    language: 'lua'
	});
    });
</script>


]]
end

-- #################################

return code_editor
