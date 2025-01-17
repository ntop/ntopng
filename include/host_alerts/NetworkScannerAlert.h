#ifndef _NETWORK_SCANNER_ALERT_H_
#define _NETWORK_SCANNER_ALERT_H_
#include "ntop_includes.h"

class NetworkScannerAlert : public FlowHitsAlert {
    private:
        u_int16_t num_flows_tokens;
        u_int64_t threshold;
        ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);
    
    public:
        static HostAlertType getClassType(){
            return { host_alert_network_scanner, alert_category_network };
        }
        
        NetworkScannerAlert(HostCheck *c, Host *h, risk_percentage cli_pctg,
                 u_int16_t _num_flows_tokens, u_int64_t threshold, bool is_attacker);
        
        ~NetworkScannerAlert() {};
        
        HostAlertType getAlertType() const { return getClassType(); }
        
        u_int8_t getAlertScore() const { return SCORE_LEVEL_WARNING; }
};

#endif /* _NETWORK_SCANNER_ALERT_H_ */