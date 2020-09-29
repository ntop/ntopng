/*
 *
 * (C) 2013-20 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the ho2pe that it will be useful,
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

/* ************************************ */

GenericHash::GenericHash(NetworkInterface *_iface, u_int _num_hashes,
			 u_int _max_hash_size, const char *_name) {
  num_hashes = _num_hashes;
  current_size = 0;
  /* Allow the total number of entries (that is, active and those idle but still not yet purged)
     to be 30% more than the maximum hash table size specified. This prevents memory from growing
     indefinitely when for example the purging is slow. */
  max_hash_size = _max_hash_size * 1.3;
  last_entry_id = 0;
  purge_step = max_val(num_hashes / PURGE_FRACTION, 1);
  walk_idle_start_hash_id = 0;
  name = strdup(_name ? _name : "???");
  memset(&entry_state_transition_counters, 0, sizeof(entry_state_transition_counters));

  iface = _iface;
  idle_entries = idle_entries_shadow = NULL;

  table = new GenericHashEntry*[num_hashes];
  for(u_int i = 0; i < num_hashes; i++)
    table[i] = NULL;

  locks = new RwLock*[num_hashes];
  for(u_int i = 0; i < num_hashes; i++) locks[i] = new RwLock();

  idle_entries_in_use = new vector<GenericHashEntry*>;

  last_purged_hash = _num_hashes - 1;
}

/* ************************************ */

GenericHash::~GenericHash() {
  cleanup();

  delete[] table;

  for(u_int i = 0; i < num_hashes; i++) delete(locks[i]);
  delete[] locks;
  free(name);
}

/* ************************************ */

void GenericHash::cleanup() {
  vector<GenericHashEntry*> **ghvs[] = { &idle_entries, &idle_entries_shadow, &idle_entries_in_use };

  for(u_int i = 0; i < sizeof(ghvs) / sizeof(ghvs[0]); i++) {
    if(*ghvs[i]) {
      if(!(*ghvs[i])->empty()) {
	for(vector<GenericHashEntry*>::const_iterator it = (*ghvs[i])->begin(); it != (*ghvs[i])->end(); ++it) {
	  delete *it;
	}
      }

      delete *ghvs[i];
      *ghvs[i] = NULL;
    }
  }

  for(u_int i = 0; i < num_hashes; i++) {
    if(table[i] != NULL) {
      GenericHashEntry *head = table[i];

      while(head) {
	GenericHashEntry *next = head->next();

	delete(head);
	head = next;
      }

      table[i] = NULL;
    }
  }

  current_size = 0;
}

/* ************************************ */

bool GenericHash::add(GenericHashEntry *h, bool do_lock) {
  if(hasEmptyRoom()) {
    u_int32_t hash = (h->key() % num_hashes);

    if(do_lock)
      locks[hash]->wrlock(__FILE__, __LINE__);

    h->set_hash_table(this);
    h->set_hash_entry_id(last_entry_id++);
    h->set_next(table[hash]);
    table[hash] = h;
    current_size++;

    if(do_lock)
      locks[hash]->unlock(__FILE__, __LINE__);

    return(true);
  } else
    return(false);
}

/* ************************************ */

void GenericHash::purgeQueuedIdleEntries() {
 vector<GenericHashEntry*> *cur_idle = NULL;
#ifdef WALK_DEBUG
 u_int32_t num_purged = entry_state_transition_counters.num_purged;
#endif
 
  if(idle_entries) {
    cur_idle = idle_entries;
    idle_entries = NULL;
  }

  if(cur_idle) {
    if(!cur_idle->empty()) {      
      for(vector<GenericHashEntry*>::const_iterator it = cur_idle->begin(); it != cur_idle->end(); ++it) {


	/* In case of flow dump the uses number might be increased (0 -> 1) */
	if((*it)->getUses() == 0) {
	  /*
	    No one is using the idle entry. Safe to execute the walker one last time and delete the entry.
	   */
	  delete *it; /* Delete the entry */
	  entry_state_transition_counters.num_purged++;
	  /* https://www.techiedelight.com/remove-elements-vector-inside-loop-cpp/ */
	  /* cur_idle->erase(it--); */
	} else {
	  /*
	    Entry is still in use. This can happen for example when there's a very slow
	    hash table walker running, or when the thread in charge of dumping flows
	    still have to process the flow.

	    In this case, the entry is moved to another vector which is in exclusive use by this thread
	   */
	  idle_entries_in_use->push_back(*it);
#if DEBUG_FLOW_DUMP
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][%s] Skipping entry in use [purged: %u]",
				       __FUNCTION__, getInterface()->get_name(), entry_state_transition_counters.num_purged);
#endif
	  /* This entry will be deleted by the dumper after the dump completed */
	}
      }
    }
    
    delete cur_idle;
  }

  /*
    Try and delete all the entries which were found to be in-use when idle
   */
  for(vector<GenericHashEntry*>::iterator it = idle_entries_in_use->begin(); it != idle_entries_in_use->end(); ) {
    if((*it)->getUses() == 0) {
      delete *it; /* Free the entry memory */
      idle_entries_in_use->erase(it); /* Remove the entry from the vector */
      entry_state_transition_counters.num_purged++;
    } else
      ++it;
  }
  
