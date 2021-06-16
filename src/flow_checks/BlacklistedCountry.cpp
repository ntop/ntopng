/*
 *
 * (C) 2013-21 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"
#include "flow_checks_includes.h"

/* ***************************************************** */

bool BlacklistedCountry::hasBlacklistedCountry(Host *h) const {
  char buf[3], *country;

  if(!h) return false;

  country = h->get_country(buf, sizeof(buf));

  return blacklisted_countries.find(country) != blacklisted_countries.end();
}

/* ***************************************************** */

void BlacklistedCountry::protocolDetected(Flow *f) {
  u_int8_t c_score, s_score;
  risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;
  bool is_server_bl = false, is_client_bl = false;

  if(blacklisted_countries.size() == 0)
    return; /* Check enabled but no blacklisted country is configured */

  if(hasBlacklistedCountry(f->get_cli_host())) {
    is_client_bl = true;
  }

  if(hasBlacklistedCountry(f->get_srv_host())) {
    is_server_bl = true;
    cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE; /* Client is being attacked */
  }

  if (is_server_bl || is_client_bl) {
    FlowAlertType alert_type = BlacklistedCountryAlert::getClassType();

    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *BlacklistedCountry::buildAlert(Flow *f) {
  bool is_server_bl = hasBlacklistedCountry(f->get_srv_host());
  bool is_client_bl = hasBlacklistedCountry(f->get_cli_host());

  BlacklistedCountryAlert *alert = new BlacklistedCountryAlert(this, f, is_server_bl);

  /*
    When a BLACKLISTED client contacts a normal host, the client is assumed to be the attacker and the server the victim
    When a normal client contacts a BLACKLISTED server, both peers are considered to be attackers
    When both peers are blacklisted, both are considered attackers
  */
  if(is_client_bl && !is_server_bl)
    alert->setCliAttacker(), alert->setSrvVictim();
  else if(!is_client_bl && is_server_bl)
    alert->setCliAttacker(), alert->setSrvAttacker();
  else if(is_client_bl && is_server_bl)
    alert->setCliAttacker(), alert->setSrvAttacker();

  return alert;
}

/* ***************************************************** */

bool BlacklistedCountry::loadConfiguration(json_object *config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */
  json_object *countries_json, *country_json;

  /*
    Parse additional parameters. Example (countries are under "items"):

    { "items": [ "IT", "FR", "DE", "CN" ], "severity": ...
  */

  /* Iterathe through the items array with country codes */
  if(json_object_object_get_ex(config, "items", &countries_json)) {
    int size = json_object_array_length(countries_json);
    for (int i = 0; i < size; i++) {
      country_json = json_object_array_get_idx(countries_json, i);

      /* Add each country code to the set of blacklisted countries */
      std::string country = json_object_get_string(country_json);
      blacklisted_countries.insert(country);
    }
  }

  /*

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", json_object_to_json_string(config));

    std::set<string>::iterator it;
    for(it = blacklisted_countries.begin(); it != blacklisted_countries.end(); ++it)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Parsed: %s", (*it).c_str());
  */


  return(true);
}

/* ***************************************************** */

