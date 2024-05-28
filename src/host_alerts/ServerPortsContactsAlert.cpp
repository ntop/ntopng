#include "host_alerts_includes.h"

/* ***************************************************** */

ServerPortsContactsAlert::ServerPortsContactsAlert(
    HostCheck* c, Host* f, risk_percentage cli_pctg, 
    u_int16_t _server_port, u_int16_t _app_proto)
    : HostAlert(c, f, cli_pctg) {
  server_port = _server_port;
  app_proto = _app_proto;
}

/* ***************************************************** */

ndpi_serializer* ServerPortsContactsAlert::getAlertJSON(
    ndpi_serializer* serializer) {
  if (serializer == NULL) return NULL;

  ndpi_serialize_string_uint64(serializer, "value", server_port);
  ndpi_serialize_string_uint64(serializer, "threshold",
                               app_proto);

  return serializer;
}

/* ***************************************************** */
