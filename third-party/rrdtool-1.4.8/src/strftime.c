/**
 *
 * strftime.c
 *
 * implements the ansi c function strftime()
 *
 * written 6 september 1989 by jim nutt
 * released into the public domain by jim nutt
 *
 * modified 21-Oct-89 by Rob Duff
 *
 * modified 08-Dec-04 by Tobi Oetiker (added %V)
**/

#include <stddef.h>     /* for size_t */
#include <stdarg.h>     /* for va_arg */
#include <time.h>       /* for struct tm */
#include "strftime.h"

/* Define your own defaults in config.h if necessary */
#if defined(TZNAME_STD) && defined(TZNAME_DST)
char     *tzname_[2] = { TZNAME_STD, TZNAME_DST };
#else
#define tzname_ tzname
#endif

static char *aday[] = {
    "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
};

static char *day[] = {
    "Sunday", "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
};

static char *amonth[] = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};

static char *month[] = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
};

static char buf[26];

static void strfmt(
    char *str,
    const char *fmt,
    ...);

/**
 *
 * size_t strftime_(char *str,
 *                  size_t maxs,
 *                  const char *fmt,
 *                  const struct tm *t)
 *
 *      this functions acts much like a sprintf for time/date output.
 *      given a pointer to an output buffer, a format string and a
 *      time, it copies the time to the output buffer formatted in
 *      accordance with the format string.  the parameters are used
 *      as follows:
 *
 *          str is a pointer to the output buffer, there should
 *          be at least maxs characters available at the address
 *          pointed to by str.
 *
 *          maxs is the maximum number of characters to be copied
 *          into the output buffer, included the '\0' terminator
 *
 *          fmt is the format string.  a percent sign (%) is used
 *          to indicate that the following character is a special
 *          format character.  the following are valid format
 *          characters:
 *
 *              %A      full weekday name (Monday)
 *              %a      abbreviated weekday name (Mon)
 *              %B      full month name (January)
 *              %b      abbreviated month name (Jan)
 *              %c      standard date and time representation
 *              %d      day-of-month (01-31)
 *              %H      hour (24 hour clock) (00-23)
 *              %I      hour (12 hour clock) (01-12)
 *              %j      day-of-year (001-366)
 *              %M      minute (00-59)
 *              %m      month (01-12)
 *              %p      local equivalent of AM or PM
 *              %S      second (00-59)
 *              %U      week-of-year, first day sunday (00-53)
 *              %W      week-of-year, first day monday (00-53)
 *              %V      ISO 8601 Week number 
 *              %w      weekday (0-6, sunday is 0)
 *              %X      standard time representation
 *              %x      standard date representation
 *              %Y      year with century
 *              %y      year without century (00-99)
 *              %Z      timezone name
 *              %%      percent sign
 *
 *      the standard date string is equivalent to:
 *
 *          %a %b %d %Y
 *
 *      the standard time string is equivalent to:
 *
 *          %H:%M:%S
 *
 *      the standard date and time string is equivalent to:
 *
 *          %a %b %d %H:%M:%S %Y
 *
 *      strftime_() returns the number of characters placed in the
 *      buffer, not including the terminating \0, or zero if more
 *      than maxs characters were produced.
 *
**/

