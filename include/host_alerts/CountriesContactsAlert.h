#include "ntop_includes.h"

class CountriesContactsAlert : public HostAlert {
private:
    u_int64_t countries_contacts, countries_contacts_threshold;

    ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

public:
    CountriesContactsAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _country_contacts, u_int64_t _country_contacts_threshold);
    ~CountriesContactsAlert() {}

    static HostAlertType getClassType() { return { host_alert_country_contacts, alert_category_security }; }
    HostAlertType getAlertType() const  { return getClassType(); }
    u_int8_t getAlertScore()     const  { return SCORE_LEVEL_WARNING; };
};