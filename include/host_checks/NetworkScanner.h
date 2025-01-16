#ifndef _NETWORKSCANNER_H_
#define _NETWORKSCANNER_H_

#include "ntop_includes.h"

class NetworkScanner : public HostCheck{
    protected:
        u_int64_t threshold;
    public:
        NetworkScanner();
        ~NetworkScanner(){};

        NetworkScannerAlert *allocAlert(HostCheck* c, Host* h,
                                risk_percentage cli_pctg,
                                u_int16_t num_flows_tokens,
                                u_int64_t _threshold,
                                bool _is_attacker) {
            return new NetworkScannerAlert(c, h, cli_pctg, num_flows_tokens, _threshold, _is_attacker);
        }; 

        bool loadConfiguration(json_object *config);
        void periodicUpdate(Host *h, HostAlert *engaged_alert);
        HostCheckID getID() const { return host_check_network_scanner; }
        std::string getName() const { return (std::string("network_scanner")); }
};

#endif