--
-- (C) 2014-26 - ntop.org
--
--

-- IMPORTANT: keep this file without require, otherwise it might cause circular dependencies
-- ##############################################

-- Constants and helpers are created once, not at every call (these functions are called for every cell of the tables)
local noHtmlEntityMap = {
   lt = "<",
   gt = ">",
   amp = "&",
   quot = '"',
   apos = "'"
}

local function noHtmlEntitySwap(orig, n, s)
   return (n == '' and noHtmlEntityMap[s]) or (n == "#" and tonumber(s)) and string.char(s) or
              (n == "#x" and tonumber(s, 16)) and string.char(tonumber(s, 16)) or orig
end

function noHtml(s)
   if s == nil then
       return nil
   end

   local cleaned = s:gsub("<[aA] .->(.-)</[aA]>", "%1"):gsub("<abbr .->(.-)</abbr>", "%1"):gsub("<span .->(.-)</span>",
       "%1"):gsub("<button .->(.-)</button>", "%1"):gsub("%s*<[iI].->(.-)</[iI]>", "%1"):gsub("<.->(.-)</.->", "%1") -- note: keep as last as this does not handle nested tags
   :gsub("^%s*(.-)%s*$", "%1"):gsub('&nbsp;', " ")

   return (string.gsub(cleaned, '(&(#?x?)([%d%a]+);)', noHtmlEntitySwap))
end

-- ##############################################

-- @brief Encode the HTML entities in a string.
--        Useful when printing dissected data which may result in XSS
--        e.g., curl -u admin:admin1 "http://devel:3000/</a><script>alert(1);</script><a>"
-- @param s The string to escape.
-- @return The string with HTML entities properly escaped
local safeHtmlReplacements = {
   ["&"] = "&amp;",
   ["<"] = "&lt;",
   [">"] = "&gt;",
   ['"'] = "&quot;",
   ["'"] = "&#39;",
   ["/"] = "&#47;"
}

function safeHtml(s)
   if not s then
      return ''
   end

   local ret = string.gsub(s, "[\">/<'&]", safeHtmlReplacements)

   return ret
end

-- ##############################################

local score_to_severity_cache = {}

function map_score_to_severity(score)
   score = score or 0

   local severity = score_to_severity_cache[score]

   if severity == nil then
      severity = ntop.mapScoreToSeverity(score)
      score_to_severity_cache[score] = severity
   end

   return severity
end

