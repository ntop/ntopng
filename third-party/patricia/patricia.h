/*
 * $Id: patricia.h,v 1.6 2005/12/07 20:53:01 dplonka Exp $
 * Dave Plonka <plonka@doit.wisc.edu>
 *
 * This product includes software developed by the University of Michigan,
 * Merit Network, Inc., and their contributors. 
 *
 * This file had been called "radix.h" in the MRT sources.
 *
 * I renamed it to "patricia.h" since it's not an implementation of a general
 * radix trie.  Also, pulled in various requirements from "mrt.h" and added
 * some other things it could be used as a standalone API.

 https://github.com/deepfield/MRT/blob/master/COPYRIGHT

 Copyright (c) 1999-2013
 
 The Regents of the University of Michigan ("The Regents") and Merit
 Network, Inc.
 
 Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 
 Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
*/

#ifndef _PATRICIA_H
#define _PATRICIA_H

#define HAVE_IPV6

/* typedef unsigned int u_int; */
/* { from defs.h */
#define prefix_touchar(prefix) ((u_char *)&(prefix)->add.sin)
#define MAXLINE 1024
#define BIT_TEST(f, b)  ((f) & (b))
/* } */

#define addroute make_and_lookup

#include <sys/types.h> /* for u_* definitions (on FreeBSD 5) */

#include <errno.h> /* for EAFNOSUPPORT */
#ifndef EAFNOSUPPORT
#  defined EAFNOSUPPORT WSAEAFNOSUPPORT
#else
#ifndef WIN32
#  include <netinet/in.h> /* for struct in_addr */
#endif
#endif

#ifndef WIN32
#include <sys/socket.h> /* for AF_INET */
#else
#include <winsock2.h>
#include <ws2tcpip.h> /* IPv6 */

typedef u_char  u_int8_t;
typedef u_short u_int16_t;
typedef unsigned int   u_int32_t;
typedef unsigned __int64 u_int64_t;

#endif

/* { from mrt.h */

typedef struct the_prefix4_t {
    unsigned short family;		/* AF_INET | AF_INET6 */
    unsigned short bitlen;		/* same as mask? */
    int ref_count;		/* reference count */
    struct in_addr sin;
} prefix4_t;

typedef struct the_prefix_t {
    unsigned short family;		/* AF_INET | AF_INET6 */
    unsigned short bitlen;		/* same as mask? */
    int ref_count;		/* reference count */
    union {
		struct in_addr sin;
#ifdef HAVE_IPV6
		struct in6_addr sin6;
#endif /* IPV6 */
    } add;
} prefix_t;

/* } */

typedef struct _patricia_node_t {
   u_int bit;			/* flag if this node used */
   prefix_t *prefix;		/* who we are in patricia tree */
   struct _patricia_node_t *l, *r;	/* left and right children */
   struct _patricia_node_t *parent;/* may be used */
   void *data;			/* pointer to data */
  u_int16_t user_data;		/* user data information (ex. route flap info) */
} patricia_node_t;

typedef struct _patricia_tree_t {
   patricia_node_t 	*head;
   u_int		maxbits;	/* for IP, 32 bit addresses */
   int num_active_node;		/* for debug purpose */
} patricia_tree_t;

typedef void (*void_fn_t)(void *data);
typedef void (*void_fn2_t)(prefix_t *prefix, void *data);


patricia_node_t *patricia_search_exact (patricia_tree_t *patricia, prefix_t *prefix);
patricia_node_t *patricia_search_best (patricia_tree_t *patricia, prefix_t *prefix);
patricia_node_t * patricia_search_best2 (patricia_tree_t *patricia, prefix_t *prefix, 
				   int inclusive);
patricia_node_t *patricia_lookup (patricia_tree_t *patricia, prefix_t *prefix);
void patricia_remove (patricia_tree_t *patricia, patricia_node_t *node);
patricia_tree_t *New_Patricia (int maxbits);
void Clear_Patricia (patricia_tree_t *patricia, void_fn_t func);
void Destroy_Patricia (patricia_tree_t *patricia, void_fn_t func);
void patricia_process (patricia_tree_t *patricia, void_fn2_t func);

/* { from demo.c */

prefix_t *
ascii2prefix (int family, char *string);

patricia_node_t *
make_and_lookup (patricia_tree_t *tree, char *string);

/* } */

#define PATRICIA_MAXBITS	(sizeof(struct in6_addr) * 8)
#define PATRICIA_NBIT(x)        (0x80 >> ((x) & 0x7f))
#define PATRICIA_NBYTE(x)       ((x) >> 3)

#define PATRICIA_DATA_GET(node, type) (type *)((node)->data)
#define PATRICIA_DATA_SET(node, value) ((node)->data = (void *)(value))

