--
-- (C) 2014-24 - ntop.org
--
--

-- IMPORTANT: keep this file without require, otherwise it might cause circular dependencies
-- ##############################################

function noHtml(s)
   if s == nil then
       return nil
   end

   local gsub, char = string.gsub, string.char
   local entityMap = {
       lt = "<",
       gt = ">",
       amp = "&",
       quot = '"',
       apos = "'"
   }
   local entitySwap = function(orig, n, s)
       return (n == '' and entityMap[s]) or (n == "#" and tonumber(s)) and string.char(s) or
                  (n == "#x" and tonumber(s, 16)) and string.char(tonumber(s, 16)) or orig
   end

   local function unescape(str)
       return (gsub(str, '(&(#?x?)([%d%a]+);)', entitySwap))
   end

   local cleaned = s:gsub("<[aA] .->(.-)</[aA]>", "%1"):gsub("<abbr .->(.-)</abbr>", "%1"):gsub("<span .->(.-)</span>",
       "%1"):gsub("<button .->(.-)</button>", "%1"):gsub("%s*<[iI].->(.-)</[iI]>", "%1"):gsub("<.->(.-)</.->", "%1") -- note: keep as last as this does not handle nested tags
   :gsub("^%s*(.-)%s*$", "%1"):gsub('&nbsp;', " ")

   return unescape(cleaned)
end