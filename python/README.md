Python API
==========

This directory contains the Python 3.x API for querying ntopng using the Python language.

This API is based on ntopng's [REST API](https://www.ntop.org/guides/ntopng/api/rest/api_v2.html) and it allows users to perform operations such as:
- Read host statistics
- Get the active flows list
- Query network interface stats
- Search historical flows

API Information
----------------
For each ntopng REST API call there is a corresponding Python method for the defined Python classes:
- [host](host.py)
- [flow](flow.py)
- [interface](interface.py)

The [ntopng](ntopng.py) class is used to store information such as ntopng IP address and credentials used to connect it.

The [test](test.py) application can be used as example of the Python API

Documentation
-------------
[ntopng REST API v2](https://www.ntop.org/guides/ntopng/api/rest/api_v2.html)
