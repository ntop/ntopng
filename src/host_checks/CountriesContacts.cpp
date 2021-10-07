#include "ntop_includes.h"
#include "host_checks_includes.h"

CountriesContacts::CountriesContacts() : HostCheck(ntopng_edition_community, false /* All interfaces */, true /* Exclude for nEdge */, false /* NOT only for nEdge */) {
    countries_contacts_threshold = (u_int8_t)-1;
}

void CountriesContacts::periodicUpdate(Host *h, HostAlert *engaged_alert) {
    HostAlert *alert = engaged_alert;
    u_int8_t contacted_countries = 0;

    if ((contacted_countries = getContactedCountries(h)) > countries_contacts_threshold) {
        if (!alert) alert = allocAlert(this, h, CLIENT_FAIR_RISK_PERCENTAGE, contacted_countries, countries_contacts_threshold);
        if (alert) h->triggerAlert(alert);
    }
}

bool CountriesContacts::loadConfiguration(json_object *config) {
    HostCheck::loadConfiguration(config); /* Parse parameters in common */

    json_object *json_threshold;
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", json_object_to_json_string(config));
    if (json_object_object_get_ex(config, "threshold", &json_threshold))
        countries_contacts_threshold = (u_int8_t)json_object_get_int64(json_threshold);
    
    return true;
}