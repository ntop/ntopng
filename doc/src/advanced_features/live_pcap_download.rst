Live Pcap Download
##################

A pcap file containing packets matching a certain src/dst host can be generated on-the-fly by ntopng and streamed via web. 
The pcap can be generated either by clicking on hyperlink `pcap` on every host page or by directly requesting endpoint `live_traffic.lua`.

The pcap file can be downloaded directly within a browser or using a command line tool such as `wget` or `curl`.
The direct url for downloading the pcap is :code:`http://<ntopng IP>:3000/lua/live_traffic.lua?ifid=<interface index>&host=<host IP>`.

Please note that you should use cookies for authentication, as explained in the documentation. For example with `curl` you can specify
username and password with :code:`--cookie "user=<user>; password=<password>"`

Command line tools are useful for example to read a pcap stream and pipe it to an analysis tool such as `tcpdump` or `tshark`/`wireshark`. 
For example, to process the traffic matching host `192.168.2.1` with `wireshark`, it is possible to use `curl` as in the example below:

.. code:: bash
	  
   curl -s --cookie "user=admin; password=admin" "http://192.168.1.1:3000/lua/live_traffic.lua?ifid=12&host=192.168.2.1" | wireshark -k -i -

Note that the pcap file is automatically cut by default after 1 minute or 100k packets.
