/*
 *
 * (C) 2016-17 - ntop.org
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

/* *************************************** */

CategoryStats::CategoryStats() {
  categories = (u_int64_t*)calloc(ntop->get_flashstart()->getNumCategories(), sizeof(u_int64_t));
}

/* *************************************** */

CategoryStats::~CategoryStats() {
  if(categories) free(categories);
}

/* *************************************** */

void CategoryStats::lua(lua_State* vm) {
  lua_newtable(vm);

  if(categories) {
    for(int i=0; i<ntop->get_flashstart()->getNumCategories(); i++)
      if(categories[i] > 0)
	lua_push_int_table_entry(vm, 
				 ntop->get_flashstart()->getCategoryName(i),
				 categories[i]);    
  }

  lua_pushstring(vm, "categories");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

char* CategoryStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

void CategoryStats::deserialize(json_object *o) {
  if(!o) return;

  /* Reset all */
  memset(categories, 0, ntop->get_flashstart()->getNumCategories()*sizeof(u_int64_t));

  for(int id=0; id<ntop->get_flashstart()->getNumCategories(); id++) {
    char *name = ntop->get_flashstart()->getCategoryName(id);

    if(name != NULL) {
      json_object *bytes;

      if(json_object_object_get_ex(o, name, &bytes)) {
	categories[id] = json_object_get_int64(bytes);
      }
    }
  }
}

/* *************************************** */

json_object* CategoryStats::getJSONObject() {
  json_object *my_object;
  
  my_object = json_object_new_object();

  for(int id=0; id<ntop->get_flashstart()->getNumCategories(); id++) {
    if(categories[id] > 0) {
      char *name = ntop->get_flashstart()->getCategoryName(id);
      
      json_object_object_add(my_object, name, 
			     json_object_new_int64(categories[id]));
    }
  }
  
  return(my_object);
}
