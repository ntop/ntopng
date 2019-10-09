Custom Alert Endpoint
---------------------

Alert endpoints are lua script executed whenever an alert event occurs. An example
of alert endpoint is the email export endpoint, which sends email with alert information.

Users can define a custom alert endpoint to be called on alert events. The endpoint
could trigger, for example, an external bash script with custom logic.

The custom alert endpoint can be enabled as follows:

  1. Run `cp /usr/share/ntopng/scripts/lua/modules/alert_endpoints/{sample.lua,custom.lua}`
  2. Restart ntopng

The file `/usr/share/ntopng/scripts/lua/modules/alert_endpoints/custom.lua` can then be
modified with custom logic.

Custom Alert Generation
-----------------------

Check out the User Scripts documentation https://www.ntop.org/guides/ntopng/api/user_scripts/index.html .