#define PATRICIA_WALK(Xhead, Xnode) \
    do { \
        patricia_node_t *Xstack[PATRICIA_MAXBITS+1]; \
        patricia_node_t **Xsp = Xstack; \
        patricia_node_t *Xrn = (Xhead); \
        while ((Xnode = Xrn)) { \
            if (Xnode->prefix)

#define PATRICIA_WALK_ALL(Xhead, Xnode) \
do { \
        patricia_node_t *Xstack[PATRICIA_MAXBITS+1]; \
        patricia_node_t **Xsp = Xstack; \
        patricia_node_t *Xrn = (Xhead); \
        while ((Xnode = Xrn)) { \
	    if (1)

#define PATRICIA_WALK_BREAK { \
	    if (Xsp != Xstack) { \
		Xrn = *(--Xsp); \
	     } else { \
		Xrn = (patricia_node_t *) 0; \
	    } \
	    continue; }

#define PATRICIA_WALK_END \
            if (Xrn->l) { \
                if (Xrn->r) { \
                    *Xsp++ = Xrn->r; \
                } \
                Xrn = Xrn->l; \
            } else if (Xrn->r) { \
                Xrn = Xrn->r; \
            } else if (Xsp != Xstack) { \
                Xrn = *(--Xsp); \
            } else { \
                Xrn = (patricia_node_t *) 0; \
            } \
        } \
    } while (0)

#endif /* _PATRICIA_H */

/*************************


   [newtool.gif]
   
MRT Credits

    The Multi-Threaded Routing Toolkit
     _________________________________________________________________
   
   MRT was developed by [1]Merit Network, Inc., under National Science
   Foundation grant NCR-9318902, "Experimentation with Routing Technology
   to be Used for Inter-Domain Routing in the Internet."
   
    Current MRT Staff
    
     * [2]Craig Labovitz <labovit@merit.edu>
     * [3]Makaki Hirabaru <masaki@merit.edu>
     * [4]Farnam Jahanian <farnam@eecs.umich.edu>
     * Susan Hares <skh@merit.edu>
     * Susan R. Harris <srh@merit.edu>
     * Nathan Binkert <binkertn@eecs.umich.edu>
     * Gerald Winters <gerald@merit.edu>
       
    Project Alumni
    
     * [5]Marc Unangst <mju@merit.edu>
     * John Scudder <jgs@ieng.com>
       
   The BGP4+ extension was originally written by Francis Dupont
   <Francis.Dupont@inria.fr>.
   
   The public domain Struct C-library of linked list, hash table and
   memory allocation routines was developed by Jonathan Dekock
   <dekock@cadence.com>.
   
   Susan Rebecca Harris <srh@merit.edu> provided help with the
   documentation.
   David Ward <dward@netstar.com> provided bug fixes and helpful
   suggestions.
   Some sections of code and architecture ideas were taken from the GateD
   routing daemon.
   
   The first port to Linux with IPv6 was done by Pedro Roque
   <roque@di.fc.ul.pt>. Some interface routines to the Linux kernel were
   originally written by him.
   
   Alexey Kuznetsov made enhancements to 1.4.3a and fixed the Linux
   kernel intarface. Linux's netlink interface was written, referring to
   his code "iproute2".
   
   We would also like to thank our other colleagues in Japan, Portugal,
   the Netherlands, the UK, and the US for their many contributions to
   the MRT development effort.
     _________________________________________________________________
   
   Cisco is a registered trademark of Cisco Systems Inc.
     _________________________________________________________________
                                                                         
        Merit Network 4251 Plymouth Road Suite C Ann Arbor, MI 48105-2785
                                                             734-764-9430
                                                           info@merit.edu
     _________________________________________________________________
                                                                         
                                               © 1999 Merit Network, Inc.
                                                         [6]www@merit.edu

References

   1. http://www.merit.edu/
   2. http://www.merit.edu/~labovit
   3. http://www.merit.edu/~masaki
   4. http://www.eecs.umich.edu/~farnam
   5. http://www.contrib.andrew.cmu.edu/~mju/
   6. mailto:www@merit.edu

------------

Copyright (c) 1997, 1998, 1999


The Regents of the University of Michigan ("The Regents") and Merit Network,
Inc.  All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1.  Redistributions of source code must retain the above 
    copyright notice, this list of conditions and the 
    following disclaimer.
2.  Redistributions in binary form must reproduce the above 
    copyright notice, this list of conditions and the 
    following disclaimer in the documentation and/or other 
    materials provided with the distribution.
3.  All advertising materials mentioning features or use of 
    this software must display the following acknowledgement:  
This product includes software developed by the University of Michigan, Merit
Network, Inc., and their contributors. 
4.  Neither the name of the University, Merit Network, nor the
    names of their contributors may be used to endorse or 
    promote products derived from this software without 
    specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  


************************ */