#ifdef WALK_DEBUG
  if((num_purged != entry_state_transition_counters.num_purged) && (!strcmp(name, "FlowHash")))
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() [%s] [%u purged]",
				 __FUNCTION__, iface->get_description(),
				 entry_state_transition_counters.num_purged - num_purged);
#endif
}

/* ************************************ */

bool GenericHash::walk(u_int32_t *begin_slot,
		       bool walk_all,
		       bool (*walker)(GenericHashEntry *h, void *user_data, bool *entryMatched),
		       void *user_data) {
  bool found = false;
  u_int16_t tot_matched = 0;

  for(u_int hash_id = *begin_slot; hash_id < num_hashes; hash_id++) {
    if(table[hash_id] != NULL) {
      GenericHashEntry *head;

#ifdef WALK_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[walk] Locking %d [%p]", hash_id, locks[hash_id]);
#endif

      locks[hash_id]->rdlock(__FILE__, __LINE__);
      head = table[hash_id];

      while(head) {
	GenericHashEntry *next = head->next();

        /* FIXX get_state() does not always match idle() as the latter can be
         * overriden (e.g. Flow), leading to walking entries that are actually
         * idle even with walk_idle = false, what about using idle() here? */

	if(!head->idle()) {
	  bool matched = false;
	  bool rc = walker(head, user_data, &matched);

	  if(matched) tot_matched++;

	  if(rc) {
	    found = true;
	    break;
	  }
	}

	head = next;
      } /* while */

      locks[hash_id]->unlock(__FILE__, __LINE__);
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[walk] Unlocked %d", hash_id);

      if((tot_matched >= MIN_NUM_HASH_WALK_ELEMS) /* At least a few entries have been returned */
	 && (!walk_all)) {
	u_int32_t next_slot  = (hash_id == (num_hashes-1)) ? 0 /* start over */ : (hash_id+1);

	*begin_slot = next_slot;
#ifdef WALK_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "[walk] Over [nextSlot: %u][hash_id: %u][tot_matched: %u]",
				     next_slot, hash_id, tot_matched);
#endif

	return(found);
      }

      if(found)
	break;
    }
  }

  if(!found)
    *begin_slot = 0 /* start over */;

#ifdef WALK_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[walk] Over [tot_matched: %u]", tot_matched);
#endif

  return(found);
}

/* ************************************ */

/*
  Bucket Lifecycle

  Active -> Idle -> Ready to be Purged -> Purged
*/

u_int GenericHash::purgeIdle(const struct timeval * tv, bool force_idle) {
  u_int i, num_detached = 0, buckets_checked = 0;
  time_t now = time(NULL);
  /* Visit all entries when force_idle is true */
  u_int visit_fraction = !force_idle ? purge_step : num_hashes;
  size_t idle_entries_shadow_old_size;
  vector<GenericHashEntry*>::const_iterator it;

  if(!idle_entries) {
    idle_entries = idle_entries_shadow;
    try {
      idle_entries_shadow = new vector<GenericHashEntry*>;
    } catch(std::bad_alloc& ba) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Memory allocation error");
      return 0;
    }
  }

  idle_entries_shadow_old_size = idle_entries_shadow->size();

#ifdef WALK_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s @ %s] Begin purgeIdle() [begin index: %u][purge step: %u][size: %u][force_idle: %u]",
			       name, iface->get_name(), last_purged_hash, visit_fraction, getNumEntries(), force_idle ? 1 : 0);
