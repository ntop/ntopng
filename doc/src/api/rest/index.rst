RESTful API
===========

ntopng provides a RESTful API for exporting data through HTTP including 
Interfaces/Hosts/Flows information and raw PCAP data.

Please note that cookies should be used for authentication, for example 
with `curl` it is possible to specify username and password with 
:code:`--cookie "user=<user>; password=<password>"`

For example, to download data for a host you can use the below `curl` 
command line:

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/host_get_json.lua?ifid=1&host=192.168.1.2"


.. swaggerv2doc:: rest-api.json
