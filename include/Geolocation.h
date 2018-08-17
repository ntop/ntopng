/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _GEOLOCATION_H_
#define _GEOLOCATION_H_

#include "ntop_includes.h"

extern "C" {
#ifdef HAVE_MAXMINDDB
#include <maxminddb.h>
#endif
};

class Geolocation {
 private:
#ifdef HAVE_MAXMINDDB
  MMDB_s geo_ip_asn_mmdb, geo_ip_city_mmdb;
  bool loadMaxMindDB(const char * const base_path, const char * const db_name, MMDB_s * const mmdb) const;
  bool mmdbs_ok;

#elif defined(HAVE_GEOIP)
  GeoIP *geo_ip_asn_db, *geo_ip_asn_db_v6;
  GeoIP *geo_ip_city_db, *geo_ip_city_db_v6;

  GeoIP* loadGeoDB(char *base_path, const char *db_name);
#endif

#define TEST_GEOLOCATION 1
#ifdef TEST_GEOLOCATION
  void testme();
#endif
 public:
  Geolocation(char *db_home);
  ~Geolocation();

  void getAS(IpAddress *addr, u_int32_t *asn, char **asname);
  void getInfo(IpAddress *addr, char **continent_code, char **country_code, char **city, float *latitude, float *longitude);
  static void freeInfo(char **continent_code, char **country_code, char **city);
};

#endif /* _GEOLOCATION_H_ */
