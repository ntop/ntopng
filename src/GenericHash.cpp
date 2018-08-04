/*
 *
 * (C) 2013-18 - ntop.org
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
  num_hashes = _num_hashes, max_hash_size = _max_hash_size, current_size = 0;
  purge_step = max_val(num_hashes / PURGE_FRACTION, 1);
  name = strdup(_name ? _name : "???");

  iface = _iface;
  table = new GenericHashEntry*[num_hashes];
  for(u_int i = 0; i < num_hashes; i++)
    table[i] = NULL;

  locks = new Mutex*[num_hashes];
  for(u_int i = 0; i < num_hashes; i++) locks[i] = new Mutex();

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
  for(u_int i = 0; i < num_hashes; i++)
    if(table[i] != NULL) {
      GenericHashEntry *head = table[i];

      while(head) {
	GenericHashEntry *next = head->next();

	delete(head);
	head = next;
      }
      table[i] = NULL;
    }
  current_size = 0;
}

/* ************************************ */

bool GenericHash::add(GenericHashEntry *h) {
  if(hasEmptyRoom()) {
    u_int32_t hash = (h->key() % num_hashes);

    if(false) {
      char buf[256];

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(): adding %s/%u",
				   __FUNCTION__, h->get_string_key(buf, sizeof(buf)), h->key());
    }

    locks[hash]->lock(__FILE__, __LINE__);
    h->set_next(table[hash]);
    table[hash] = h, current_size++;
    locks[hash]->unlock(__FILE__, __LINE__);

    return(true);
  } else
    return(false);
}

/* ************************************ */

bool GenericHash::remove(GenericHashEntry *h) {
  u_int32_t hash = (h->key() % num_hashes);

  if(table[hash] == NULL)
    return(false);
  else {
    GenericHashEntry *head, *prev = NULL;
    bool ret;

    locks[hash]->lock(__FILE__, __LINE__);

    head = table[hash];
    while(head && (!head->equal(h))) {
      prev = head;
      head = head->next();
    }

    if(head) {
      if(false) {
	char buf[256];

	ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(): removing %s",
				     __FUNCTION__, h->get_string_key(buf, sizeof(buf)));
      }

      if(prev != NULL)
	prev->set_next(head->next());
      else
	table[hash] = head->next();

      current_size--;

      ret = true;
    } else
      ret = false;

    locks[hash]->unlock(__FILE__, __LINE__);
    return(ret);
  }
}

/* ************************************ */

bool GenericHash::walk(u_int32_t *begin_slot,
		       bool walk_all,
		       bool (*walker)(GenericHashEntry *h, void *user_data, bool *entryMatched), void *user_data) {
  bool found = false;
  u_int16_t tot_matched = 0;

  if(ntop->getGlobals()->isShutdown())
    return(found);

  for(u_int hash_id = *begin_slot; hash_id < num_hashes; hash_id++) {
    if(table[hash_id] != NULL) {
      GenericHashEntry *head;

#if WALK_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[walk] Locking %d [%p]", hash_id, locks[hash_id]);
#endif

      locks[hash_id]->lock(__FILE__, __LINE__);
      head = table[hash_id];

      while(head) {
	GenericHashEntry *next = head->next();

	if(!head->idle() && !head->is_ready_to_be_purged()) {
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
#if WALK_DEBUG
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

#if WALK_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[walk] Over [tot_matched: %u]", tot_matched);
#endif

  return(found);
}

/* ************************************ */

/*
  Bucket Lifecycle

  Active -> Idle -> Ready to be Purged -> Purged
 */

u_int GenericHash::purgeIdle() {
  u_int i, num_purged = 0, buckets_checked = 0;

  if(ntop->getGlobals()->isShutdown()
     || purgeLock.is_locked())
    return(0);

#if WALK_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s @ %s] Begin purgeIdle() [begin index: %u][purge step: %u]",
				 name, iface->get_name(), last_purged_hash, purge_step);
#endif

  disablePurge();

  for(u_int j = 0; j < purge_step; j++) {
    if(++last_purged_hash == num_hashes) last_purged_hash = 0;
    i = last_purged_hash;

    if(table[i] != NULL) {
      GenericHashEntry *head, *prev = NULL;

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[purge] Locking %d", i);
      locks[i]->lock(__FILE__, __LINE__);
      head = table[i];

      while(head) {
	GenericHashEntry *next = head->next();

	buckets_checked++;
	if(head->is_ready_to_be_purged()) {
	  if(prev == NULL) {
	    table[i] = next;
	  } else {
	    prev->set_next(next);
	  }

	  num_purged++, current_size--;
	  delete(head);
	  head = next;
	} else {
	  /* Do the chores */
	  head->housekeep();

	  /* Purge at the next run */
	  if(head->idle())
	    head->set_to_purge();

	  prev = head;
	  head = next;
	}
      } /* while */

      locks[i]->unlock(__FILE__, __LINE__);
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[purge] Unlocked %d", i);
    }
  }

  enablePurge();

#if WALK_DEBUG
  if(/* (num_purged > 0) && */ (!strcmp(name, "FlowHash")))
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "[%s @ %s] purgeIdle() [num_purged: %u][num_checked: %u][end index: %u][current_size: %u]",
				 name, iface->get_name(), num_purged, buckets_checked, last_purged_hash, current_size);
#endif

  return(num_purged);
}

/* ************************************ */

GenericHashEntry* GenericHash::findByKey(u_int32_t key) {
  u_int32_t hash = key % num_hashes;
  GenericHashEntry *head = table[hash];

  if(head == NULL) return(NULL);

  locks[hash]->lock(__FILE__, __LINE__);
  while(head != NULL) {
    if((!head->idle()) && (!head->is_ready_to_be_purged()) && (head->key() == key))
      break;
    else
      head = head->next();
  }

  locks[hash]->unlock(__FILE__, __LINE__);

  return(head);
}
