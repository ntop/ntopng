/*
 *
 * (C) 2013-26 - ntop.org
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

Geolocation::Geolocation() {
  bool mmdbs_asn_ok = false, mmdbs_city_ok = false;
  char* custom_dir = ntop->getPrefs()->getCustomGeoIPDir();

  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  if (custom_dir == NULL) custom_dir = (char*)".";

#ifdef HAVE_MAXMINDDB
  char docs_path[MAX_PATH];
  const char* lookup_paths[] = {
      custom_dir,
#ifndef WIN32
      "/var/lib/GeoIP",    // `geoipupdate` default install dir on Ubuntu 16,18
                           // and Debian 10,9
      "/usr/share/GeoIP",  // `geoipupdate` default install dir on Ubuntu 14 and
                           // Centos 7,8
#if defined(__FreeBSD__)
      "/usr/local/share/ntopng/httpdocs/geoip/",  // ntopng-data default install
                                                  // dir
#else
      "/usr/share/ntopng/httpdocs/geoip/",  // ntopng-data default install dir
#endif
#endif
      docs_path};

  mmdbs_ok = false;

  snprintf(docs_path, sizeof(docs_path), "%s/geoip",
           ntop->getPrefs()->get_docs_dir());
  ntop->fixPath(docs_path);

  for (u_int i = 0;
       i < sizeof(lookup_paths) / sizeof(lookup_paths[0]) && !mmdbs_ok; i++) {
    DIR* dirp;
    struct dirent* dp;

    /* Let's try with MaxMind files DBs:
     * https://dev.maxmind.com/geoip/geoipupdate/ */
    if (!mmdbs_asn_ok)
      mmdbs_asn_ok =
          loadGeoDB(lookup_paths[i], "GeoLite2-ASN.mmdb", &geo_ip_asn_mmdb);

    if (!mmdbs_city_ok)
      mmdbs_city_ok =
          loadGeoDB(lookup_paths[i], "GeoLite2-City.mmdb", &geo_ip_city_mmdb);

    if (mmdbs_asn_ok && mmdbs_city_ok) {
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL,
          "Using geolocation provided by MaxMind (https://maxmind.com)");
      mmdbs_ok = true;
      break;
    }

    /*
      Let's try https://db-ip.com

      Filename format is
      - dbip-asn-lite-YYYY-MM.mmdb
      - dbip-country-lite-YYYY-MM.mmdb
    */

    dirp = opendir(lookup_paths[i]);
    if (dirp == NULL) continue;

    while ((dp = readdir(dirp)) != NULL) {
      if (dp->d_name[0] == '.') continue;

      if (strncmp(dp->d_name, "dbip-", 5) == 0) {
        if ((!mmdbs_asn_ok) && (strncmp(dp->d_name, "dbip-asn", 8) == 0)) {
          mmdbs_asn_ok =
              loadGeoDB(lookup_paths[i], dp->d_name, &geo_ip_asn_mmdb);
        }

        if ((!mmdbs_city_ok) && (strncmp(dp->d_name, "dbip-city", 9) == 0)) {
          mmdbs_city_ok =
              loadGeoDB(lookup_paths[i], dp->d_name, &geo_ip_city_mmdb);
        }
      }

      if (mmdbs_asn_ok && mmdbs_city_ok) {
        ntop->getTrace()->traceEvent(
            TRACE_NORMAL,
            "Using geolocation provided by DB-IP (https://db-ip.com)");
        break;
      }
    }

    closedir(dirp);

    if (mmdbs_asn_ok && mmdbs_city_ok) {
      mmdbs_ok = true;
      break;
    }
  }
#endif

#ifndef WIN32
#ifdef HAVE_MAXMINDDB
  if (!mmdbs_ok)
#endif
  {
    if (mmdbs_asn_ok) MMDB_close(&geo_ip_asn_mmdb);
    if (mmdbs_city_ok) MMDB_close(&geo_ip_city_mmdb);
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Running without geolocation support.");
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "To enable geolocation follow the instructions at");
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL,
        "https://github.com/ntop/ntopng/blob/dev/doc/README.geolocation.md");
  }
