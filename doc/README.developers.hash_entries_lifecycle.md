Introduction
============

ntopng heavily relies on hash tables to keep flows, hosts, autonomous systems and other entries in memory. Hash tables are accessed concurrently by several threads:
- The thread that capture packets or receives flows. Operations performed in this thread are referred to as _inline_, all the other operations are referred to as _offline_.
- A periodic thread that updates stats such as hosts throughputs.
- Periodic threads that execute lua scripts (e.g., `minute.lua`, `hourly.lua`) to write traffic timeseries, trigger alerts, and perform other operations.
- Web server threads accessing the hash table when the user is browsing the ntopng web GUI.


Concurrent accesses require special care to prevent race conditions or even crashes.

Hash tables in the code, such as the `FlowHash` and the `HostHash`, inherit from class `GenericHashTable`. Hash table entries, such as the `Host` and the `Flow`, inherit from class `GenericHashEntry`.

Hash Table Entries Lifecycle
----------------------------

Hash entries are always instantiated, added to their hash table, and deleted _inline_. At the same time, other threads are allowed to access the hash table. For this reason, to guarantee no thread is accessing an entry that is being deleted or added, resulting in inconsistent accesses or even crashes, a lifecycle is defined an implemented for every hash table entry.

The lifecycle is implemented as a state machine with the following states:

- `hash_entry_state_active`. This state is the default one which is set as soon as any of the `GenericHashEntry`-inherited hash entry is instantiated _inline_.
- `hash_entry_state_idle`. This state is set by method `GenericHash::purgeIdle` which is called _inline_ and is used to explicitly mark the entry as idle. Once the entry has been marked as `hash_entry_state_idle`, it won't be returned to any of the threads that are accessing the hash table with one exception: an offline periodic thread which will perform an extra transition to state `hash_entry_state_ready_to_be_purged`.
- `hash_entry_state_ready_to_be_purged`. This state is set by an offline periodic thread, generally in method `updateStats`, only after the inline thread has set state `hash_entry_state_idle`. This guarantees that also a offline thread has seen the entry before cleaning it up and freeing its memory. Once this state has been set, the inline-thread will perform the actual delete to free the memory.

The following diagram recaps the states transitions

```
             ..new..
                |
                |
                v
      hash_entry_state_active
                |
                | [inline]
                v
      hash_entry_state_idle
                |
                | [offline]
                v
      hash_entry_state_ready_to_be_purged
                |
                |
                v
          ...deleted...
```

Following are some code snippets that try and demonstrate how the lifecycle state machine is handled at runtime for `Flows`. The very same operations are performed for all the other hash entries such as `Hosts` and `AutonomousSystems`.
 
Assuming a new flow is detected, inline method `NetworkInterface::getFlow` instantiates a `Flow` and adds it to the `flows_hash` hash table with a `flows_hash->add` call. From this point on, the flow is in state `hash_entry_state_active`.

Periodically, inline method `GenericHash::purgeIdle` walks the `flows_hash` to check for idle flows and possibly do their transition to state `hash_entry_state_idle`. To check whether an entry is idle, `is_hash_entry_state_idle_transition_ready()` is called and the transition is done when this call returns true: 

```
if(head_state == hash_entry_state_active && head->is_hash_entry_state_idle_transition_ready())
  head->set_hash_entry_state_idle();
```

At this point, an offline periodic thread calls `Flow::update_hosts_stats` in which the transition to `hash_entry_state_ready_to_be_purged` is performed if the entry was in `hash_entry_state_idle`:

```
if(get_state() == hash_entry_state_idle)
  set_hash_entry_state_ready_to_be_purged();
```

Finally, inline method `GenericHash::purgeIdle`, while walking the `flows_hash`, encounters the `hash_entry_state_ready_to_be_purged` one last time and it performs the delete as follow:

```
if(head_state == hash_entry_state_ready_to_be_purged)
  delete(head);
```

Locks
-----

As additions and deletions to the hash tables are performed _inline_, there is no need to lock when the same _inline_ thread accesses the hash table. Indeed, if the thread is accessing the hash table, it will not delete or add entries to it. For this reason, methods such as `HostHash::get` take a parameter `is_inline_call` and will only `lock` the hash table when called _offline_.

Hash table locks are implemented in class `RwLock` which uses pthread read-write locks:
- _offline_ operations always acquire read locks `RwLock::rdlock` when accessing any hash table. This guarantees an elevated degree of parallelism as multiple _offline_ threads can access the same hash table entries simultaneously.
- _inline_ additions are performed withouth locks as list access won't break any concurrent hash table access.
- _inline_ deletions, only performed in `GenericHash::purgeIdle`, use a `RwLock::trywrlock`. When there is no other reader the lock is aquired successfully and the `GenericHash::purgeIdle` is free to delete entries from the hash table. When there are one or more readers, the lock is not acquired and `GenericHash::purgeIdle` will try to acquire the lock again during a successive cycle.





