Security
========

nEdge actively inspects all the network traffic and make sure no one can reach - or be reached by - an insecure host. Its technology leverages IP and domains lists produced and constantly updated by Industry's leading cyber-security companies to assure not even a single byte is exchanged with potentially harmful hosts. Currently supported lists are those provided by `Malware Domain List`_ and `Emerging Threats`_ and are refreshed every day.

Whenever an insecure host is detected as a source or destination of network traffic, the corresponding traffic is dropped and an alert is generated. This behavior can be disabled from the preferences.

DNS-based unsafe sites blocking
-------------------------------
ntopng Edge can also seamlessly and transparently enforce the use of safe DNS servers. Every DNS request seen is forcefully routed to make sure it is handled by a trusted, safe DNS to protect you against the most common cyber threats. Several DNS servers provided by cyber-security companies are ready to be chosen and can be used free of charge within ntopng Edge. And if you are concerned about someone who could try to manually force an arbitrary DNS, don't worry! ntopng Edge sees and routes every DNS request to the safe DNS. Additional protection is also offered for kids with special Child-Safe DNS, to protect them against violent or explicit material.

See dns_ for a detailed description of how the DNS-based unsafe site blocking works.

.. _`Malware Domain List`: https://www.malwaredomainlist.com/
.. _`Emerging Threats`: https://rules.emergingthreats.net/
.. _dns: dns.html