#endif
}

/* *************************************** */

#ifdef HAVE_MAXMINDDB
bool Geolocation::loadGeoDB(const char* base_path, const char* db_name,
                            MMDB_s* const mmdb) const {
  char path[MAX_PATH];
  struct stat buf;
  bool found;

  snprintf(path, sizeof(path), "%s/%s", base_path, db_name);
  ntop->fixPath(path);

  found = ((stat(path, &buf) == 0) && (S_ISREG(buf.st_mode))) ? true : false;

  if (!found) return false;

  int status = MMDB_open(path, MMDB_MODE_MMAP, mmdb);

  if (status != MMDB_SUCCESS) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open %s [%s]", path,
                                 MMDB_strerror(status));

    if (status == MMDB_IO_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "IO error [%s]",
                                   strerror(errno));

    return false;
  } else {
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Loaded database %s [%s][ip_version: %d]",
                                 db_name, path, mmdb->metadata.ip_version);

    return true;
  }
}

#endif

/* *************************************** */

Geolocation::~Geolocation() {
#ifdef HAVE_MAXMINDDB
  if (mmdbs_ok) {
    MMDB_close(&geo_ip_asn_mmdb);
    MMDB_close(&geo_ip_city_mmdb);
  }
#endif
}

/* *************************************** */

/*
  IMPORTANT:
  if *asname != NULL, then the caller MUST free *asname
 */
bool Geolocation::getAS(IpAddress* addr, u_int32_t* asn, char** asname) {
  if (asn) *asn = 0;
  if (asname) *asname = NULL;
  bool ret = false;

#ifdef HAVE_MAXMINDDB
  sockaddr* sa = NULL;
  ssize_t sa_len;
  int mmdb_error, status;
  MMDB_lookup_result_s result;
  MMDB_entry_data_s entry_data;

  if (!mmdbs_ok) return (false);

  if (addr && addr->get_sockaddr(&sa, &sa_len)) {
    result = MMDB_lookup_sockaddr(&geo_ip_asn_mmdb, sa, &mmdb_error);

    if (mmdb_error == MMDB_SUCCESS) {
      if (result.found_entry) {
        /* Get the ASN */
        if (asn && (status = MMDB_get_value(&result.entry, &entry_data,
                                            "autonomous_system_number",
                                            NULL)) == MMDB_SUCCESS) {
          if (entry_data.has_data && entry_data.type == MMDB_DATA_TYPE_UINT32)
            *asn = entry_data.uint32;
        }

        /* Get the AS Organization, that is an utf8 string that is NOT
         * terminated with a null character. */
        if (asname && (status = MMDB_get_value(&result.entry, &entry_data,
                                               "autonomous_system_organization",
                                               NULL)) == MMDB_SUCCESS) {
          if (entry_data.has_data &&
              entry_data.type == MMDB_DATA_TYPE_UTF8_STRING) {
            char* org;

            if ((org = (char*)calloc(1, entry_data.data_size + 1))) {
              memcpy(org, entry_data.utf8_string, entry_data.data_size);
              *asname = org;
            }
          }
        }
      }

      ret = true;
    } else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Lookup failed [%s]",
                                   MMDB_strerror(mmdb_error));
  }
  if (sa) free(sa);
#endif

  return ret;
}

/* *************************************** */

