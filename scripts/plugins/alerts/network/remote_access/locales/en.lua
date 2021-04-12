--
-- (C) 2020 - ntop.org
--

return {
   description = "Trigger an alert when a Remote Access Session is ended", -- 
   title = "Remote Access",

   alert = {
      title = "Remote Access",
      description = "Remote Access Ended and lasted for %{sec} sec",
   },
}
