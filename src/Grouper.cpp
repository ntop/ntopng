/*
 *
 * (C) 2015-16 - ntop.org
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
Grouper::Grouper(const char* dimension_){
  if (!dimension_){
    dimension = INVALID;
    return;
  }

  if(!strcmp(dimension_, (char*)"asn"))
    dimension = ASN;
  else if(!strcmp(dimension_, (char*)"os"))
    dimension = OS;
  else if(!strcmp(dimension_, (char*)"country"))
    dimension = COUNTRY;
  else
    dimension = INVALID;
}


/* *************************************** */
GrouperEntry* Grouper::getGrouperEntryAt(const char *group_key, const char *label){
  if (!group_key)
    return NULL;

  string k(group_key);
  map<string, GrouperEntry*>::const_iterator it;

  if((it = string_grouper.find(k)) == string_grouper.end()){
    GrouperEntry *ge;
    if((ge = new(std::nothrow) GrouperEntry(label)) == NULL){
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to allocate memory for a GrouperEntry.");
      return NULL;
    }
    string_grouper.insert(make_pair(k, ge));

  }
  return string_grouper[k];
}

/* *************************************** */
GrouperEntry* Grouper::getGrouperEntryAt(int group_key, const char *label){
  map<int, GrouperEntry*>::const_iterator it;
  if((it = number_grouper.find(group_key)) == number_grouper.end()){
    GrouperEntry *ge;
    if((ge = new(std::nothrow) GrouperEntry(label)) == NULL){
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to allocate memory for a GrouperEntry.");
      return NULL;
    }
    number_grouper.insert(make_pair(group_key, ge));
  }
  return number_grouper[group_key];
}

/* *************************************** */
void Grouper::print(){
  map<int,    GrouperEntry*>::const_iterator iti;
  map<string, GrouperEntry*>::const_iterator its;
  for(iti = number_grouper.begin(); iti != number_grouper.end(); iti++){
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "key: %i", iti->first);
    iti->second->print();
  }
  for(its = string_grouper.begin(); its != string_grouper.end(); its++){
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "key: %s", its->first.c_str());
    its->second->print();
  }
}

/* *************************************** */
Grouper::~Grouper(){
  map<int,    GrouperEntry*>::iterator iti;
  map<string, GrouperEntry*>::iterator its;

  for(iti = number_grouper.begin(); iti != number_grouper.end(); iti++)
    if (iti->second) delete iti->second, iti->second = NULL;

  for(its = string_grouper.begin(); its != string_grouper.end(); its++)
    if(its->second) delete its->second, its->second = NULL;

  number_grouper.clear();
  string_grouper.clear();
}


/* *************************************** */
void Grouper::group(Host *h){
  if(!h)
    return;
  GrouperEntry *ge = NULL;
  if (dimension == ASN)
    ge = getGrouperEntryAt(h->get_asn(), h->get_asname());
  else if(dimension == COUNTRY)
    ge = getGrouperEntryAt(h->get_country(), h->get_country());

  if(!ge)
    return;
  ge->incStats();

}

/* *************************************** */

void Grouper::lua(lua_State* vm) {
  map<int,    GrouperEntry*>::iterator iti;
  map<string, GrouperEntry*>::iterator its;

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "numGroups", numEntries());

  lua_newtable(vm);
  for(iti = number_grouper.begin(); iti != number_grouper.end(); iti++)
    iti->second->lua(vm);

  for(its = string_grouper.begin(); its != string_grouper.end(); its++)
    its->second->lua(vm);

  lua_pushstring(vm, "groups"); // Key
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
