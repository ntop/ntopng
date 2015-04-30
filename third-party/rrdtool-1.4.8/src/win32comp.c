/* compatibility routines, non reentrant .... */

#include <string.h>
#include <time.h>

struct tm *localtime_r(
    const time_t *t,
    struct tm *r)
{
    struct tm *temp;

    temp = localtime(t);
    memcpy(r, temp, sizeof(struct tm));
    return (r);
}

struct tm *gmtime_r(
    const time_t *t,
    struct tm *r)
{
    struct tm *temp;

    temp = gmtime(t);
    memcpy(r, temp, sizeof(struct tm));
    return r;
}

char     *ctime_r(
    const time_t *t,
    char *buf)
{
    char     *temp;

    temp = asctime(localtime(t));
    strcpy(buf, temp);
    return (buf);
}

/*
	s  
	Points to the string from which to extract tokens. 

	delim  
	Points to a null-terminated set of delimiter characters. 

	save_ptr
	Is a value-return parameter used by strtok_r() to record its progress through s1. 
*/


char     *strtok_r(
    char *s,
    const char *delim,
    char **save_ptr)
{
    char     *token;

    if (s == NULL)
        s = *save_ptr;

    /* Scan leading delimiters.  */
    s += strspn(s, delim);
    if (*s == '\0') {
        *save_ptr = s;
        return NULL;
    }

    /* Find the end of the token.  */
    token = s;
    s = strpbrk(token, delim);
    if (s == NULL) {
        /* This token finishes the string.  */
        *save_ptr = token;
        while (**save_ptr != '\0')
            (*save_ptr)++;
    } else {
        /* Terminate the token and make *SAVE_PTR point past it.  */
        *s = '\0';
        *save_ptr = s + 1;
    }
    return token;
}
