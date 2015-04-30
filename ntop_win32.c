/*
 *
 * (C) 2013 - ntop.org
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

#ifdef WIN32


#include "ntop_win32.h"
#define _CRT_SECURE_NO_WARNINGS 1 /* Avoid Win warnings */

/* **************************************

   WIN32 MULTITHREAD STUFF
   
   ************************************** */

pthread_t pthread_self(void) { return(0); }

int pthread_create(pthread_t *threadId, void* notUsed, void *(*__start_routine) (void *), void* userParm) {
  DWORD dwThreadId, dwThrdParam = 1;
  
  (*threadId) = CreateThread(NULL, /* no security attributes */
			     0,            /* use default stack size */
			     (LPTHREAD_START_ROUTINE)__start_routine, /* thread function */
			     userParm,     /* argument to thread function */
			     0,            /* use default creation flags */
			     &dwThreadId); /* returns the thread identifier */

  if(*threadId != NULL)
    return(1);
  else
    return(0);
}

/* ************************************ */

void pthread_detach(pthread_t *threadId) {
  CloseHandle((HANDLE)*threadId);
}

/* ************************************ */

int pthread_join (pthread_t threadId, void **_value_ptr) {
  int rc = WaitForSingleObject(threadId, INFINITE);
  CloseHandle(threadId);
  return(rc);
}

/* ************************************ */

int pthread_mutex_init(pthread_mutex_t *mutex, char* notused) {
  (*mutex) = CreateMutex(NULL, FALSE, NULL);
  return(0);
}

/* ************************************ */

void pthread_mutex_destroy(pthread_mutex_t *mutex) {
  ReleaseMutex(*mutex);
  CloseHandle(*mutex);
}

/* ************************************ */

int pthread_mutex_lock(pthread_mutex_t *mutex) {

  if(*mutex == NULL) {
	printf("Error\n");
	return(-1);
  }

  WaitForSingleObject(*mutex, INFINITE);
  return(0);
}

/* ************************************ */

int pthread_mutex_trylock(pthread_mutex_t *mutex) {
  if(WaitForSingleObject(*mutex, 0) == WAIT_FAILED)
    return(1);
  else
    return(0);
}

/* ************************************ */

int pthread_mutex_unlock(pthread_mutex_t *mutex) {
  if(*mutex == NULL)
    printf("Error\n");
  return(!ReleaseMutex(*mutex));
}

/* ************************************ */

unsigned long waitForNextEvent(unsigned long ulDelay /* ms */) {
  unsigned long ulSlice = 1000L; /* 1 Second */

  while(ulDelay > 0L) {
    if(ulDelay < ulSlice)
      ulSlice = ulDelay;
    Sleep(ulSlice);
    ulDelay -= ulSlice;
  }

  return ulDelay;
}

unsigned int sleep(unsigned int seconds) { return(waitForNextEvent(seconds*1000)); }

#if 0
/* ************************************ */

/* Reentrant string tokenizer.  Generic version.

   Slightly modified from: glibc 2.1.3

   Copyright (C) 1991, 1996, 1997, 1998, 1999 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public License as
   published by the Free Software Foundation; either version 2 of the
   License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with the GNU C Library; see the file COPYING.LIB.  If not,
   write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.  */

