#include "ntop_includes.h"
#include "host_checks_includes.h"
NetworkScanner::NetworkScanner()
  : HostCheck(ntopng_edition_community, 
              false /* All interfaces */, 
              false /* Don't exclude for nEdge */, 
              false /* NOT only for nEdge */){};

void NetworkScanner::periodicUpdate(Host *h, HostAlert *engaged_alert) {
    HostAlert *alert = engaged_alert;
    u_int32_t num_flows_tokens = 0;
    num_flows_tokens = h->getNetscanTokens();
    if (num_flows_tokens > threshold) {
        if (!alert)
        alert = allocAlert(this, h, CLIENT_FAIR_RISK_PERCENTAGE, num_flows_tokens, threshold,true);
        if (alert) {
            h->triggerAlert(alert);
            h->resetNetscanTokens();
        }
    }  
}
bool NetworkScanner::loadConfiguration(json_object *config) {
    json_object *json_threshold;
    HostCheck::loadConfiguration(config);
    if (json_object_object_get_ex(config, "threshold", &json_threshold))
            threshold = json_object_get_int64(json_threshold);
    return (true);
}