#endif

  /* Visit at least MIN_NUM_VISITED_ENTRIES entries at each iteration regardless of the hash size */
  u_int j;

  for(j = 0; j < num_hashes; j++) {
    /*
      Initially visit the visit_fraction of the hash, but if we have
      visited too few elements we keep visiting until a minimum number
      of entries is reached
    */
    if((j > visit_fraction) && (buckets_checked > MIN_NUM_VISITED_ENTRIES))
      break;

    if(++last_purged_hash == num_hashes) last_purged_hash = 0;
    i = last_purged_hash;

    if(table[i] != NULL) {
      GenericHashEntry *head, *prev = NULL;

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[purge] Locking %d", i);
      if(!locks[i]->trywrlock(__FILE__, __LINE__))
	continue; /* Busy, will retry next round */

      head = table[i];

      while(head) {
	HashEntryState head_state = head->get_state();
	GenericHashEntry *next = head->next();

	head->periodic_stats_update(tv);

	buckets_checked++;

	switch(head_state) {
	case hash_entry_state_idle:
	  /* As an idle entry is always removed immediately from the hash table
	     This walk should never find any such entry */
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Unexpected state found [%u]", head_state);
	  break;

	case hash_entry_state_allocated:
	  /* TCP flows with 3WH not yet completed (or collected with no TCP flags) fall here */
	  /* Don't break */
	case hash_entry_state_flow_notyetdetected:
	  /* UDP flows or TCP flows for which the 3WH is completed but protocol hasn't been detected yet */
	  /* Don't break  */
	case hash_entry_state_flow_protocoldetected:
	  head->housekeep(now);

	  if(head_state == hash_entry_state_flow_protocoldetected)
	    /*
	      Transition to active if the protocol is detected
	     */
	    head->set_hash_entry_state_active();

	  if(force_idle) goto detach_idle_hash_entry;
	  break;

	case hash_entry_state_active:
	  if(
	     force_idle
	     || (
		 iface->is_purge_idle_interface()
		 /*  Allow idle entries with uses >= 0 to be removed from the hash table.
		     Those entries won't be deleted but it is good to remove them from the
		     hash table to make room for newer entries and to prevent them from starving
		     in the table (for example when the number of uses would increase)
		    && (head->getUses() == 0)
		 */
		 && head->is_hash_entry_state_idle_transition_ready())
	     ) {
	  detach_idle_hash_entry:
	    idle_entries_shadow->push_back(head); /* Found entry to purge */

	    if(!prev)
	      table[i] = next;
	    else
	      prev->set_next(next);

	    num_detached++, current_size--;
	    head = next;
	    continue;
	  }

	  /* If there hasn't been an active->idle transition, and thus head hasn't been detached,
	     it is safe to execute housekeep. This function is executed also for idle entries below. */
	  head->housekeep(now);
	  break;
	} /* switch */

	prev = head;
	head = next;
      } /* while */

      locks[i]->unlock(__FILE__, __LINE__);
    }
  }

#ifdef WALK_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][current_size: %u][visit_fraction: %u/%u (visited %u)][buckets_checked: %u]",
			       name, current_size, visit_fraction, num_hashes, j, buckets_checked);
#endif

  /* Actual idling can be performed when the hash table is no longer locked. */
  if(idle_entries_shadow->size() > idle_entries_shadow_old_size) {
    it = idle_entries_shadow->begin();
    advance(it, idle_entries_shadow_old_size);

    for(; it != idle_entries_shadow->end(); it++) {
      (*it)->set_hash_entry_state_idle();
      /* Now that the entry has been set to idle, housekeep can executed one last time */
      (*it)->housekeep(now);
      entry_state_transition_counters.num_idle_transitions++;
    }
  }

#ifdef WALK_DEBUG
  if(/* (num_detached > 0) && */ (!strcmp(name, "FlowHash")))
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "[%s @ %s] purgeIdle() [num_detached: %u][num_checked: %u][end index: %u][current_size: %u][visit_fraction: %u]",
				 name, iface->get_name(), num_detached, buckets_checked, last_purged_hash, current_size, visit_fraction);
#endif

  return(num_detached);
}

/* ************************************ */

u_int32_t GenericHash::getNumIdleEntries() const {
  return(ndpi_max(0, entry_state_transition_counters.num_idle_transitions - entry_state_transition_counters.num_purged));
};

/* ************************************ */

bool GenericHash::hasEmptyRoom() {
  /* The check below has been added to avoid adding entries when the system is under pressure */
  if((getNumIdleEntries() > 5000 /* Enable this mechanism when there is a consistent number of idle elements */) && (getNumIdleEntries() > getNumEntries())) {
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Hash full: [idle: %u][active: %u]", getNumIdleEntries(), getNumEntries());
    return(false);
  } else
    return((getNumEntries() + getNumIdleEntries() <= max_hash_size));
};

/* ************************************ */

void GenericHash::lua(lua_State *vm) {
  int64_t num_idle;

  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "max_hash_size", (u_int64_t)max_hash_size);

  /* Hash Entry states */
  lua_newtable(vm);

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] [total idle: %u][tot purged: %u][idle_entries_shadow: %u][idle_entries: %u][idle_entries_in_use: %u]",
			       name,
			       entry_state_transition_counters.num_idle_transitions,
			       entry_state_transition_counters.num_purged,
			       idle_entries_shadow ? idle_entries_shadow->size() : 0,
			       idle_entries ? idle_entries->size() : 0,
			       idle_entries_in_use ? idle_entries_in_use->size() : 0);
#endif

  num_idle = getNumIdleEntries();
  if(num_idle < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: unexpected number of entries in state [iface: %s][%s][hash_entry_state_idle: %i][num_idle_transitions: %u][num_purged: %u]",
				 iface ? iface->get_name(): "", name, num_idle, entry_state_transition_counters.num_idle_transitions, entry_state_transition_counters.num_purged);
  else
    lua_push_uint64_table_entry(vm, "hash_entry_state_idle", (u_int64_t)num_idle);

  lua_push_uint64_table_entry(vm, "hash_entry_state_active", (u_int64_t)getNumEntries());

  lua_pushstring(vm, "hash_entry_states");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_pushstring(vm, name ? name : "");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
