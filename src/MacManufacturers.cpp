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

MacManufacturers::MacManufacturers(const char * const home) {
  mac_manufacturers = NULL;
  snprintf(manufacturers_file, sizeof(manufacturers_file), "%s/other/%s", home ? home : "", "EtherOUI.txt");
  ntop->fixPath(manufacturers_file);

  init();
}

/* *************************************** */

void MacManufacturers::init() {
  struct stat buf;
  FILE *fd;
  char * line = NULL, *manuf = NULL, *cr;
  size_t len = 0;
  ssize_t read;
  u_int8_t mac[3];
  char short_name[9];
  mac_manufacturers_t *s;

  if(!(stat(manufacturers_file, &buf) == 0) && (S_ISREG(buf.st_mode)))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "File %s doesn't exists or is not readable", manufacturers_file);

  if((fd = fopen(manufacturers_file, "r")) == NULL)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read %s", manufacturers_file);

  if(fd) {
    while ((read = getline(&line, &len, fd)) != -1) {
      char *tab = strchr(line, '\t');

      if((sscanf(line, "%02hhx:%02hhx:%02hhx", &mac[0], &mac[1], &mac[2]) == 3) &&
         (tab != NULL)) {

	// printf("Retrieved line of length %zu :\n", read);
	// printf("%s", line);

	/* Lines are like:
	   00:05:02        Apple                  # Apple, Inc.
	   So it is possible to use '# ' as the full manufacturer name separator
	 */
	if((manuf = strstr(line, "# ")) == NULL)
	  continue;
	manuf += 2;

	if((cr = strchr(manuf, '\n')))
	   *cr = '\0';

	HASH_FIND(hh, mac_manufacturers, mac, 3, s);
	if(!s) {
	  if((s = (mac_manufacturers_t*)calloc(1, sizeof(mac_manufacturers_t))) != NULL) {
	    memcpy(s->mac_manufacturer, mac, 3);
	    s->manufacturer_name = strdup(manuf);
	    sscanf(tab, "%8s", short_name);
	    s->short_name = strdup(short_name);
	    HASH_ADD(hh, mac_manufacturers, mac_manufacturer, 3, s);

#ifdef MANUF_DEBUG
	    ntop->getTrace()->traceEvent(TRACE_NORMAL,
					 "Adding mac %02x:%02x:%02x [manufacturer name: %s]",
					 s->mac_manufacturer[0],
					 s->mac_manufacturer[1],
					 s->mac_manufacturer[2],
					 s->manufacturer_name);
#endif
	  }
	}
      }
    }
    fclose(fd);
  }
}

/* *************************************** */

MacManufacturers::~MacManufacturers() {
  mac_manufacturers_t *current, *tmp;

  HASH_ITER(hh, mac_manufacturers, current, tmp) {
    HASH_DEL(mac_manufacturers, current);
    free(current->manufacturer_name);
    free(current);
  }
}
