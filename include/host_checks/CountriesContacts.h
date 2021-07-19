#ifndef _COUNTRY_CONTACTS_H_
#define _COUNTRY_CONTACTS_H_

#include "ntop_includes.h"

class CountriesContacts : public HostCheck {
protected:
    u_int64_t countries_contacts_threshold;
private:
    CountriesContactsAlert *allocAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _countries_contacts, u_int64_t _countries_contacts_threshold) { 
        return new CountriesContactsAlert(c, f, cli_pctg, _countries_contacts, _countries_contacts_threshold); 
    }
public:
    CountriesContacts();
    ~CountriesContacts() {}

    u_int32_t getContactedCountries(Host *h) { return h->getCountriesContactsCardinality(); }
    void periodicUpdate(Host *h, HostAlert *engaged_alert);
    bool loadConfiguration(json_object *config); 
    HostCheckID getID()     const { return host_check_countries_contacts; }
    std::string getName()   const { return(std::string("country_contacts")); }
};

#endif /* _COUNTRY_CONTACTS_H_ */