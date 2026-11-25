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

#ifndef _SCRIPT_REFERENCES_H_
#define _SCRIPT_REFERENCES_H_

/*
  Hash entries (hosts, MACs) looked up (not inline) by the Lua script running
  on this thread. Each entry is referenced once, under the lock of its hash
  bucket, and released when the script is over, so that the purge
  (GenericHash::purgeQueuedIdleEntries) cannot free it while the script is
  still using it. Lives on the stack of the functions that run a script.
*/
class ScriptReferences {
 private:
  inline static thread_local ScriptReferences* current = NULL;
  ScriptReferences* outer; /* A script can be run while another one is running */
  std::set<GenericHashEntry*> entries;

 public:
  ScriptReferences() { outer = current, current = this; }
  ~ScriptReferences() {
    for (std::set<GenericHashEntry*>::iterator it = entries.begin();
         it != entries.end(); ++it)
      (*it)->decUses(); /* incUses in hold() */

    current = outer;
  }

  /* NOTE: to be called with the lock of the bucket of the entry held.
     GenericHashEntry::incUses() on purpose: Mac::incUses() also updates the
     device type */
  static inline void hold(GenericHashEntry* e) {
    if (current && current->entries.insert(e).second) e->incUses();
  }
};

#endif /* _SCRIPT_REFERENCES_H_ */
