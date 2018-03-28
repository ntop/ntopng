What is ntopng
##############

Ntopng is a passive network monitoring tool focused on flows and statistics that can be obtained from the traffic captured by the server.

Licensing
---------
Binary ntopng instances require a per-server license that is released according to the EULA (End User License Agreement). Each license is perpetual (i.e. it does not expire) and it allows to install updates for one year since purchase/license issue. This means that a license generated on 1/1/2018 will be able to activate new versions of the software until 1/1/2019. If you want to install new versions of the software release after that date, you need to renew the maintenance or avoid further updating the software. For source-based ntopng you can refer to the GPL-v3 License.

ntopng licenses are generated using the orderId and email you provided when the license has been purchased on https://shop.ntop.org/. The licenses are generated at https://shop.ntop.org/mkntopng.

.. note::

   if you are using a VM or you plan to move licenses often, and you have installed the software on a server with Internet access, you can add :code:`--online-license-check` to the application command line (example: :code:`ntopng -i eth0 --online-license-check`) so that at startup the license is validated against the license database. The :code:`--online-license-check` option also supports http proxy setting the :code:`http_proxy` environment variable (example: :code:`export http_proxy=http://<ip>:<port>`).
