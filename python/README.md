Python API
==========

This directory contains the Python 3.x API for querying ntopng using the Python language.

This API is based on ntopng's [REST API](https://www.ntop.org/guides/ntopng/api/rest/api_v2.html) and it allows users to perform operations such as:

- Read host statistics
- Get the active flows list
- Query network interface stats and time series
- Search historical data including alerts and flows

Prerequisites
-------------

The API is using Pandas for working with time series data.

- pandas

Examples are using additional libraries including NumPy for playing with time series data.

- numpy

API Information
---------------

For each ntopng REST API call there is a corresponding Python method for the defined Python classes:
- [host](ntopng/host.py)
- [interface](ntopng/interface.py)
- [historical](ntopng/historical.py)

The [ntopng](ntopng/ntopng.py) class is used to store information such as ntopng IP address and credentials used to connect it.

The [test](test.py) application can be used as example of the Python API

Installation
------------

For you convenience, ntop periodically builds pip packages. You can install the latest available package as:

`pip3 install ntopng`

Developing the Python API
-------------------------

We encourage our users to extend this API. For your convenience we are sharing a [Makefile](Makefile) that you can use as skeleton for installing the package locally or creating test packages.

Documentation
-------------

For further information please visit the API documentation available at:

[ntopng Python API](https://www.ntop.org/guides/ntopng/api/python/index.html)
[ntopng REST API v2](https://www.ntop.org/guides/ntopng/api/rest/api_v2.html)
