/*
 *
 * (C) 2013-24 - ntop.org
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

#include "flow_checks_includes.h"

bool CustomFlowLuaScriptAlert::addScript(const std::string& name, const std::string& title,
                                         const std::string& msg) {
  for (const Script& sc : scripts)
    if (sc.name == name) return (false);

  scripts.push_back({name, title, msg});
  return (true);
}

/* ***************************************************** */

ndpi_serializer* CustomFlowLuaScriptAlert::getAlertJSON(ndpi_serializer* serializer) {
  std::string msg, titles;

  if (serializer == NULL) return (serializer);

  for (const Script& sc : scripts) {
    if (!msg.empty()) msg += " | ", titles += ", ";
    msg += sc.msg, titles += sc.title;
  }

  if (!msg.empty()) ndpi_serialize_string_string(serializer, "alert.message", msg.c_str());

  /*
    "custom_script": { "title": "ciao, pippo",
                       "scripts": { "ciao.lua": { "title": "ciao", "message": "..." }, ... } }
    titles: shown by the GUI; scripts: one entry per script, filtered by title
  */
  if (!scripts.empty()) {
    ndpi_serialize_start_of_block(serializer, "custom_script");
    ndpi_serialize_string_string(serializer, "title", titles.c_str());
    ndpi_serialize_start_of_block(serializer, "scripts");

    for (const Script& sc : scripts) {
      ndpi_serialize_start_of_block(serializer, sc.name.c_str());
      ndpi_serialize_string_string(serializer, "title", sc.title.c_str());
      ndpi_serialize_string_string(serializer, "message", sc.msg.c_str());
      ndpi_serialize_end_of_block(serializer);
    }

    ndpi_serialize_end_of_block(serializer);
    ndpi_serialize_end_of_block(serializer);
  }

  return (serializer);
}
