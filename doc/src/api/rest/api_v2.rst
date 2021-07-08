RESTful API v2 Specification
============================

Authentication
--------------

The HTTP/HTTPS authentication should be used, for example with `curl` 
it is possible to specify username and password with 
:code:`-u <user>:<password>`

Using HTTPS is recommended for security. See  `this post <https://www.ntop.org/ntopng/best-practices-to-secure-ntopng/>`_ to enable HTTPS.

Request Format
--------------

Parameters can be provided both using GET with a query string or
POST using JSON (in this case please make sure the correct 
Content Type is provided). For example, to download data for a host you can 
use the below `curl` command line using GET:

.. code:: bash
	  
   curl -s -u admin:admin "http://192.168.1.1:3000/lua/rest/v2/get/host/data.lua?ifid=1&host=192.168.1.2"

or the below `curl` command line using POST:

.. code:: bash
	  
   curl -s -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.2"}' "http://192.168.1.1:3000/lua/rest/v2/get/host/data.lua"

Please check the *Examples* section for more examples.

Response Format
---------------

An API response is usually represented by a JSON message matching a standard structure.
This JSON message consists of an envelope containing:

- a return code *rc*
- a human-readable string *rc_str* describing the return code
- the actual response in *rsp*

Example:

.. code:: text

   {
    "rc": 0
    "rc_str": "OK",
    "rsp": {
       ...
    }
   }

API
---

.. swaggerv2doc:: rest-api-v2.json