bool Geolocation::getInfo(IpAddress* addr, char** continent_code,
                          char** country_code, char** city, float* latitude,
                          float* longitude) {
  if ((!addr) || (addr->getVersion() == 0)) return (false);

  if (continent_code) *continent_code = strdup((char*)UNKNOWN_CONTINENT);
  if (country_code) *country_code = strdup((char*)UNKNOWN_COUNTRY);
  if (city) *city = strdup((char*)UNKNOWN_CITY);
  if (latitude) *latitude = 0;
  if (longitude) *longitude = 0;

  bool ret = false;

#ifdef HAVE_MAXMINDDB
  sockaddr* sa = NULL;
  ssize_t sa_len;
  char* cdata;

  if (!mmdbs_ok) return (false);

  if (addr && addr->get_sockaddr(&sa, &sa_len)) {
    int mmdb_error, status;
    MMDB_lookup_result_s result;
    MMDB_entry_data_s entry_data;

    result = MMDB_lookup_sockaddr(&geo_ip_city_mmdb, sa, &mmdb_error);

    if (mmdb_error == MMDB_SUCCESS) {
      if (result.found_entry) {
        /* Get the continent code */
        if (continent_code &&
            (status = MMDB_get_value(&result.entry, &entry_data, "continent",
                                     "code", NULL)) == MMDB_SUCCESS) {
          if (entry_data.has_data &&
              entry_data.type == MMDB_DATA_TYPE_UTF8_STRING) {
            if ((cdata = (char*)calloc(1, entry_data.data_size + 1))) {
              memcpy(cdata, entry_data.utf8_string, entry_data.data_size);
              free(*continent_code);
              *continent_code = cdata;
            }
          }
        }

        /* Get the country code */
        if (country_code &&
            (status = MMDB_get_value(&result.entry, &entry_data, "country",
                                     "iso_code", NULL)) == MMDB_SUCCESS) {
          if (entry_data.has_data &&
              entry_data.type == MMDB_DATA_TYPE_UTF8_STRING) {
            if ((cdata = (char*)calloc(1, entry_data.data_size + 1))) {
              memcpy(cdata, entry_data.utf8_string, entry_data.data_size);
              free(*country_code);
              *country_code = cdata;
            }
          }
        }

        /* Get the city (seems that there are only localized versions of the
         * city name) */
        if (city &&
            (status = MMDB_get_value(&result.entry, &entry_data, "city",
                                     "names", "en", NULL)) == MMDB_SUCCESS) {
          if (entry_data.has_data &&
              entry_data.type == MMDB_DATA_TYPE_UTF8_STRING) {
            if ((cdata = (char*)calloc(1, entry_data.data_size + 1))) {
              memcpy(cdata, entry_data.utf8_string, entry_data.data_size);
              free(*city);
              *city = cdata;
            }
          }
        }

        /* Get the latitude */
        if (latitude &&
            (status = MMDB_get_value(&result.entry, &entry_data, "location",
                                     "latitude", NULL)) == MMDB_SUCCESS) {
          if (entry_data.has_data && entry_data.type == MMDB_DATA_TYPE_DOUBLE)
            *latitude = (float)entry_data.double_value;
        }

        /* Get the longitude */
        if (longitude &&
            (status = MMDB_get_value(&result.entry, &entry_data, "location",
                                     "longitude", NULL)) == MMDB_SUCCESS) {
          if (entry_data.has_data && entry_data.type == MMDB_DATA_TYPE_DOUBLE)
            *longitude = (float)entry_data.double_value;
        }
      }
    }

    ret = true;
  } else {
    char buf[64];

    ntop->getTrace()->traceEvent(
        TRACE_ERROR,
        "Invalid address lookup [addr addr: 0x%X][addr: %s][version: %u]",
        addr ? addr : 0, addr ? addr->print(buf, sizeof(buf)) : "",
        addr ? addr->getVersion() : 0);
  }
  if (sa) free(sa);
#endif

  return ret;
}

/* *************************************** */

void Geolocation::freeInfo(char** continent_code, char** country_code,
                           char** city) {
  if (continent_code) {
    free(*continent_code);
    *continent_code = NULL;
  }
  if (country_code) {
    free(*country_code);
    *country_code = NULL;
  }
  if (city) {
    free(*city);
    *city = NULL;
  }
}

/* *************************************** */

