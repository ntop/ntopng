--
-- (C) 2020 - ntop.org
--

--
-- This module implements defines the email endpoint
--

local endpoint = {}

-- #################################################################

endpoint = {
   key = "email",
   conf_params = {
      { param_name = "smtp_server_name", param_type = "text" },
      { param_name = "sender", param_type = "email" },
      { param_name = "username", param_type = "text", optional = true },
      { param_name = "password", param_type = "password", optional = true },
   },
   recipient_params = {
      { param_name = "to", param_type = "email" },
      { param_name = "cc", param_type = "email", optional = true },
   }
}

-- #################################################################

return endpoint
