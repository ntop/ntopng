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
      { param_name = "smtp_server", param_type = "text", regex="[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\\.[a-zA-Z]{2,})+" },
      { param_name = "email_sender", param_type = "email" },
      { param_name = "smtp_username", param_type = "text", optional = true },
      { param_name = "smtp_password", param_type = "password", optional = true },
   },
   recipient_params = {
      { param_name = "email_recipient", param_type = "email" },
      { param_name = "cc", param_type = "email", optional = true },
   }
}

-- #################################################################

return endpoint
