--
-- (C) 2014-22 - ntop.org
--

local http_utils = {}

function http_utils.getResponseStatusCode(return_code)
  return(i18n("http_info.return_codes." .. tostring(return_code)) or return_code)
end

return http_utils