size_t strftime_(
    char *s,
    size_t maxs,
    const char *f,
    const struct tm *t)
{
    int       w, d;
    char     *p, *q, *r;

    p = s;
    q = s + maxs - 1;
    while ((*f != '\0')) {
        if (*f++ == '%') {
            r = buf;
            switch (*f++) {
            case '%':
                r = "%";
                break;

            case 'a':
                r = aday[t->tm_wday];
                break;

            case 'A':
                r = day[t->tm_wday];
                break;

            case 'b':
                r = amonth[t->tm_mon];
                break;

            case 'B':
                r = month[t->tm_mon];
                break;

            case 'c':
                strfmt(r, "%0 %0 %2 %2:%2:%2 %4",
                       aday[t->tm_wday], amonth[t->tm_mon],
                       t->tm_mday, t->tm_hour, t->tm_min,
                       t->tm_sec, t->tm_year + 1900);
                break;

            case 'd':
                strfmt(r, "%2", t->tm_mday);
                break;

            case 'H':
                strfmt(r, "%2", t->tm_hour);
                break;

            case 'I':
                strfmt(r, "%2", (t->tm_hour % 12) ? t->tm_hour % 12 : 12);
                break;

            case 'j':
                strfmt(r, "%3", t->tm_yday + 1);
                break;

            case 'm':
                strfmt(r, "%2", t->tm_mon + 1);
                break;

            case 'M':
                strfmt(r, "%2", t->tm_min);
                break;

            case 'p':
                r = (t->tm_hour > 11) ? "PM" : "AM";
                break;

            case 'S':
                strfmt(r, "%2", t->tm_sec);
                break;

            case 'U':
                w = t->tm_yday / 7;
                if (t->tm_yday % 7 > t->tm_wday)
                    w++;
                strfmt(r, "%2", w);
                break;

            case 'W':
                w = t->tm_yday / 7;
                if (t->tm_yday % 7 > (t->tm_wday + 6) % 7)
                    w++;
                strfmt(r, "%2", w);
                break;

            case 'V':

                /* ISO 8601 Week Of Year:
                   If the week (Monday - Sunday) containing January 1 has four or more
                   days in the new year, then it is week 1; otherwise it is week 53 of
                   the previous year and the next week is week one. */

                w = (t->tm_yday + 7 - (t->tm_wday ? t->tm_wday - 1 : 6)) / 7;
                d = (t->tm_yday + 7 - (t->tm_wday ? t->tm_wday - 1 : 6)) % 7;

                if (d >= 4) {
                    w++;
                } else if (w == 0) {
                    w = 53;
                }
                strfmt(r, "%2", w);
                break;

            case 'w':
                strfmt(r, "%1", t->tm_wday);
                break;

            case 'x':
                strfmt(r, "%3s %3s %2 %4", aday[t->tm_wday],
                       amonth[t->tm_mon], t->tm_mday, t->tm_year + 1900);
                break;

            case 'X':
                strfmt(r, "%2:%2:%2", t->tm_hour, t->tm_min, t->tm_sec);
                break;

            case 'y':
                strfmt(r, "%2", t->tm_year % 100);
                break;

            case 'Y':
                strfmt(r, "%4", t->tm_year + 1900);
                break;

            case 'Z':
                r = (t->tm_isdst && tzname_[1][0]) ? tzname_[1] : tzname_[0];
                break;

            default:
                buf[0] = '%';   /* reconstruct the format */
                buf[1] = f[-1];
                buf[2] = '\0';
                if (buf[1] == 0)
                    f--;    /* back up if at end of string */
            }
            while (*r) {
                if (p == q) {
                    *q = '\0';
                    return 0;
                }
                *p++ = *r++;
            }
        } else {
            if (p == q) {
                *q = '\0';
                return 0;
            }
            *p++ = f[-1];
        }
    }
    *p = '\0';
    return p - s;
}

/*
 *  stdarg.h
 *
typedef void *va_list;
#define va_start(vp,v) (vp=((char*)&v)+sizeof(v))
#define va_arg(vp,t) (*((t*)(vp))++)
#define va_end(vp)
 *
 */

static int powers[5] = { 1, 10, 100, 1000, 10000 };

/**
 * static void strfmt(char *str, char *fmt);
 *
 * simple sprintf for strftime
 *
 * each format descriptor is of the form %n
 * where n goes from zero to four
 *
 * 0    -- string %s
 * 1..4 -- int %?.?d
 *
**/

static void strfmt(
    char *str,
    const char *fmt,
    ...)
{
    int       ival, ilen;
    char     *sval;
    va_list   vp;

    va_start(vp, fmt);
    while (*fmt) {
        if (*fmt++ == '%') {
            ilen = *fmt++ - '0';
            if (ilen == 0) {    /* zero means string arg */
                sval = va_arg(vp, char *);

                while (*sval)
                    *str++ = *sval++;
            } else {    /* always leading zeros */

                ival = va_arg(vp, int);

                while (ilen) {
                    ival %= powers[ilen--];
                    *str++ = (char) ('0' + ival / powers[ilen]);
                }
            }
        } else
            *str++ = fmt[-1];
    }
    *str = '\0';
    va_end(vp);
}

#ifdef TEST

#include <stdio.h>      /* for printf */
#include <time.h>       /* for strftime */

char      test[80];

int main(
    int argc,
    char *argv[])
{
    int       len;
    char     *fmt;
    time_t    now;

    time(&now);

    fmt = (argc == 1) ? "%I:%M %p\n%c\n" : argv[1];
    len = strftime_(test, sizeof test, fmt, localtime(&now));
    printf("%d: %s\n", len, test);
    return !len;
}

#endif                          /* TEST */
