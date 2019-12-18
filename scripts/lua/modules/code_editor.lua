--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
local info = ntop.getInfo()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local code_editor = {}

-- ################################################################

function code_editor.editor(scriptname)
   
if(starts(scriptname, "/plugins/")) then
   lua_script_url = string.gsub(scriptname, "/plugins/", "/plugins-src/")
else
   lua_script_url = ""
end

print [[
<p>
<H3><i class="fas fa-lg fa-binoculars"></i> ]] print(scriptname) print [[</H3>
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

if(lua_script_url ~= "") then
  print [[
   src = getSourceFile(']] print(lua_script_url) print[[')
]]
end

print [[
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
