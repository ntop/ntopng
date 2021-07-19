#include "host_alerts_includes.h"

/* ***************************************************** */

CountriesContactsAlert::CountriesContactsAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _countries_contacts, u_int64_t _countries_contacts_threshold) : HostAlert(c, f, cli_pctg) {
    countries_contacts = _countries_contacts;
    countries_contacts_threshold = _countries_contacts_threshold;
}

/* ***************************************************** */

ndpi_serializer* CountriesContactsAlert::getAlertJSON(ndpi_serializer* serializer) {
  if(serializer == NULL)
    return NULL;

  ndpi_serialize_string_uint64(serializer, "value", countries_contacts);
  ndpi_serialize_string_uint64(serializer, "threshold", countries_contacts_threshold);
  
  return serializer;
}

/* ***************************************************** */


