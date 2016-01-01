/*
 *
 * (C) 2013-16 - ntop.org
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

/* **************************************************** */

Profiles::Profiles() {
  numProfiles = 0;
  //profiles = NULL;
  memset(profiles, 0, sizeof(profiles));
  //loadProfiles();
}

/* **************************************************** */

Profiles::~Profiles() {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Destroying Profiles\n");    
  for(int i=0; i<numProfiles; i++)
    delete profiles[i];
}

/* **************************************************** */

void Profiles::loadProfiles() {
  char **vals;
  Redis *redis = ntop->getRedis();
  int rc;

  rc = (redis ? redis->hashKeys(CONST_PROFILES_PREFS, &vals) : -1);
  if(rc > 0) {
    rc = min_val(rc, MAX_NUM_PROFILES);

    for(int i = 0; i < rc; i++) {
      if(vals[i] != NULL) {
	char contents[2048];

	if(redis->hashGet((char*)CONST_PROFILES_PREFS, vals[i], contents, sizeof(contents)) != -1) {
	  Profile *c = addProfile(vals[i], contents);
	  if(c) profiles[numProfiles++] = c;
	}

	free(vals[i]);
      }
    }

    free(vals);
  }
}

void Profiles::lua(lua_State* vm) {
  lua_newtable(vm);

  for(int i=0; i<numProfiles; i++)
    profiles[i]->lua(vm);
  
  lua_pushstring(vm, "profiles");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

}
