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

int pthread_mutex_init(pthread_mutex_t *mutex, void* notused) {
  (*mutex) = CreateMutex(NULL, FALSE, NULL);
  (void) notused;	
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

#if 0
/* static */int pthread_cond_init(pthread_cond_t *cv, const void *unused) {
	unused = NULL;
	cv->signal = CreateEvent(NULL, FALSE, FALSE, NULL);
	cv->broadcast = CreateEvent(NULL, TRUE, FALSE, NULL);
	return cv->signal != NULL && cv->broadcast != NULL ? 0 : -1;
}

/* static */int pthread_cond_wait(pthread_cond_t *cv, pthread_mutex_t *mutex) {
	HANDLE handles[] = { cv->signal, cv->broadcast };
	ReleaseMutex(*mutex);
	WaitForMultipleObjects(2, handles, FALSE, INFINITE);
	return WaitForSingleObject(*mutex, INFINITE) == WAIT_OBJECT_0 ? 0 : -1;
}

/* static */int pthread_cond_signal(pthread_cond_t *cv) {
	return SetEvent(cv->signal) == 0 ? -1 : 0;
}

/* static */int pthread_cond_broadcast(pthread_cond_t *cv) {
	// Implementation with PulseEvent() has race condition, see                                                                                                                           
	// http://www.cs.wustl.edu/~schmidt/win32-cv-1.html                                                                                                                                   
	return PulseEvent(cv->broadcast) == 0 ? -1 : 0;
}

/* static */int pthread_cond_destroy(pthread_cond_t *cv) {
	return CloseHandle(cv->signal) && CloseHandle(cv->broadcast) ? 0 : -1;
}
#endif

#if 0
/* static */int pthread_cond_timedwait(pthread_cond_t* cv, pthread_mutex_t* mutex, const struct timespec* abstime) {
	HANDLE handles[] = { cv->signal, cv->broadcast };
	DWORD msec = abstime->tv_sec * 1000 + abstime->tv_sec / 1000;

	ReleaseMutex(*mutex);
	WaitForMultipleObjects(2, handles, FALSE, msec);
	return WaitForSingleObject(*mutex, msec) == WAIT_OBJECT_0 ? 0 : -1;
}
#endif
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


void __cdecl win_usleep(__int64 usec)
{
	HANDLE timer;
	LARGE_INTEGER ft;

	ft.QuadPart = -(10 * usec); // Convert to 100 nanosecond interval, negative value indicates relative time

	timer = CreateWaitableTimer(NULL, TRUE, NULL);
	SetWaitableTimer(timer, &ft, 0, NULL, NULL, 0);
	WaitForSingleObject(timer, INFINITE);
	CloseHandle(timer);
}

#if 0
/*
The strndup function copies not more than n characters (characters that
follow a null character are not copied) from string to a dynamically
allocated buffer. The copied string shall always be null terminated.
*/
char *strndup(const char *string, size_t s)
{
	char *p, *r;
	if (string == NULL)
		return NULL;
	p = (char*)string;
	while (s > 0) {
		if (*p == 0)
			break;
		p++;
		s--;
	}
	s = (p - string);
	r = (char*)malloc(1 + s);
	if (r) {
		strncpy(r, string, s);
		r[s] = 0;
	}
	return r;
}
#endif

#endif /* WIN32 */



/* ************************************************************************************ */

/* Convert a string representation of time to a time value.
   Copyright (C) 1996, 1997, 1998, 1999, 2000 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@cygnus.com>, 1996.

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

void get_locale_strings(void);

/* XXX This version of the implementation is not really complete.
   Some of the fields cannot add information alone.  But if seeing
   some of them in the same format (such as year, week and weekday)
   this is enough information for determining the date.  */

#include <ctype.h>
#include <limits.h>
#include <string.h>
#include <time.h>

#define match_char(ch1, ch2) if (ch1 != ch2) return NULL

#ifndef Macintosh
#if defined __GNUC__ && __GNUC__ >= 2
# define match_string(cs1, s2) \
  ({ size_t len = strlen (cs1);                                               \
     int result = strncasecmp ((cs1), (s2), len) == 0;                        \
     if (result) (s2) += len;                                                 \
     result; })
#else
   /* Oh come on.  Get a reasonable compiler.  */
# define match_string(cs1, s2) \
  (strncasecmp ((cs1), (s2), strlen (cs1)) ? 0 : ((s2) += strlen (cs1), 1))
#endif
#else
# define match_string(cs1, s2) \
  (strncmp ((cs1), (s2), strlen (cs1)) ? 0 : ((s2) += strlen (cs1), 1))
#endif /* mac */

   /* We intentionally do not use isdigit() for testing because this will
	  lead to problems with the wide character version.  */
#define get_number(from, to, n) \
  do {                                                                        \
    int __n = n;                                                              \
    val = 0;                                                                  \
    while (*rp == ' ')                                                        \
      ++rp;                                                                   \
    if (*rp < '0' || *rp > '9')                                               \
      return NULL;                                                            \
    do {                                                                      \
      val *= 10;                                                              \
      val += *rp++ - '0';                                                     \
    } while (--__n > 0 && val * 10 <= to && *rp >= '0' && *rp <= '9');        \
    if (val < from || val > to)                                               \
      return NULL;                                                            \
  } while (0)
# define get_alt_number(from, to, n) \
  /* We don't have the alternate representation.  */                          \
  get_number(from, to, n)
#define recursive(new_fmt) \
  (*(new_fmt) != '\0'                                                         \
   && (rp = strptime_internal (rp, (new_fmt), tm, decided)) != NULL)

	  /* This version: may overwrite these with versions for the locale */
static char weekday_name[][20] =
{
	"Sunday", "Monday", "Tuesday", "Wednesday",
	"Thursday", "Friday", "Saturday"
};
static char ab_weekday_name[][10] =
{
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
};
static char month_name[][20] =
{
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
};
static char ab_month_name[][10] =
{
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};

static char am_pm[][4] = { "AM", "PM" };


# define HERE_D_T_FMT "%a %b %e %H:%M:%S %Y"
# define HERE_D_FMT "%y/%m/%d"
# define HERE_T_FMT_AMPM "%I:%M:%S %p"
# define HERE_T_FMT "%H:%M:%S"

static const unsigned short int __mon_yday[2][13] =
{
	/* Normal years.  */
	{ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365 },
	/* Leap years.  */
	{ 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366 }
};


/* Status of lookup: do we use the locale data or the raw data?  */
enum locale_status { not, loc, raw };

# define __isleap(year) \
  ((year) % 4 == 0 && ((year) % 100 != 0 || (year) % 400 == 0))

/* Compute the day of the week.  */
void
day_of_the_week(struct tm *tm)
{
	/* We know that January 1st 1970 was a Thursday (= 4).  Compute the
	   the difference between this data in the one on TM and so determine
	   the weekday.  */
	int corr_year = 1900 + tm->tm_year - (tm->tm_mon < 2);
	int wday = (-473
		+ (365 * (tm->tm_year - 70))
		+ (corr_year / 4)
		- ((corr_year / 4) / 25) + ((corr_year / 4) % 25 < 0)
		+ (((corr_year / 4) / 25) / 4)
		+ __mon_yday[0][tm->tm_mon]
		+ tm->tm_mday - 1);
	tm->tm_wday = ((wday % 7) + 7) % 7;
}

/* Compute the day of the year.  */
void
day_of_the_year(struct tm *tm)
{
	tm->tm_yday = (__mon_yday[__isleap(1900 + tm->tm_year)][tm->tm_mon]
		+ (tm->tm_mday - 1));
}

char *
strptime_internal(const char *rp, const char *fmt, struct tm *tm,
	enum locale_status *decided)
{
	const char *rp_backup;
	int cnt;
	size_t val;
	int have_I, is_pm;
	int century, want_century;
	int have_wday, want_xday;
	int have_yday;
	int have_mon, have_mday;

	have_I = is_pm = 0;
	century = -1;
	want_century = 0;
	have_wday = want_xday = have_yday = have_mon = have_mday = 0;

	while (*fmt != '\0')
	{
		/* A white space in the format string matches 0 more or white
		   space in the input string.  */
		if (isspace(*fmt))
		{
			while (isspace(*rp))
				++rp;
			++fmt;
			continue;
		}

		/* Any character but `%' must be matched by the same character
		   in the iput string.  */
		if (*fmt != '%')
		{
			match_char(*fmt++, *rp++);
			continue;
		}

		++fmt;

		/* We need this for handling the `E' modifier.  */
	start_over:

		/* Make back up of current processing pointer.  */
		rp_backup = rp;

		switch (*fmt++)
		{
		case '%':
			/* Match the `%' character itself.  */
			match_char('%', *rp++);
			break;
		case 'a':
		case 'A':
			/* Match day of week.  */
			for (cnt = 0; cnt < 7; ++cnt)
			{
				if (*decided != loc
					&& (match_string(weekday_name[cnt], rp)
						|| match_string(ab_weekday_name[cnt], rp)))
				{
					*decided = raw;
					break;
				}
			}
			if (cnt == 7)
				/* Does not match a weekday name.  */
				return NULL;
			tm->tm_wday = cnt;
			have_wday = 1;
			break;
		case 'b':
		case 'B':
		case 'h':
			/* Match month name.  */
			for (cnt = 0; cnt < 12; ++cnt)
			{
				if (match_string(month_name[cnt], rp)
					|| match_string(ab_month_name[cnt], rp))
				{
					*decided = raw;
					break;
				}
			}
			if (cnt == 12)
				/* Does not match a month name.  */
				return NULL;
			tm->tm_mon = cnt;
			want_xday = 1;
			break;
		case 'c':
			/* Match locale's date and time format.  */
			if (!recursive(HERE_T_FMT_AMPM))
				return NULL;
			break;
		case 'C':
			/* Match century number.  */
			get_number(0, 99, 2);
			century = val;
			want_xday = 1;
			break;
		case 'd':
		case 'e':
			/* Match day of month.  */
			get_number(1, 31, 2);
			tm->tm_mday = val;
			have_mday = 1;
			want_xday = 1;
			break;
		case 'F':
			if (!recursive("%Y-%m-%d"))
				return NULL;
			want_xday = 1;
			break;
		case 'x':
			/* Fall through.  */
		case 'D':
			/* Match standard day format.  */
			if (!recursive(HERE_D_FMT))
				return NULL;
			want_xday = 1;
			break;
		case 'k':
		case 'H':
			/* Match hour in 24-hour clock.  */
			get_number(0, 23, 2);
			tm->tm_hour = val;
			have_I = 0;
			break;
		case 'I':
			/* Match hour in 12-hour clock.  */
			get_number(1, 12, 2);
			tm->tm_hour = val % 12;
			have_I = 1;
			break;
		case 'j':
			/* Match day number of year.  */
			get_number(1, 366, 3);
			tm->tm_yday = val - 1;
			have_yday = 1;
			break;
		case 'm':
			/* Match number of month.  */
			get_number(1, 12, 2);
			tm->tm_mon = val - 1;
			have_mon = 1;
			want_xday = 1;
			break;
		case 'M':
			/* Match minute.  */
			get_number(0, 59, 2);
			tm->tm_min = val;
			break;
		case 'n':
		case 't':
			/* Match any white space.  */
			while (isspace(*rp))
				++rp;
			break;
		case 'p':
			/* Match locale's equivalent of AM/PM.  */
			if (!match_string(am_pm[0], rp))
				if (match_string(am_pm[1], rp))
					is_pm = 1;
				else
					return NULL;
			break;
		case 'r':
			if (!recursive(HERE_T_FMT_AMPM))
				return NULL;
			break;
		case 'R':
			if (!recursive("%H:%M"))
				return NULL;
			break;
		case 's':
		{
			/* The number of seconds may be very high so we cannot use
			   the `get_number' macro.  Instead read the number
			   character for character and construct the result while
			   doing this.  */
			time_t secs = 0;
			if (*rp < '0' || *rp > '9')
				/* We need at least one digit.  */
				return NULL;

			do
			{
				secs *= 10;
				secs += *rp++ - '0';
			} while (*rp >= '0' && *rp <= '9');

			if ((tm = localtime(&secs)) == NULL)
				/* Error in function.  */
				return NULL;
		}
		break;
		case 'S':
			get_number(0, 61, 2);
			tm->tm_sec = val;
			break;
		case 'X':
			/* Fall through.  */
		case 'T':
			if (!recursive(HERE_T_FMT))
				return NULL;
			break;
		case 'u':
			get_number(1, 7, 1);
			tm->tm_wday = val % 7;
			have_wday = 1;
			break;
		case 'g':
			get_number(0, 99, 2);
			/* XXX This cannot determine any field in TM.  */
			break;
		case 'G':
			if (*rp < '0' || *rp > '9')
				return NULL;
			/* XXX Ignore the number since we would need some more
			   information to compute a real date.  */
			do
				++rp;
			while (*rp >= '0' && *rp <= '9');
			break;
		case 'U':
		case 'V':
		case 'W':
			get_number(0, 53, 2);
			/* XXX This cannot determine any field in TM without some
			   information.  */
			break;
		case 'w':
			/* Match number of weekday.  */
			get_number(0, 6, 1);
			tm->tm_wday = val;
			have_wday = 1;
			break;
		case 'y':
			/* Match year within century.  */
			get_number(0, 99, 2);
			/* The "Year 2000: The Millennium Rollover" paper suggests that
			   values in the range 69-99 refer to the twentieth century.  */
			tm->tm_year = val >= 69 ? val : val + 100;
			/* Indicate that we want to use the century, if specified.  */
			want_century = 1;
			want_xday = 1;
			break;
		case 'Y':
			/* Match year including century number.  */
			get_number(0, 9999, 4);
			tm->tm_year = val - 1900;
			want_century = 0;
			want_xday = 1;
			break;
		case 'Z':
			/* XXX How to handle this?  */
			break;
		case 'E':
			/* We have no information about the era format.  Just use
			   the normal format.  */
			if (*fmt != 'c' && *fmt != 'C' && *fmt != 'y' && *fmt != 'Y'
				&& *fmt != 'x' && *fmt != 'X')
				/* This is an invalid format.  */
				return NULL;

			goto start_over;
		case 'O':
			switch (*fmt++)
			{
			case 'd':
			case 'e':
				/* Match day of month using alternate numeric symbols.  */
				get_alt_number(1, 31, 2);
				tm->tm_mday = val;
				have_mday = 1;
				want_xday = 1;
				break;
			case 'H':
				/* Match hour in 24-hour clock using alternate numeric
				   symbols.  */
				get_alt_number(0, 23, 2);
				tm->tm_hour = val;
				have_I = 0;
				break;
			case 'I':
				/* Match hour in 12-hour clock using alternate numeric
				   symbols.  */
				get_alt_number(1, 12, 2);
				tm->tm_hour = val - 1;
				have_I = 1;
				break;
			case 'm':
				/* Match month using alternate numeric symbols.  */
				get_alt_number(1, 12, 2);
				tm->tm_mon = val - 1;
				have_mon = 1;
				want_xday = 1;
				break;
			case 'M':
				/* Match minutes using alternate numeric symbols.  */
				get_alt_number(0, 59, 2);
				tm->tm_min = val;
				break;
			case 'S':
				/* Match seconds using alternate numeric symbols.  */
				get_alt_number(0, 61, 2);
				tm->tm_sec = val;
				break;
			case 'U':
			case 'V':
			case 'W':
				get_alt_number(0, 53, 2);
				/* XXX This cannot determine any field in TM without
				   further information.  */
				break;
			case 'w':
				/* Match number of weekday using alternate numeric symbols.  */
				get_alt_number(0, 6, 1);
				tm->tm_wday = val;
				have_wday = 1;
				break;
			case 'y':
				/* Match year within century using alternate numeric symbols.  */
				get_alt_number(0, 99, 2);
				tm->tm_year = val >= 69 ? val : val + 100;
				want_xday = 1;
				break;
			default:
				return NULL;
			}
			break;
		default:
			return NULL;
		}
	}

	if (have_I && is_pm)
		tm->tm_hour += 12;

	if (century != -1)
	{
		if (want_century)
			tm->tm_year = tm->tm_year % 100 + (century - 19) * 100;
		else
			/* Only the century, but not the year.  Strange, but so be it.  */
			tm->tm_year = (century - 19) * 100;
	}

	if (want_xday && !have_wday) {
		if (!(have_mon && have_mday) && have_yday) {
			/* we don't have tm_mon and/or tm_mday, compute them */
			int t_mon = 0;
			while (__mon_yday[__isleap(1900 + tm->tm_year)][t_mon] <= tm->tm_yday)
				t_mon++;
			if (!have_mon)
				tm->tm_mon = t_mon - 1;
			if (!have_mday)
				tm->tm_mday = tm->tm_yday - __mon_yday[__isleap(1900 + tm->tm_year)][t_mon - 1] + 1;
		}
		day_of_the_week(tm);
	}
	if (want_xday && !have_yday)
		day_of_the_year(tm);

	return (char *)rp;
}

char *
strptime(const char *buf, const char *format, struct tm *tm)
{
	enum locale_status decided;
#ifdef HAVE_LOCALE_H
	// if (!have_used_strptime) {
		get_locale_strings();
		/* have_used_strptime = 1; might change locale during session */
	//}
#endif
	decided = raw;
	return strptime_internal(buf, format, tm, &decided);
}

#ifdef HAVE_LOCALE_H
void get_locale_strings(void)
{
	int i;
	struct tm tm;
	char buff[4];

	tm.tm_sec = tm.tm_min = tm.tm_hour = tm.tm_mday = tm.tm_mon
		= tm.tm_isdst = 0;
	tm.tm_year = 30;
	for (i = 0; i < 12; i++) {
		tm.tm_mon = i;
		strftime(ab_month_name[i], 10, "%b", &tm);
		strftime(month_name[i], 20, "%B", &tm);
	}
	tm.tm_mon = 0;
	for (i = 0; i < 7; i++) {
		tm.tm_mday = tm.tm_yday = i + 1; /* 2000-1-2 was a Sunday */
		tm.tm_wday = i;
		strftime(ab_weekday_name[i], 10, "%a", &tm);
		strftime(weekday_name[i], 20, "%A", &tm);
	}
	tm.tm_hour = 1;
	/* in locales where these are unused, they may be empty: better
	   not to reset them then */
	strftime(buff, 4, "%p", &tm);
	if (strlen(buff)) strcpy(am_pm[0], buff);
	tm.tm_hour = 13;
	strftime(buff, 4, "%p", &tm);
	if (strlen(buff)) strcpy(am_pm[1], buff);
}
#endif

// strndup() is not available on Windows
char* strndup(const char* s1, size_t n)
{
	char* copy = (char*)malloc(n + 1);
	memcpy(copy, s1, n);
	copy[n] = 0;
	return copy;
};
