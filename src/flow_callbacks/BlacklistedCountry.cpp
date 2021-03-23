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
#include "flow_callbacks_includes.h"

/* ***************************************************** */

bool BlacklistedCountry::hasBlacklistedCountry(Host *h) const {
  char buf[3], *country;

  if(!h) return false;

  country = h->get_country(buf, sizeof(buf));

  return blacklisted_countries.find(country) != blacklisted_countries.end();
}

/* ***************************************************** */

void BlacklistedCountry::protocolDetected(Flow *f) {
  Host *cli_host, *srv_host;
  u_int8_t c_score = 0, s_score = 0;
  bool is_server_bl = false, is_client_bl = false;

  if(blacklisted_countries.size() == 0)
    return; /* Callback enabled but no blacklisted country is configured */

  cli_host = f->get_cli_host(), srv_host = f->get_srv_host();

  if(hasBlacklistedCountry(f->get_cli_host())) {
    is_client_bl = true;
    c_score += 60, s_score += 10;
  }

  if(hasBlacklistedCountry(f->get_srv_host())) {
    is_server_bl = true;
    s_score += 60, c_score += 10;
  }

  if (is_server_bl || is_client_bl) {
    f->triggerAlertAsync(BlacklistedCountryAlert::getClassType(), getSeverity(), c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *BlacklistedCountry::buildAlert(Flow *f) {
  bool is_server = hasBlacklistedCountry(f->get_srv_host());
  return new BlacklistedCountryAlert(this, f, is_server);
}

/* ***************************************************** */

bool BlacklistedCountry::loadConfiguration(json_object *config) {
  FlowCallback::loadConfiguration(config); /* Parse parameters in common */
  json_object *countries_json, *country_json;

  /*
    Parse additional parameters. Example (countries are under "items"):

    { "items": [ "IT", "FR", "DE", "CN" ], "severity": ...
  */

  /* Iterathe through the items array with country codes */
  if(json_object_object_get_ex(config, "items", &countries_json)) {
    for (int i = 0; i < json_object_array_length(countries_json); i++) {
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