#if defined(HAVE_MAXMINDDB) && defined(TEST_GEOLOCATION)
void Geolocation::testme() {
  sockaddr* sa = NULL;
  ssize_t sa_len;
  IpAddress test;
  int mmdb_error, status;
  MMDB_lookup_result_s result;
  MMDB_entry_data_list_s* entry_data_list = NULL;
  MMDB_entry_data_s entry_data;

  static char* ips[] = {(char*)"192.168.1.1", (char*)"69.89.31.226",
                        (char*)"8.8.8.8", (char*)"69.63.181.15",
                        (char*)"2a03:2880:f10c:83:face:b00c:0:25de"};

  for (u_int32_t i = 0; i < sizeof(ips) / sizeof(char*); i++) {
    char* ip = ips[i];

    ntop->getTrace()->traceEvent(TRACE_INFO, "Geolocating [%s]", ip);
    test.set(ip);

    if (test.get_sockaddr(&sa, &sa_len)) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Autonomous System Information", ip);

      /* TEST Autonomous Systems database */
      result = MMDB_lookup_sockaddr(&geo_ip_asn_mmdb, sa, &mmdb_error);

      if (mmdb_error != MMDB_SUCCESS) {
      }

      if (result.found_entry) {
        entry_data_list = NULL;

        if ((status = MMDB_get_entry_data_list(
                 &result.entry, &entry_data_list)) != MMDB_SUCCESS)
          ntop->getTrace()->traceEvent(TRACE_ERROR,
                                       "Unable to lookup address [%s]",
                                       MMDB_strerror(status));

        if (entry_data_list)
          MMDB_dump_entry_data_list(stdout, entry_data_list, 2);

        if ((status = MMDB_get_value(&result.entry, &entry_data,
                                     "autonomous_system_number", NULL)) ==
            MMDB_SUCCESS) {
          if (entry_data.has_data && entry_data.type == MMDB_DATA_TYPE_UINT32)
            ntop->getTrace()->traceEvent(TRACE_NORMAL, "ASN: %d", entry_data.uint32);

        } else
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "Unable to lookup autonomous system number [%s]",
              MMDB_strerror(status));

        if ((status = MMDB_get_value(&result.entry, &entry_data,
                                     "autonomous_system_organization", NULL)) ==
            MMDB_SUCCESS) {
          if (entry_data.has_data &&
              entry_data.type == MMDB_DATA_TYPE_UTF8_STRING) {
            char* org;

            if ((org = (char*)calloc(1, entry_data.data_size + 1))) {
              memcpy(org, entry_data.utf8_string, entry_data.data_size);
              ntop->getTrace()->traceEvent(TRACE_NORMAL, "Organization: %s", org);
              free(org);
            }
          }

        } else
          ntop->getTrace()->traceEvent(
              TRACE_ERROR,
              "Unable to lookup autonomous system organization [%s]",
              MMDB_strerror(status));
      }

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "City Information", ip);

      result = MMDB_lookup_sockaddr(&geo_ip_city_mmdb, sa, &mmdb_error);

      if (mmdb_error != MMDB_SUCCESS) {
      }

      if (result.found_entry) {
        entry_data_list = NULL;
        status = MMDB_get_entry_data_list(&result.entry, &entry_data_list);

        if (status != MMDB_SUCCESS)
          ntop->getTrace()->traceEvent(TRACE_ERROR,
                                       "Unable to lookup address [%s]",
                                       MMDB_strerror(status));

        if (entry_data_list) {
          MMDB_dump_entry_data_list(stdout, entry_data_list, 2);
        }
      }

      free(sa);
    }
  }
}
#endif

/* *************************************** */

/* Callback for getASName(): reads handle (col 0) and description (col 1) from asn_info */
static int asn_info_cb(std::vector<std::string>* row,
                       std::vector<std::string>* /* columns */,
                       void* user_data) {
  asn_info_query_ctx_t* out = (asn_info_query_ctx_t*)user_data;
  if (!out->found && row->size() >= 2) {
    snprintf(out->handle_buf, out->handle_len, "%s", (*row)[0].c_str());
    snprintf(out->desc_buf,   out->desc_len,   "%s", (*row)[1].c_str());
    out->found = true;
  }
  return 0;
}

