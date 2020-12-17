--
-- (C) 2020 - ntop.org
--

return {
   alert_format = "Format",
   content = "Content",
   description = "Host, Port and Protocol should be specified for remote syslog servers only.",
   description_ecs = "ECS (Elasticsearch Common Schema) format is documented <a href='%{url}' target='_blank'>here</a> <i class='%{icon}'></i>.",
   description_raw_json = "Raw JSON format is self-documented in the <a href='%{url}' target='_blank'>code</a> <i class='%{icon}'></i> and is meant to be used only by programmers who intend to programmatically process notifications.",
   host = "Host",
   port = "Port",
   protocol = "Protocol",
   text = "Text",
   validation = {
      invalid_host = "Invalid Syslog host.",
      invalid_port = "Invalid Syslog port.",
   },
}
