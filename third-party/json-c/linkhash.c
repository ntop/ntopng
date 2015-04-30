/*
 * $Id: linkhash.c,v 1.4 2006/01/26 02:16:28 mclark Exp $
 *
 * Copyright (c) 2004, 2005 Metaparadigm Pte. Ltd.
 * Michael Clark <michael@metaparadigm.com>
 * Copyright (c) 2009 Hewlett-Packard Development Company, L.P.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the MIT license. See COPYING for details.
 *
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stddef.h>
#include <limits.h>

#include "linkhash.h"

void lh_abort(const char *msg, ...)
{
	va_list ap;
	va_start(ap, msg);
	vprintf(msg, ap);
	va_end(ap);
	exit(1);
}

unsigned long lh_ptr_hash(const void *k)
{
	/* CAW: refactored to be 64bit nice */
	return (unsigned long)((((ptrdiff_t)k * LH_PRIME) >> 4) & ULONG_MAX);
}

int lh_ptr_equal(const void *k1, const void *k2)
{
	return (k1 == k2);
}

unsigned long lh_char_hash(const void *k)
{
	unsigned int h = 0;
	const char* data = (const char*)k;
 
	while( *data!=0 ) h = h*129 + (unsigned int)(*data++) + LH_PRIME;

	return h;
}

int lh_char_equal(const void *k1, const void *k2)
{
	return (strcmp((const char*)k1, (const char*)k2) == 0);
}

struct lh_table* lh_table_new(int size, const char *name,
			      lh_entry_free_fn *free_fn,
			      lh_hash_fn *hash_fn,
			      lh_equal_fn *equal_fn)
{
	int i;
	struct lh_table *t;

	t = (struct lh_table*)calloc(1, sizeof(struct lh_table));
	if(!t) lh_abort("lh_table_new: calloc failed\n");
	t->count = 0;
	t->size = size;
	t->name = name;
	t->table = (struct lh_entry*)calloc(size, sizeof(struct lh_entry));
	if(!t->table) lh_abort("lh_table_new: calloc failed\n");
	t->free_fn = free_fn;
	t->hash_fn = hash_fn;
	t->equal_fn = equal_fn;
	for(i = 0; i < size; i++) t->table[i].k = LH_EMPTY;
	return t;
}

struct lh_table* lh_kchar_table_new(int size, const char *name,
				    lh_entry_free_fn *free_fn)
{
	return lh_table_new(size, name, free_fn, lh_char_hash, lh_char_equal);
}

struct lh_table* lh_kptr_table_new(int size, const char *name,
				   lh_entry_free_fn *free_fn)
{
	return lh_table_new(size, name, free_fn, lh_ptr_hash, lh_ptr_equal);
}

void lh_table_resize(struct lh_table *t, int new_size)
{
	struct lh_table *new_t;
	struct lh_entry *ent;

	new_t = lh_table_new(new_size, t->name, NULL, t->hash_fn, t->equal_fn);
	ent = t->head;
	while(ent) {
		lh_table_insert(new_t, ent->k, ent->v);
		ent = ent->next;
	}
	free(t->table);
	t->table = new_t->table;
	t->size = new_size;
	t->head = new_t->head;
	t->tail = new_t->tail;
	t->resizes++;
	free(new_t);
}

void lh_table_free(struct lh_table *t)
{
	struct lh_entry *c;
	for(c = t->head; c != NULL; c = c->next) {
		if(t->free_fn) {
			t->free_fn(c);
		}
	}
	free(t->table);
	free(t);
}


int lh_table_insert(struct lh_table *t, void *k, const void *v)
{
	unsigned long h, n;

	t->inserts++;
	if(t->count >= t->size * LH_LOAD_FACTOR) lh_table_resize(t, t->size * 2);

	h = t->hash_fn(k);
	n = h % t->size;

	while( 1 ) {
		if(t->table[n].k == LH_EMPTY || t->table[n].k == LH_FREED) break;
		t->collisions++;
		if ((int)++n == t->size) n = 0;
	}

	t->table[n].k = k;
	t->table[n].v = v;
	t->count++;

	if(t->head == NULL) {
		t->head = t->tail = &t->table[n];
		t->table[n].next = t->table[n].prev = NULL;
	} else {
		t->tail->next = &t->table[n];
		t->table[n].prev = t->tail;
		t->table[n].next = NULL;
		t->tail = &t->table[n];
	}

	return 0;
}


struct lh_entry* lh_table_lookup_entry(struct lh_table *t, const void *k)
{
	unsigned long h = t->hash_fn(k);
	unsigned long n = h % t->size;
	int count = 0;

	t->lookups++;
	while( count < t->size ) {
		if(t->table[n].k == LH_EMPTY) return NULL;
		if(t->table[n].k != LH_FREED &&
		   t->equal_fn(t->table[n].k, k)) return &t->table[n];
		if ((int)++n == t->size) n = 0;
		count++;
	}
	return NULL;
}


const void* lh_table_lookup(struct lh_table *t, const void *k)
{
	void *result;
	lh_table_lookup_ex(t, k, &result);
	return result;
}

json_bool lh_table_lookup_ex(struct lh_table* t, const void* k, void **v)
{
	struct lh_entry *e = lh_table_lookup_entry(t, k);
	if (e != NULL) {
		if (v != NULL) *v = (void *)e->v;
		return TRUE; /* key found */
	}
	if (v != NULL) *v = NULL;
	return FALSE; /* key not found */
}

int lh_table_delete_entry(struct lh_table *t, struct lh_entry *e)
{
	ptrdiff_t n = (ptrdiff_t)(e - t->table); /* CAW: fixed to be 64bit nice, still need the crazy negative case... */

	/* CAW: this is bad, really bad, maybe stack goes other direction on this machine... */
	if(n < 0) { return -2; }

	if(t->table[n].k == LH_EMPTY || t->table[n].k == LH_FREED) return -1;
	t->count--;
	if(t->free_fn) t->free_fn(e);
	t->table[n].v = NULL;
	t->table[n].k = LH_FREED;
	if(t->tail == &t->table[n] && t->head == &t->table[n]) {
		t->head = t->tail = NULL;
	} else if (t->head == &t->table[n]) {
		t->head->next->prev = NULL;
		t->head = t->head->next;
	} else if (t->tail == &t->table[n]) {
		t->tail->prev->next = NULL;
		t->tail = t->tail->prev;
	} else {
		t->table[n].prev->next = t->table[n].next;
		t->table[n].next->prev = t->table[n].prev;
	}
	t->table[n].next = t->table[n].prev = NULL;
	return 0;
}


int lh_table_delete(struct lh_table *t, const void *k)
{
	struct lh_entry *e = lh_table_lookup_entry(t, k);
	if(!e) return -1;
	return lh_table_delete_entry(t, e);
}

int lh_table_length(struct lh_table *t)
{
	return t->count;
}