bool Geolocation::getASName(u_int32_t asn, char* handle, u_int handle_len,
                            char* description, u_int description_len) {
  char buf[256], val[16], json[2048];
  long rc;

  snprintf(val, sizeof(val), "%u", asn);

  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "ASN Lookup (%u)", asn);

  /* Redis cache (AS data stored as "handle|description", old entries have just "description") */
  char cached[512];
  if (ntop->getRedis()->hashGet(AS_NAME_CACHE, val, cached, sizeof(cached)) == 0) {
    if (cached[0] == '\0') return (false); /* previously not found */
    char* pipe = strchr(cached, '|');
    if (pipe) {
      snprintf(handle,      handle_len,      "%.*s", (int)(pipe - cached), cached);
      snprintf(description, description_len, "%s",   pipe + 1);
    } else {
      snprintf(handle,      handle_len,      "%s", cached);
      snprintf(description, description_len, "%s", cached);
    }

    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "AS INFO From Redis [%s]", cached);

    return (true);
  }

  /* Check asn_info table on DB before checking RIPE */
  NetworkInterface* iface = ntop->getFirstInterface();
  if (iface) {
    DB* db = iface->getFlowsDB(); /* asn_info lives only in ClickHouse */
    if (db) {
      asn_info_query_ctx_t ctx = {handle, handle_len, description, description_len, false};
      snprintf(buf, sizeof(buf),
               "SELECT handle, description FROM asn_info WHERE asn = %u LIMIT 1", asn);
      db->execSQLQuery(buf, true, true, asn_info_cb, &ctx);
      if (ctx.found) {
        /* Note: if either field is empty, use the other */
        if (handle[0] == '\0')      snprintf(handle,      handle_len,      "%s", description);
        if (description[0] == '\0') snprintf(description, description_len, "%s", handle);
        snprintf(cached, sizeof(cached), "%s|%s", handle, description);
        ntop->getRedis()->hashSet(AS_NAME_CACHE, val, cached);

        //ntop->getTrace()->traceEvent(TRACE_NORMAL, "AS INFO From DB [%s]", cached);

        return (true);
      }
    }
  }

  /* Last resort: get AS info from RIPE stat */
  snprintf(buf, sizeof(buf), "https://stat.ripe.net/data/as-overview/data.json?resource=AS%u", asn);
  json[0] = '\0';
  rc = Utils::httpGet(buf, NULL, NULL, NULL, 5 /* connect timeout */,
                      10 /* download timeout */, json, sizeof(json),
		      ntop->getPrefs()->do_insecure_tls());

  ntop->getTrace()->traceEvent(TRACE_INFO, "[rc: %u][%s]", rc, json);

  if (rc == 200) {
    json_object *o, *obj;
    enum json_tokener_error jerr = json_tokener_success;

    if ((o = json_tokener_parse_verbose(json, &jerr)) == NULL) return (false);

    if (json_object_object_get_ex(o, "data", &obj)) {
      json_object* obj1;

      if (json_object_object_get_ex(obj, "holder", &obj1)) {
        const char *res, *r = json_object_get_string(obj1);

#if 1
        res = r;
#else
        res = strchr(r, ' ');

        if (res == NULL)
          res = r;
        else
          res = &res[1]; /* Skip space */
#endif

        /* RIPE provides a single holder string — use it for both fields */
        snprintf(description, description_len, "%s", res);
        snprintf(handle,      handle_len,      "%s", res);

        snprintf(cached, sizeof(cached), "%s|%s", handle, description);
        ntop->getRedis()->hashSet(AS_NAME_CACHE, val, cached);
        json_object_put(o);

        //ntop->getTrace()->traceEvent(TRACE_NORMAL, "AS INFO From RIPE [%s]", cached);

        return (true);
      }

      json_object_put(o);
    }
  }

  /* Not found */
  ntop->getRedis()->hashSet(AS_NAME_CACHE, val, "");

  return (false);
}
