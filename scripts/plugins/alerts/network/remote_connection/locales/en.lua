--
-- (C) 2020 - ntop.org
--

return {
   description = "Trigger an alert when an host has 1 or more Remote Connection Sessions open", -- 
   title = "Remote Connection",

   alert = {
      title = "Remote Connection",
      description = "The Host: [%{host}] currently is taking part to %{connections} flows with a remote access protocol",
   },
}
