--
-- (C) 2014-22 - ntop.org
--

local dns_utils = {}

function dns_utils.getResponseStatusCode(return_code)
  return(i18n("dns_info.return_codes." .. tostring(return_code)) or return_code)
end

function dns_utils.getQueryType(query_type)
  return(i18n("dns_info.query_types." .. tostring(query_type)) or query_type)
end

return dns_utils
