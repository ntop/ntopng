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

/*
  This product includes GeoLite data created by MaxMind, available from
  <a href="http://www.maxmind.com">http://www.maxmind.com</a>.

  http://dev.maxmind.com/geoip/legacy/geolite
*/

#include "ntop_includes.h"

/* *************************************** */

MacManufacturers::MacManufacturers(const char * const home) {
  snprintf(manufacturers_file, sizeof(manufacturers_file), "%s/other/%s", home ? home : "", "EtherOUI.txt");
  ntop->fixPath(manufacturers_file);

  init();
}

/* *************************************** */

void MacManufacturers::init() {
  struct stat buf;
  FILE *fd;
  char line[256], *cr;
  int _mac[3];
  u_int32_t mac_key;

  if(!(stat(manufacturers_file, &buf) == 0) && (S_ISREG(buf.st_mode)))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "File %s doesn't exists or is not readable",
				 manufacturers_file);

  if((fd = fopen(manufacturers_file, "r")) == NULL)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read %s",
				 manufacturers_file);

  if(fd) {
    while(fgets(line, sizeof(line), fd)) {
      char *tmp;
      char *mac = strtok_r(line, "\t", &tmp);
      char *shortmanuf, *manuf;

      if(!mac)
	continue;
      else
	shortmanuf = strtok_r(NULL, "\t", &tmp);

      if(!shortmanuf)
	continue;
      else {
	manuf = strtok_r(NULL, "\t", &tmp);
	if(!manuf) manuf = shortmanuf;
      }

#ifdef MANUF_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [short: %s][full: %s]", mac, shortmanuf, manuf);
#endif
				   
      if(sscanf(mac, "%02x:%02x:%02x", &_mac[0], &_mac[1], &_mac[2]) == 3) {	
	// printf("Retrieved line of length %zu :\n", read);
	// printf("%s", line);

	/* Lines are like:
	   00:05:02        Apple                  # Apple, Inc.
	   So it is possible to use '# ' as the full manufacturer name separator
	*/
	tmp = strstr(manuf, "# ");
	if(tmp)
	  manuf = &tmp[2];

	if((cr = strchr(manuf, '\n')))
	  *cr = '\0';

	mac[0] = (u_int8_t)_mac[0], mac[1] = (u_int8_t)_mac[1], mac[2] = (u_int8_t)_mac[2];
	mac_key = mac2key((u_int8_t*)mac);

	if(mac_manufacturers.find(mac_key) == mac_manufacturers.end()) {
	  mac_manufacturers_t s;

	  s.manufacturer_name = (char*)calloc(strlen(manuf) + 1, sizeof(char));
	  strcpy(s.manufacturer_name, manuf);
	  Utils::purifyHTTPparam(s.manufacturer_name, false, false, false);

	  s.short_name = (char*)calloc(strlen(shortmanuf) + 1, sizeof(char));
	  strcpy(s.short_name, shortmanuf);
	  Utils::purifyHTTPparam(s.short_name, false, false, false);

	  /* TODO: reduce memory usage for recurrent manufacturers */

	  mac_manufacturers[mac_key] = s;

#ifdef MANUF_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL,
				       "Adding mac %02x:%02x:%02x [manufacturer name: %s]",
				       s.mac_manufacturer[0],
				       s.mac_manufacturer[1],
				       s.mac_manufacturer[2],
				       s.manufacturer_name);
#endif
	}
      }
    }

    fclose(fd);
  }
}

/* *************************************** */

MacManufacturers::~MacManufacturers() {
  std::map<u_int32_t, mac_manufacturers_t>::const_iterator it;

  for(it = mac_manufacturers.begin(); it != mac_manufacturers.end(); ++it) {
    free(it->second.manufacturer_name);
    free(it->second.short_name);
  }
  mac_manufacturers.clear();
}

/* *************************************** */

const char * MacManufacturers::getManufacturer(u_int8_t mac[]) {
  std::map<u_int32_t, mac_manufacturers_t>::const_iterator it;
  u_int32_t mac_key = mac2key(mac);

  if((it = mac_manufacturers.find(mac_key)) != mac_manufacturers.end())
    return(it->second.manufacturer_name);

  return(NULL);
}

/* *************************************** */

void MacManufacturers::getMacManufacturer(u_int8_t mac[], lua_State *vm) {
  std::map<u_int32_t, mac_manufacturers_t>::const_iterator it;
  u_int32_t mac_key = mac2key(mac);

  if((it = mac_manufacturers.find(mac_key)) != mac_manufacturers.end()) {
    lua_newtable(vm);
    lua_push_str_table_entry(vm, "short", it->second.short_name);
    lua_push_str_table_entry(vm, "extended", it->second.manufacturer_name);
  } else {
    lua_pushnil(vm);
  }
};
