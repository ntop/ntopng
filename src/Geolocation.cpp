/*
 *
 * (C) 2013-17 - ntop.org
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

/*
  This product includes GeoLite data created by MaxMind, available from
  <a href="http://www.maxmind.com">http://www.maxmind.com</a>.

  http://dev.maxmind.com/geoip/legacy/geolite
*/

#include "ntop_includes.h"

/* *************************************** */

Geolocation::Geolocation(char *db_home) {
#ifdef HAVE_GEOIP
  char path[MAX_PATH];

  snprintf(path, sizeof(path), "%s/geoip", db_home);

  geo_ip_asn_db     = loadGeoDB(path, "GeoIPASNum.dat");
  geo_ip_asn_db_v6  = loadGeoDB(path, "GeoIPASNumv6.dat");
  geo_ip_city_db    = loadGeoDB(path, "GeoLiteCity.dat");
  geo_ip_city_db_v6 = loadGeoDB(path, "GeoLiteCityv6.dat");
#endif
}

/* *************************************** */

#ifdef HAVE_GEOIP
GeoIP* Geolocation::loadGeoDB(char *base_path, const char *db_name) {
  char path[MAX_PATH];
  GeoIP *geo;
  struct stat buf;
  bool found;  
  
  snprintf(path, sizeof(path), "%s/%s", base_path, db_name);
  ntop->fixPath(path);

  found = ((stat(path, &buf) == 0) && (S_ISREG(buf.st_mode))) ? true : false;

  if(!found) return(NULL);

  geo = GeoIP_open(path, GEOIP_CHECK_CACHE);

  if(geo == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to read GeoIP database %s", path);
  else
    GeoIP_set_charset(geo, GEOIP_CHARSET_UTF8); /* Avoid UTF-8 issues (hopefully) */

  return(geo);
}
#endif

/* *************************************** */

Geolocation::~Geolocation() {
#ifdef HAVE_GEOIP
  if(geo_ip_asn_db != NULL)     GeoIP_delete(geo_ip_asn_db);
  if(geo_ip_asn_db_v6 != NULL)  GeoIP_delete(geo_ip_asn_db_v6);
  if(geo_ip_city_db != NULL)    GeoIP_delete(geo_ip_city_db);
  if(geo_ip_city_db_v6 != NULL) GeoIP_delete(geo_ip_city_db_v6);
#endif
}

/* *************************************** */

void Geolocation::getAS(IpAddress *addr, u_int32_t *asn, char **asname) {
#ifdef HAVE_GEOIP
  char *rsp = NULL;
  struct ipAddress *ip = addr->getIP();
  
  switch(ip->ipVersion) {
  case 4:
    if(geo_ip_asn_db)
      rsp = GeoIP_name_by_ipnum(geo_ip_asn_db, ntohl(ip->ipType.ipv4));
    break;
    
  case 6:
    if(geo_ip_asn_db_v6 != NULL) {
      struct in6_addr *ipv6 = (struct in6_addr*)&ip->ipType.ipv6;
      rsp = GeoIP_name_by_ipnum_v6(geo_ip_asn_db_v6, *ipv6);
    }
    break;
  }

  if(rsp != NULL) {
    char *space = strchr(rsp, ' ');

    *asn = atoi(&rsp[2]);

    if(space)
      *asname = strdup(&space[1]);
    else
      *asname = strdup(rsp);

    free(rsp);
    return;
  }
#endif

  *asn = 0, *asname = NULL;
}

/* *************************************** */

void Geolocation::getInfo(IpAddress *addr, char **country_code, char **city, float *latitude, float *longitude) {
#ifdef HAVE_GEOIP
  GeoIPRecord *geo = NULL;
  struct ipAddress *ip = addr->getIP();
  
  switch(ip->ipVersion) {
  case 4:
    if(geo_ip_city_db != NULL)
      geo = GeoIP_record_by_ipnum(geo_ip_city_db, ntohl(ip->ipType.ipv4));
    break;
    
  case 6:
    if(geo_ip_city_db_v6 != NULL) {
      struct in6_addr *ipv6 = (struct in6_addr*)&ip->ipType.ipv6;
      
      geo = GeoIP_record_by_ipnum_v6(geo_ip_city_db_v6, *ipv6);
    }
    break;
  }

  if(geo != NULL) {
    *country_code = geo->country_code ? strdup(geo->country_code) : NULL;
    *city = geo->city ? strdup(geo->city) : NULL;
    *latitude = geo->latitude, *longitude = geo->longitude;
    GeoIPRecord_delete(geo);
  } else
    *country_code = NULL, *city = NULL, *latitude = *longitude = 0;
#endif
}