char* strtok_r(char *s, const char *delim, char **save_ptr) {
  char *token;

  if (s == NULL)
    s = *save_ptr;

  /* Scan leading delimiters.  */
  s += strspn (s, delim);
  if (*s == '\0')
    return NULL;

  /* Find the end of the token.  */
  token = s;
  s = strpbrk (token, delim);
  if (s == NULL)
    /* This token finishes the string.  */
    *save_ptr = "";
  else {
    /* Terminate the token and make *SAVE_PTR point past it.  */
    *s = '\0';
    *save_ptr = s + 1;
  }

  return token;
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
/*!
 * \brief format an IPv4 address
 *
 * \return `dst' (as a const)
 *
 * \note
 *	\li (1) uses no statics
 *	\li (2) takes a u_char* not an in_addr as input
 */
const char *inet_ntop4(const u_char *src, char *dst, socklen_t size)
{
	char tmp[sizeof ("255.255.255.255") + 1] = "\0";
	int octet;
	int i;

	i = 0;
	for (octet = 0; octet <= 3; octet++) {

		if (src[octet]>255) {
			//__set_errno (ENOSPC);
			return (NULL);
		}
		tmp[i++] = '0' + src[octet] / 100;
		if (tmp[i - 1] == '0') {
			tmp[i - 1] = '0' + (src[octet] / 10 % 10);
			if (tmp[i - 1] == '0') i--;
		} else {
			tmp[i++] = '0' + (src[octet] / 10 % 10);
		}
		tmp[i++] = '0' + src[octet] % 10;
		tmp[i++] = '.';
	}
	tmp[i - 1] = '\0';

	if ((socklen_t)strlen(tmp)>size) {
		//__set_errno (ENOSPC);
		return (NULL);
	}

	return strcpy(dst, tmp);
}

#ifdef INET_IPV6
/*!
 * \brief convert IPv6 binary address into presentation (printable) format
 */
const char *inet_ntop6(const u_char *src, char *dst, socklen_t size)
{
	/*
	 * Note that int32_t and int16_t need only be "at least" large enough
	 * to contain a value of the specified size.  On some systems, like
	 * Crays, there is no such thing as an integer variable with 16 bits.
	 * Keep this in mind if you think this function should have been coded
	 * to use pointer overlays.  All the world's not a VAX.
	 */
	char tmp[sizeof ("ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255")], *tp;
	struct { int base, len; } best, cur;
	u_int words[8];
	int i;

	/*
	 * Preprocess:
	 *	Copy the input (bytewise) array into a wordwise array.
	 *	Find the longest run of 0x00's in src[] for :: shorthanding.
	 */
	memset(words, '\0', sizeof words);
	for (i = 0; i < 16; i += 2)
		words[i / 2] = (src[i] << 8) | src[i + 1];
	best.base = -1;
	cur.base = -1;
	for (i = 0; i < 8; i++) {
		if (words[i] == 0) {
			if (cur.base == -1)
				cur.base = i, cur.len = 1;
			else
				cur.len++;
		} else {
			if (cur.base != -1) {
				if (best.base == -1 || cur.len > best.len)
					best = cur;
				cur.base = -1;
			}
		}
	}
	if (cur.base != -1) {
		if (best.base == -1 || cur.len > best.len)
			best = cur;
	}
	if (best.base != -1 && best.len < 2)
		best.base = -1;

	/*
	 * Format the result.
	 */
	tp = tmp;
	for (i = 0; i < 8; i++) {
		/* Are we inside the best run of 0x00's? */
		if (best.base != -1 && i >= best.base &&
		    i < (best.base + best.len)) {
			if (i == best.base)
				*tp++ = ':';
			continue;
		}
		/* Are we following an initial run of 0x00s or any real hex? */
		if (i != 0)
			*tp++ = ':';
		/* Is this address an encapsulated IPv4? */
		if (i == 6 && best.base == 0 &&
		    (best.len == 6 || (best.len == 5 && words[5] == 0xffff))) {
			if (!inet_ntop4(src+12, tp, sizeof tmp - (tp - tmp)))
				return (NULL);
			tp += strlen(tp);
			break;
		}
		tp += sprintf(tp, "%x", words[i]);
	}
	/* Was it a trailing run of 0x00's? */
	if (best.base != -1 && (best.base + best.len) == 8)
		*tp++ = ':';
	*tp++ = '\0';

	/* Check for overflow, copy, and we're done. */
	if ((socklen_t)(tp - tmp) > size) {
		//__set_errno (ENOSPC);
		return (NULL);
	}
	return strcpy(dst, tmp);
}
#endif /* INET_IPV6 */

/*!
 * \brief like inet_aton() but without all the hexadecimal and shorthand.
 *
 * \return 1 if `src' is a valid dotted quad, else 0.
 *
 * \note does not touch `dst' unless it's returning 1.
 */
int inet_pton4(const char *src,u_char *dst)
{
	int saw_digit, octets, ch;
	u_char tmp[4], *tp;

	saw_digit = 0;
	octets = 0;
	*(tp = tmp) = 0;
	while ((ch = *src++) != '\0') {
		if (ch >= '0' && ch <= '9') {
			u_int newc = *tp * 10 + (ch - '0');
			if (newc>255)
				return (0);
			*tp = newc;
			if (! saw_digit) {
				if (++octets>4)
					return (0);
				saw_digit = 1;
			}
		} else if (ch == '.' && saw_digit) {
			if (octets == 4)
				return (0);
			*++tp = 0;
			saw_digit = 0;
		} else
			return (0);
	}
	if (octets < 4)
		return (0);
	memcpy(dst, tmp, 4);
	return 1;
}

#ifdef INET_IPV6
/*!
 * \brief convert presentation level address to network order binary form.
 *
 * \return 1 if `src' is a valid [RFC1884 2.2] address, else 0.
 *
 * \note
 *	\li (1) does not touch `dst' unless it's returning 1.
 *	\li (2) :: in a full address is silently ignored.
 */

/* http://ftp.samba.org/pub/unpacked/replace/inet_pton.c */
#define NS_INT16SZ	 2
#define NS_INADDRSZ	 4
#define NS_IN6ADDRSZ	16

int inet_pton6(const char *src, u_char *dst)
{
	static const char xdigits_l[] = "0123456789abcdef",
		xdigits_u[] = "0123456789ABCDEF";
	unsigned char tmp[NS_IN6ADDRSZ], *tp, *endp, *colonp;
	const char *xdigits, *curtok;
	int ch, saw_xdigit;
	unsigned int val;

	memset((tp = tmp), '\0', NS_IN6ADDRSZ);
	endp = tp + NS_IN6ADDRSZ;
	colonp = NULL;
	/* Leading :: requires some special handling. */
	if (*src == ':')
		if (*++src != ':')
			return (0);
	curtok = src;
	saw_xdigit = 0;
	val = 0;
	while ((ch = *src++) != '\0') {
		const char *pch;

		if ((pch = strchr((xdigits = xdigits_l), ch)) == NULL)
			pch = strchr((xdigits = xdigits_u), ch);
		if (pch != NULL) {
			val <<= 4;
			val |= (pch - xdigits);
			if (val > 0xffff)
				return (0);
			saw_xdigit = 1;
			continue;
		}
		if (ch == ':') {
			curtok = src;
			if (!saw_xdigit) {
				if (colonp)
					return (0);
				colonp = tp;
				continue;
			}
			if (tp + NS_INT16SZ > endp)
				return (0);
			*tp++ = (unsigned char)(val >> 8) & 0xff;
			*tp++ = (unsigned char)val & 0xff;
			saw_xdigit = 0;
			val = 0;
			continue;
		}
		if (ch == '.' && ((tp + NS_INADDRSZ) <= endp) &&
			inet_pton4(curtok, tp) > 0) {
			tp += NS_INADDRSZ;
			saw_xdigit = 0;
			break;	/* '\0' was seen by inet_pton4(). */
		}
		return (0);
	}
	if (saw_xdigit) {
		if (tp + NS_INT16SZ > endp)
			return (0);
		*tp++ = (unsigned char)(val >> 8) & 0xff;
		*tp++ = (unsigned char)val & 0xff;
	}
	if (colonp != NULL) {
		/*
		* Since some memmove()'s erroneously fail to handle
		* overlapping regions, we'll do the shift by hand.
		*/
		const int n = tp - colonp;
		int i;

		for (i = 1; i <= n; i++) {
			endp[-i] = colonp[n - i];
			colonp[n - i] = 0;
		}
		tp = endp;
	}
	if (tp != endp)
		return (0);
	memcpy(dst, tmp, NS_IN6ADDRSZ);
	return (1);
}
#endif /* INET_IPV6 */


const char *win_inet_ntop(int af, const void *src, char *dst,socklen_t size)
{
	switch (af) {
	case AF_INET:
		return inet_ntop4((const u_char*)src, dst, size);
#ifdef INET_IPV6
	case AF_INET6:
		return inet_ntop6(src, dst, size);
#endif
	default:
		/*__set_errno(EAFNOSUPPORT);*/
		return NULL;
	}
	/* NOTREACHED */
}

int win_inet_pton(int af, const char *src, void *dst)
{
	switch (af) {
	case AF_INET:
		return inet_pton4(src, (u_char*)dst);
#ifdef INET_IPV6
	case AF_INET6:
		return inet_pton6(src, dst);
#endif
	default:
		/*__set_errno(EAFNOSUPPORT);*/
		return -1;
	}
	/* NOTREACHED */
}


#ifdef __cplusplus
}
#endif

#endif /* WIN32 */
