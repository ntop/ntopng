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

#ifndef _SERIALIZABLE_ELEMENT_H_

class SerializableElement {
 protected:
  static json_object* deserializeJson(const char *key);

  /* Virtual */
  virtual char* getSerializationKey(char *buf, uint bufsize) = 0;
  virtual void deserialize(json_object *obj) = 0;
  virtual void serialize(json_object *obj, DetailsLevel details_level) = 0;

 public:
  bool serializeToRedis();
  bool deserializeFromRedis();
  bool deleteRedisSerialization();
};

#endif
