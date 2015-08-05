#ifndef __DETECTXSSLIB_H
#define	__DETECTXSSLIB_H

#include <memory.h>

#define	MAX_URL_LENGTH	(4192)
#define	MAX_TOKENS		(5120)

// possible outcomes of XSS scanning
//
typedef enum { XssUnknown, XssClean, XssSuspected, XssFound } XSSRESULT;

typedef struct _xsslibUrl
{
  char		Url[MAX_URL_LENGTH + 64];		// 64 for skipping length checks in regexes
  char		Tokens[MAX_TOKENS];
  XSSRESULT	Result;
  int			TokenCnt;
  int			MatchedRule;
} xsslibUrl;


#ifdef	__cplusplus
extern "C"
{
#endif
void xsslibUrlInit(xsslibUrl *url);
void xsslibUrlSetUrl(xsslibUrl *url, char *x);
void xsslibUrlSetUrl2(xsslibUrl *url, char *x, unsigned int len);
XSSRESULT xsslibUrlScan(xsslibUrl *url);
#ifdef	__cplusplus
}
#endif
#endif // !__DETECTXSSLIB_H
