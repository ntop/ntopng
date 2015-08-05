detectXSSlib
=============

Author: Greg Wroblewski
Contact: gwroblew@hotmail.com

detectXSSlib is a general purpose library for detection of XSS attacks in URLs.
It is based on a subset of OWASP CRS ModSecurity rules and optimized for
performance. See sample tool xssscan and nginx module 
(in ngx_http_detectxsslib_handler) for API usage examples.

The library processes URLs in three stages. First stage removes URL encoding
and cleans URL from noisy characters. Stage two tokenizes URL matching
following substrings as token entities:

<?import
<applet
<base
<embed
<frame
<iframe
<implementation
<import
<link
<meta
<object
<script
<style
charset
classid
code
codetype
data
href
http-equiv
javascript:
src
type
vbscript:
vmlframe
xlink:href
=
[ /+\t]*
<
>
.*

The third stage implements regular expression matching in simplified way,
applying 15 different patterns to the array of tokens generated in the
second stage. The first matching pattern stops the third stage and
the detection process returns with successful findings of an XSS attack.

https://github.com/gwroblew/detectXSSlib
