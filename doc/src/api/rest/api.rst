RESTful API v0 Specification
============================

.. warning:: This API is deprecated and will be discountinued with ntopng 4.2, please move to the RESTful API v1

Authentication
--------------

Please note that cookies should be used for authentication, for example 
with `curl` it is possible to specify username and password with 
:code:`--cookie "user=<user>; password=<password>"`

For example, to download data for a host you can use the below `curl` 
command line:

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/rest/get/host/data.lua?ifid=1&host=192.168.1.2"

Please check the *Examples* section for more examples.

API
---

.. swaggerv2doc:: rest-api.json


