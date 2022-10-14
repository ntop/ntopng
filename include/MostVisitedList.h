/*
 *
 * (C) 2013-22 - ntop.org
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

#ifndef _MOST_VISITED_LIST_H_
#define _MOST_VISITED_LIST_H_

/* A list used to identify the "Tops", for example Top Sites 
   (most visited sites, used by the host and interface) */
class MostVisitedList {
private:
  /* Variables used by top sites periodic update */
  u_int8_t current_cycle;
  u_int32_t max_num_items;

  FrequentStringItems *top_data;
  char *old_data, *shadow_old_data;

  void getCurrentTime(struct tm *t_now);
  void deserializeTopData(char* redis_key_current);

public:
  MostVisitedList(u_int32_t _max_num_items);
  ~MostVisitedList();

  void resetTopSitesData(u_int32_t iface_id, char *extra_info, char *hashkey);
  void saveOldData(u_int32_t iface_id, char *additional_key_info, char *hashkey);
  void serializeDeserialize(u_int32_t iface_id, 
			    bool do_serialize, 
			    char *extra_info, 
			    char *info_subject, 
			    char *hour_hashkey, 
			    char *day_hashkey);
  void lua(lua_State *vm, char *name, char *old_name);
  void clear() { if(top_data) top_data->clear(); }
  inline void incrVisitedData(char *data, u_int32_t num) { if(top_data) top_data->add(data, num); };
};

#endif /* _MOST_VISITED_LIST_H_ */
