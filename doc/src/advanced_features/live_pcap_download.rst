Live Pcap Download
##################

A pcap file containing packets matching a certain src/dst host can be generated on-the-fly by ntopng and streamed via web. The pcap can be generated either by clicking on hyperlink `pcap` on every host page or by directly requesting endpoint `live_traffic.lua`.

The pcap file can be downloaded directly within a browser or using a command line tool such as `wget` or `curl`.

Command line tools are useful for example to download the pcap and pipe it to an analysis tool such as wireshark. For example, to download a pcap for host `192.168.2.178` one can use `wget` to request page `live_traffic.lua` with the given ip address in the host parameter:

.. code:: bash
	  
	  wget -qO-  "http://192.168.2.149:3000/lua/live_traffic.lua?ifid=0&host=192.168.2.178"  | wireshark -k -i -

