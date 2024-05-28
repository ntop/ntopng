#ifndef _SERVER_PORTS_CONTACTS_ALERT_H_
#define _SERVER_PORTS_CONTACTS_ALERT_H_

#include "ntop_includes.h"

class ServerPortsContactsAlert : public HostAlert {
  private:
  u_int16_t server_port;
  u_int16_t app_proto;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  ServerPortsContactsAlert(HostCheck* c, Host* f, risk_percentage cli_pctg,
                         u_int16_t _server_port, u_int16_t _app_proto);
  ~ServerPortsContactsAlert() {}

  static HostAlertType getClassType() {
    return {host_alert_server_ports_contacts, alert_category_security};
  }
  HostAlertType getAlertType() const { return getClassType(); }
  u_int8_t getAlertScore() const { return SCORE_LEVEL_WARNING; };
};

#endif /* _SERVER_PORTS_CONTACTS_ALERT_H_ */