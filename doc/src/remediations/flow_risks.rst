Remediations for Flow Risks
###########################

.. _Risk 001:

Blacklisted Flow
================
#. Block at the Firewall: Configure your firewall to block incoming and outgoing traffic from the blacklisted IP address or domain. This can be done at the network level using a firewall or security appliance.
#. Block at the Mail Server: If the blacklist pertains to an email address, you can configure your mail server to reject emails from that address. You can also set up spam filters to quarantine or delete messages containing the blacklisted email address.
#. Use a Content Filtering Service: Consider using a content filtering service that can block access to websites with known malicious content. These services often maintain lists of blacklisted domains and can help prevent traffic from reaching your network.
#. Configure DNS Settings: You can configure your DNS settings to prevent resolving requests for the blacklisted domain. This can be done by adding the domain to your local DNS blacklist or using a DNS filtering service.
#. Regularly Update Blacklists: Make sure you regularly update your blacklist to ensure you are blocking the latest threats.

.. _Risk 002:

Blacklisted Country
================
#. Use a Firewall: Configure your firewall to block incoming and outgoing traffic from IP addresses in blacklisted countries. You can obtain lists of IP address ranges for each country from organizations such as MaxMind or GeoIP.
#. Implement Content Filtering: Use content filtering tools to block access to websites in blacklisted countries. These tools can help prevent users in your network from visiting malicious sites and downloading malware.
#. Use VPNs: Consider implementing Virtual Private Networks (VPNs) for remote workers or employees traveling abroad. VPNs can encrypt all traffic between the user's device and your network, preventing eavesdropping and unauthorized access to sensitive data.
#. Conduct Regular Security Audits: Regularly conduct security audits to identify vulnerabilities in your network and systems. This can help you address any weaknesses before they are exploited by attackers from blacklisted countries.
#. Implement SIEM Solutions: Use Security Information and Event Management (SIEM) solutions to monitor network traffic for suspicious activity from blacklisted countries. These solutions can help you detect and respond to threats before they cause damage to your network or data.

.. _Risk 004:

ICMP Data Exfiltration
======================
#. Implement Access Controls: Use access controls to limit who has access to sensitive data and what they can do with it. Implement strong password policies and use multi-factor authentication (MFA) to secure user accounts.
#. Encrypt Data: Encrypt sensitive data both at rest and in transit using strong encryption algorithms. This helps ensure that even if the data is intercepted, it cannot be read without the decryption key.
#. Use Data Loss Prevention (DLP) Tools: Implement DLP tools to monitor and control the flow of sensitive data both inside and outside your network. These tools can help you prevent data exfiltration by enforcing data usage policies and blocking unauthorized data transfers.
#. Implement User Behavior Analytics (UBA): Use UBA tools to analyze user behavior patterns and detect anomalous activity that could indicate data exfiltration attempts. These tools can help you identify insider threats or compromised user accounts before they cause significant damage.

.. _Risk 005:

Susp. Device Protocol
=====================
#. Implement Network Segmentation: Use network segmentation to separate devices and traffic based on trust levels. Restrict access between segments and implement strict access control policies.
#. Use Application Control: Use application control solutions to monitor and manage which applications are allowed to run on devices on your network. These solutions can help you block unknown or unusual application protocols.
#. Implement Intrusion Detection Systems (IDS): Use IDS solutions to monitor network traffic for known malicious activity, including unusual application protocols. IDS can alert you to potential threats and help you take action before damage is done.
#. Configure Firewalls: Configure firewalls to block or restrict access to ports associated with unusual application protocols. Use a whitelist approach, allowing only known and trusted protocols through the firewall.

.. _Risk 006:

DNS Data Exfiltration
=====================
#. Implement DNS Filtering: Use DNS filtering solutions to block access to known malicious or suspicious DNS domains and IP addresses. These solutions can help prevent DNS queries from resolving to malicious destinations and preventing data exfiltration.
#. Encrypt DNS Traffic: Use encryption for DNS traffic to prevent eavesdropping and unauthorized access to your DNS queries and responses. You can use tools like DNS over HTTPS (DoH) or DNS over TLS to encrypt DNS traffic.
#. Implement Source Port Randomization: Use source port randomization for DNS queries to prevent attackers from predicting which port will be used for a query, making it more difficult to intercept and filter the queries.

.. _Risk 007:

Invalid DNS query
=================
#. Implement DNS Filtering: Use DNS filtering solutions to block access to known malicious or suspicious DNS domains and IP addresses. These solutions can help prevent invalid queries from resolving to malicious destinations.
#. Configure DNS Server Security: Secure your internal DNS servers by configuring them with strong authentication, such as TSIG keys for dynamic updates, and implementing access controls. This can help prevent unauthorized queries and responses.
#. Implement Source Port Randomization: Use source port randomization for DNS queries to prevent attackers from predicting which port will be used for a query. This makes it more difficult for them to intercept and analyze the queries.

.. _Risk 008:

Elephant Flow
=============
#. Implement QoS policies: Configure QoS policies on switches, routers, and firewalls to prioritize critical traffic over non-critical traffic based on their importance, ensuring that the network bandwidth is optimally utilized.
#. Implement traffic shaping: Traffic shaping can help prevent elephant flows by limiting the amount of bandwidth consumed by any single application or user, ensuring that network resources are evenly distributed among all users and applications.
#. Implement link aggregation: Link aggregation, also known as bonding, can help increase network capacity by combining multiple physical links into a logical link, increasing overall bandwidth and reducing the risk of congestion caused by elephant flows on any single link.
#. Use WAN optimization: For organizations with remote or distributed offices, implementing WAN optimization technologies such as caching, compression, and traffic prioritization can help reduce the amount of data that needs to be transferred across the network, minimizing the risk of congestion caused by elephant flows.
#. Implement traffic filtering: Use firewalls, intrusion prevention systems (IPS), and other security solutions to filter out non-essential traffic and prevent large data transfers that can contribute to elephant flows.

.. _Risk 009:

Blacklisted Client contact
==========================
#. Firewall rules: Configure your firewall to block traffic from known malicious or blacklisted IP addresses or domains. You can use various sources for IP addresses and domains, such as public blacklists like SpamHaus, SORBS, and others. Ensure that your firewall is updated with the latest list of blacklisted IPs to effectively block unwanted traffic.
#. DNS filtering: Use DNS filtering to block access to known malicious websites or IP addresses by modifying the DNS response. DNS filtering can help prevent connections to sites that host malware or other threats, keeping your local hosts safe.
#. Application-level controls: Implement application-level controls, such as Access Control Lists (ACLs) and user authentication, in applications running on local hosts. These controls help restrict access to unauthorized users or sources, including those from remote blacklisted hosts.
#. Patch management: Keep all applications, operating systems, and software running on your local hosts up-to-date with the latest patches and updates. Outdated software can be exploited by attackers, allowing them to bypass other security controls and gain access to your network.
#. Virtual Private Networks (VPNs): Use VPNs to create secure and encrypted connections between remote and local networks, ensuring that all traffic between them is properly secured and protected from external threats. Ensure that you use strong encryption, authentication methods, and regularly update your VPN infrastructure.

.. _Risk 011:

Long-Lived Flow
===============
#. Configure Firewalls and Access Controls: Configure firewalls and access controls to limit the duration of connections based on source/destination IP addresses, protocols, or other parameters. This can help prevent long-lived flows from remaining open for an extended period of time.
#. Implement Flow Limiting: Use flow limiting to control the number of connections that are allowed between two endpoints. This can help prevent a large number of long-lived flows from being established, which could potentially be used for data exfiltration or other malicious activities.
#. Implement Intrusion Detection and Prevention Systems (IDS/IPS): Use IDS/IPS systems to identify and prevent long-lived flows based on known attack patterns or anomalous behavior. These systems can help you detect and respond to potential long-lived flow attacks in real time.

.. _Risk 012:

Low Goodput Ratio
=================
#. Configure Quality of Service (QoS) Policies: Implement QoS policies to prioritize and shape network traffic based on different parameters, including goodput. This can help ensure that important applications or services receive adequate bandwidth, while flows with low goodput are limited or blocked.
#. Use Traffic Shaping Techniques: Use traffic shaping techniques such as throttling, policing, and rate limiting to control the amount of data that can be transferred over the network during a given period of time. This can help prevent flows from transferring data at rates below the specified threshold.
#. Implement Data Loss Prevention (DLP) Solutions: Use DLP solutions to identify, monitor, and control sensitive data as it moves across your network. These solutions can help you prevent low goodput flows of sensitive data from being exfiltrated or slowed down.

.. _Risk 013:

Blacklisted Server Contact
==========================
#. Firewall rules: Configure your firewall to block traffic to known malicious or blacklisted servers based on their IP addresses or domains. You can use various sources for IP addresses and domains, such as public blacklists like SpamHaus, SORBS, and others. Ensure that your firewall is updated with the latest list of blacklisted IPs and domains to effectively block unwanted traffic.
#. DNS filtering: Use DNS filtering to block access to known malicious websites or IP addresses by modifying the DNS response. DNS filtering can help prevent connections to sites that host malware or other threats, keeping your local hosts from contacting blacklisted servers.
#. Content filtering: Implement content filtering at your network's edge using solutions like Web Security Gateways or Email Security Appliances. These solutions can analyze inbound and outbound traffic for malicious content, such as emails with spam or phishing attachments, and block it from being sent to local hosts or accessed by them.
#. Application-level controls: Implement application-level controls, such as Access Control Lists (ACLs) and user authentication, in applications running on local hosts. These controls help restrict access to unauthorized servers or websites, including those that are blacklisted.
#. Regularly review and update your whitelist: Ensure that your whitelist of approved websites, IP addresses, and domains is up-to-date and only includes trusted resources. Regularly reviewing and updating this list can help prevent unintended connections to blacklisted servers and maintain the overall security of your network.

.. _Risk 016:

Remote to Remote
================
#. Implement Network Access Controls: Use network access controls such as firewalls, virtual private networks (VPNs), and access lists to limit traffic between remote clients and servers based on specific criteria, such as IP addresses, user identities, or protocols. This can help prevent unauthorized access or data transfer between the two endpoints.
#. Use Secure Communication Protocols: Ensure that secure communication protocols, such as SSL/TLS, SSH, or VPNs, are used for all traffic between remote clients and servers to encrypt and protect the data being transferred. This can help prevent interception and eavesdropping on the network.
#. Implement Intrusion Detection and Prevention Systems (IDS/IPS): Use IDS/IPS systems to identify and prevent flows with remote client and server based on known attack patterns or anomalous behavior. These systems can help you detect and respond to potential attacks in real time.

.. _Risk 019:

TCP Packets Issues
==================
#. Implement Quality of Service (QoS) Policies: Use QoS policies to prioritize and shape network traffic based on different parameters, including packet loss and delay sensitivity. This can help ensure that important applications receive adequate bandwidth and priority, while less critical applications are given lower priority or limited bandwidth.
#. Implement Traffic Shaping Techniques: Use traffic shaping techniques such as smoothing, filtering, and policing to control the amount of data being transmitted on the network at any given time. This can help reduce the likelihood of packet loss or out-of-order packets.
#. Use Forward Error Correction (FEC): Implement FEC technologies that can detect and correct errors in real-time, reducing the need for retransmissions and improving overall network performance.
#. Optimize Applications: Ensure that applications are optimized for network conditions by implementing features such as congestion control, error recovery, and flow control. This can help reduce the likelihood of retransmissions, out-of-order packets, and packet loss issues.

.. _Risk 022:

TLS Cert Expired
================
#. Obtain a New Certificate: Request and obtain a new TLS certificate from a trusted certificate authority (CA) or internal certificate management system. Ensure that the private key used to generate the new certificate is kept securely.
#. Update the Endpoint Configuration: Install and configure the new TLS certificate on the endpoint that was using the expired certificate. This may involve updating configuration files, restarting services, or installing new software.
#. Configure Automatic Certificate Renewal: Implement an automated process to renew or replace certificates before they expire in the future. This can help ensure that your organization's network remains secure against potential attacks that could exploit expired certificates.

.. _Risk 023:

TLS Cert Mismatch
=================
#. Implement Certificate Pinning: Use certificate pinning to ensure that specific, trusted certificates are used for SSL/TLS communication between endpoints. This can help prevent TLS certificate mismatch issues by preventing the use of untrusted or invalid certificates.
#. Verify Certificate Chain of Trust: Ensure that the entire certificate chain is valid and trusted, from the leaf certificate (the one installed on the endpoint) to the root certificate authority (CA). This can help ensure that SSL/TLS communication is secure and that no intermediate certificates have been revoked or expired.
#. Implement Automated Certificate Management: Use automated certificate management tools to renew, replace, or generate new certificates as needed. Ensure that all certificates are installed and configured correctly on endpoints and that any changes are propagated to all relevant endpoints in a timely manner.
#. Monitor Certificate Revocation Lists (CRLs) and Online Certificate Status Protocol (OCSP): Implement mechanisms for checking CRLs and OCSP to ensure that all SSL/TLS certificates are valid and not revoked or suspended. This can help prevent TLS certificate mismatch issues caused by compromised or invalid certificates.

.. _Risk 025:

Unsafe TLS Ciphers
==================
#. Update Cipher Suites: Ensure that all endpoints are configured to use only secure and up-to-date TLS cipher suites. This may involve updating configuration files or installing new software.
#. Implement Strict Security Policies: Use strict security policies to enforce the use of specific, secure cipher suites for SSL/TLS communication between endpoints. This can help prevent the use of weak or outdated ciphers that are vulnerable to attacks.
#. Implement TLS Protocol Negotiation: Use TLS protocol negotiation to ensure that endpoints are using the latest and most secure version of the SSL/TLS protocol. This can help prevent attacks that exploit vulnerabilities in older SSL/TLS versions.
#. Implement HSTS: Implement HTTP Strict Transport Security (HSTS) to enforce the use of SSL/TLS encryption for all communication between endpoints and web servers. This can help prevent man-in-the-middle attacks and other security vulnerabilities that rely on weak or unencrypted connections.

.. _Risk 027:

Web Mining
==========
#. Block Known Crypto Mining Malware: Implement security software and firewalls that can detect and block known crypto mining malware. Keep these tools up-to-date with the latest signatures and definitions to ensure effective protection against new and emerging threats.
#. Use Content Filtering: Implement content filtering policies to block access to known crypto mining websites and domains. This can help prevent users from unintentionally visiting sites that may attempt to install crypto mining software on their systems.
#. Implement Endpoint Protection: Use endpoint protection software to prevent unauthorized crypto mining on individual systems. This could include antivirus software, host-based intrusion prevention systems, and other security tools that can detect and block crypto mining malware.
#. Implement Network Segmentation: Use network segmentation to isolate critical systems from potential threats posed by crypto mining activity. This can help prevent the spread of crypto mining malware or other malicious software throughout your organization's networks.

.. _Risk 028:

TLS Cert Self-signed
====================
#. Obtain a Valid Certificate: Request and obtain a valid certificate from a trusted CA. Ensure that the private key used to generate the new certificate is kept securely.
#. Update Endpoint Configuration: Install and configure the new certificate on endpoints that were using self-signed certificates. This may involve updating configuration files, restarting services, or installing new software.
#. Implement Automatic Certificate Renewal: Implement an automated process to renew or replace certificates before they expire in the future. This can help ensure that your organization's network remains secure against potential attacks that could exploit weak or invalid certificates.
#. Implement Certificate Validation Policies: Use certificate validation policies to ensure that only valid and trusted SSL/TLS certificates are used for SSL/TLS communication within your organization's networks. This can help prevent the use of weak, invalid, or outdated certificates that could pose security risks.

.. _Risk 029:

Binary App/.exe Transfer
========================
#. Implement Content Filtering: Use content filtering policies to block the download or upload of binary applications from untrusted sources. This can help prevent the introduction of malware or other unwanted software into your systems.
#. Use Application Whitelisting: Implement application whitelisting policies to restrict the execution of specific, trusted binary applications on endpoints. This can help prevent the execution of malicious or unauthorized software.
#. Use Sandboxing: Use sandboxing techniques to isolate and test new binary applications in a secure environment before deploying them to production systems. This can help identify any potential security risks or vulnerabilities before they are introduced into your production environment.

.. _Risk 030:

Known Proto on Non Std Port
===========================
#. Configure Firewalls: Configure firewalls to block traffic to and from non-standard ports for known protocols. This can help prevent unauthorized access to your systems or data.
#. Implement Port Scanning Protection: Use intrusion prevention systems or other network security tools to detect and block port scans, which could be indicative of an attempt to identify non-standard protocol usage.
#. Use Secure Communication Protocols: Implement secure communication protocols, such as SSL/TLS or SSH, for all communication between systems and applications. This can help ensure that data is transmitted securely over encrypted channels, even if the underlying protocol is non-standard or used on a non-standard port.

.. _Risk 032:

Unexpected DHCP server found
============================
#. Implement IP Address Management: Use a centralized IP address management solution to manage and control IP addresses across your network. This can help prevent IP address conflicts that could result from the introduction of unexpected DHCP servers.
#. Implement DHCP Snooping Protection: Use DHCP snooping protection technologies to prevent unauthorized access to DHCP information and prevent attackers from distributing malicious configurations.
#. Configure Firewalls: Configure firewalls to block traffic to and from non-standard DHCP ports or IP addresses. This can help prevent rogue DHCP servers from providing configurations to clients on your network.
#. Implement DHCP Security Best Practices: Ensure that all DHCP servers are configured according to industry best practices, such as using secure communication protocols (e.g., TLS or SSL), implementing  access controls and authentication, and disabling unnecessary features.
#. Conduct Regular Audits: Conduct regular audits of your networks to identify any rogue or unexpected DHCP servers, and take appropriate remediation steps if necessary.

.. _Risk 033:

Unexpected DNS server
=====================
#. Configure Firewalls: Configure firewalls to block traffic to and from non-standard DNS ports or IP addresses. This can help prevent rogue DNS servers from providing incorrect configurations to clients on your network.
#. Implement DNS Security Best Practices: Ensure that all DNS servers are configured according to industry best practices, such as using secure communication protocols (e.g., DNSSEC), implementing access controls and authentication, and disabling unnecessary features.
#. Conduct Regular Audits: Conduct regular audits of your networks to identify any rogue or unexpected DNS servers, and take appropriate remediation steps if necessary.

.. _Risk 034:

Unexpected SMTP server found
============================
#. Configure Firewalls: Configure firewalls to block traffic to and from non-standard SMTP ports or IP addresses. This can help prevent rogue SMTP servers from sending emails on behalf of users or devices on your network.
#. Implement Email Security Best Practices: Ensure that all SMTP servers are configured according to industry best practices, such as using Transport Layer Security (TLS) encryption, implementing access controls and authentication, and disabling unnecessary features.
#. Implement Email Filtering: Use email filtering technologies, such as spam filters and antivirus software, to block known malicious emails before they reach users.
#. Implement Multi-Factor Authentication: Use multi-factor authentication (MFA) technologies for email accounts, especially those with administrative privileges. This can help prevent unauthorized access to email accounts and reduce the risk of email attacks.

.. _Risk 035:

Unexpected NTP server found
===========================
#. Configure Firewalls: Configure firewalls to block traffic to and from non-standard NTP ports or IP addresses. This can help prevent rogue NTP servers from synchronizing the time on devices on your network.
#. Implement NTP Security Best Practices: Ensure that all NTP servers are configured according to industry best practices, such as using secure communication protocols (e.g., authentication), implementing access controls and encryption, and disabling unnecessary features.
#. Implement Time Synchronization Protection: Use time synchronization protection technologies to prevent devices from using stale or incorrect time information from rogue NTP servers.

.. _Risk 036:

TCP Zero Window
===============
#. Implement Firewalls: Configure firewalls to block traffic that contains a Zero TCP Window packet. Most modern firewalls have built-in protection against this attack.
#. Implement Intrusion Detection Systems (IDS): Use IDS technologies to detect and prevent Zero TCP Window attacks in real-time. IDS solutions can identify suspicious traffic patterns and alert administrators before an attack occurs.
#. Implement Traffic Shaping: Use traffic shaping technologies to limit the amount of traffic that can be sent or received on a network interface at any given time. This can help prevent a single connection from consuming all available bandwidth, making it more difficult for an attacker to launch a successful Zero TCP Window attack.
#. Implement Rate Limiting: Use rate limiting technologies to limit the number of requests or responses that can be sent or received from a specific IP address within a specified time period. This can help prevent a single source from overwhelming a server with traffic, making it more difficult for an attacker to launch a Zero TCP Window attack.
#. Implement Application-level Protections: Many applications and operating systems offer built-in protections against Zero TCP Window attacks. Make sure that all applications and operating systems are up-to-date with the latest security patches and configurations.

.. _Risk 037:

IEC Invalid Transition
======================
#. Use Secure Configuration Practices: Ensure that all switches and other networking devices are configured securely, with strong passwords, access control lists, and encryption enabled where appropriate.
#. Patch Switches: Keep all switches and networking devices up-to-date with the latest firmware patches and security updates. This can help prevent known vulnerabilities that could be exploited to inject Invalid IEC Transition frames onto your network.
#. Implement VLAN Trunking Security: Use best practices for implementing VLAN trunking securely, such as using EAP-TLS or 802.1X authentication, enabling port security, and configuring access control lists.
#. Implement Intrusion Detection Systems (IDS): Use IDS technologies, such as firewalls or intrusion prevention systems, to block known malicious traffic, including Invalid IEC Transition frames.


.. _Risk 038:

Remote to Local Insecure Flow
=============================
#. Configure a Firewall: Use a firewall to block incoming traffic from the remote server on the specific ports used by the insecure protocol. This will prevent the remote server from being able to connect to your local host over that protocol.
#. Implement Secure Protocols: Encourage the use of secure communication protocols, such as TLS/SSL or SSH, whenever possible. These protocols provide encryption and authentication features that help protect data transmitted between servers.
#. Configure Access Control Lists (ACLs): Use ACLs to control which IP addresses or domains are allowed to access specific services on your local host. This can help prevent unauthorized access from remote servers using insecure protocols.
#. Implement Secure Configuration Practices: Ensure that all servers and applications are configured securely, with strong passwords, access control lists, and encryption enabled where appropriate.

.. _Risk 055:

IEC Unexpected TypeID
=====================
#. Configure Device Profiles: Ensure that all devices are configured with approved device profiles that adhere to industry standards and do not allow the use of unexpected Type IDs. You can also consider implementing a device hardening policy to further restrict configuration options.
#. Implement Signature-Based Detection: Use intrusion detection systems (IDS) or firewalls with signature-based detection capabilities to identify and block traffic that contains unexpected Type IDs in IEC 104 protocol messages. This can help prevent attackers from exploiting known vulnerabilities associated with these IDs.
#. Implement Protocol Validation: Use protocol validation techniques, such as message digest algorithms or message authentication codes (MAC), to ensure the integrity of IEC 104 protocol messages and detect any unexpected modifications, including those related to Type IDs.
#. Implement Strong Authentication: Use strong authentication mechanisms, such as digital certificates or two-factor authentication, to secure communications between devices using the IEC 104 protocol. This can help prevent unauthorized access and modification of protocol messages, including those related to Type IDs.

.. _Risk 056:

TCP No Data Exchanged
=====================
#. Investigate TCP Stack Configuration: Ensure that both hosts have correctly configured their TCP stacks. Incorrect settings, such as incorrect MTU values or misconfigured window sizes, can result in NDE flows.
#. Use Tools to Diagnose TCP Issues: Utilize tools such as Wireshark or tcpdump to capture and analyze network traffic related to the failed connection attempt. This can help identify issues with packet loss, reordering, or other TCP protocol violations that could be causing NDE flows.
#. Check for Firewall Rules: Verify that firewalls or other security devices are not blocking the TCP connection attempt. Incorrect rules or misconfigured policies could be causing NDE flows.
#. Implement Keepalive Mechanisms: Use TCP keepalive mechanisms to periodically probe connections and detect any abnormal behavior, such as NDE flows. This can help you quickly identify and address potential issues before they impact your users.

.. _Risk 057:

Remote Access
=============
#. Implement Strong Access Controls: Use strong access controls to limit who is able to access your systems and networks remotely. This can include using multi-factor authentication (MFA), strong password policies, and other security measures such as virtual private networks (VPNs) or secure remote access solutions.
#. Use Encryption: Ensure that all communications during a remote access session are encrypted. This includes both the data being transmitted as well as any associated metadata such as usernames and passwords.
#. Implement Least Privilege Principle: Ensure that users only have the necessary permissions to perform their job functions and no more. This can help minimize the potential impact of a compromised remote access session.
#. Use Firewalls and Access Control Lists (ACLs): Implement firewalls and ACLs to control incoming and outgoing traffic to and from your systems and networks during a remote access session. This can help prevent unauthorized access or data exfiltration.

.. _Risk 058:

Lateral Movement on Service Map
===============================
#. Regularly Scan Your Network: Implement network scanning tools that can help you identify any unexpected services appearing on your network. These tools should be able to detect both known and unknown services, as well as provide information about their potential impact on your network's security.
#. Use Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to unauthorized or malicious activity related to unexpected services. These systems should be able to analyze traffic patterns and identify any suspicious behavior, such as attempts to exploit vulnerabilities in a new service.
#. Implement Network Segmentation: Use network segmentation to separate different parts of your network and limit the spread of any potential threats related to unexpected services. This can include using firewalls, access control lists (ACLs), and other security measures.
#. Conduct Regular Security Assessments: Perform regular security assessments of your network to identify any potential weaknesses or misconfigurations that could be exploited by attackers to introduce unexpected services. This can include vulnerability scans, penetration testing, and other security assessment methods.

.. _Risk 067:

Broadcast Non-UDP Traffic
=========================
#. Implement Access Controls: Use access controls to limit which hosts on your network are able to communicate with broadcast addresses using non-UDP protocols. This can include using firewalls, access control lists (ACLs), and other security measures.
#. Configure Network Devices: Configure your network devices, such as routers and switches, to not forward traffic from a host to a broadcast address using non-UDP protocols. This can help prevent unintended communication between hosts and reduce the risk of potential security vulnerabilities.
#. Use Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to any attempts by a host to contact a broadcast address using a non-UDP protocol. These systems should be able to analyze traffic patterns and provide real-time alerts for any potential issues.
#. Implement Network Segmentation: Use network segmentation to separate different parts of your network and limit the spread of any potential threats related to a host contacting a broadcast address using a non-UDP protocol. This can include using firewalls, access control lists (ACLs), and other security measures.
#. Configure Hosts: Configure hosts to not use non-UDP protocols when communicating with broadcast addresses. This can help reduce the potential for accidental or unintended communication that could introduce security vulnerabilities.

.. _Risk 074:

IEC Invalid Command Transition
==============================
#. Configure Industrial Devices: Configure your industrial devices to only accept valid IEC commands. This can involve implementing protocol validation checks, access controls, and other security measures to ensure that only authorized commands are processed.
#. Implement Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to any attempts to send invalid IEC commands to your industrial control systems. These systems should be able to analyze traffic patterns and provide real-time alerts for any potential issues.
#. Implement Network Segmentation: Use network segmentation to separate different parts of your industrial control systems and limit the spread of any potential threats related to invalid IEC commands. This can include using firewalls, access control lists (ACLs), and other security measures.
#. Implement Regular Security Assessments: Perform regular security assessments of your industrial control systems to identify any potential weaknesses or misconfigurations that could be exploited by attackers to send invalid IEC commands. This can include vulnerability scans, penetration testing, and other security assessment methods.

.. _Risk 075:

No Answer
=========
#. Configure Firewalls and Routers: Configure firewalls and routers to only allow incoming traffic from trusted sources, and block traffic from other sources. This can help prevent unauthorized TCP connection attempts, as well as reduce the risk of potential security vulnerabilities.
#. Use Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to any attempts to initiate TCP connections without receiving a response from the server. These systems should be able to analyze traffic patterns and provide real-time alerts for any potential issues.
#. Implement Network Segmentation: Use network segmentation to separate different parts of your network and limit the spread of any potential threats related to TCP connection attempts without responses from the server. This can include using firewalls, access control lists (ACLs), and other security measures.
#. Implement Regular Security Assessments: Perform regular security assessments of your network to identify any potential weaknesses or misconfigurations that could be exploited by attackers to initiate TCP connection attempts without responses from the server. This can include vulnerability scans, penetration testing, and other security assessment methods.

.. _Risk 091:

VLAN Bidirectional Traffic
==========================
#. Configure Firewalls and Routers: Configure firewalls and routers to only allow traffic between trusted sources and destinations, and block traffic from other sources. Use access control lists (ACLs) to define rules for inbound and outbound traffic based on source IP addresses, destination IP addresses, protocols, and ports.
#. Implement VLAN Segmentation: Use VLAN segmentation to separate different parts of your network and limit the spread of any potential threats related to bidirectional flows between VLAN members and remote servers. This can help prevent unauthorized traffic and reduce the risk of security vulnerabilities.
#. Use Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to any attempts to establish bidirectional flows between VLAN members and remote servers. These systems should be able to analyze traffic patterns, user behavior, and other relevant data to help you quickly respond to any potential security threats.
#. Implement Regular Security Assessments: Perform regular security assessments of your VLAN and network infrastructure to identify any potential weaknesses or misconfigurations that could be exploited by attackers to establish bidirectional flows between VLAN members and remote servers. This can include vulnerability scans, penetration testing, and other security assessment methods.

.. _Risk 092:

Rare Destination
================
#. Configure Firewalls and Routers: Configure firewalls and routers to only allow traffic to rare destinations from trusted sources, and block traffic from other sources. Use access control lists (ACLs) to define rules for inbound and outbound traffic based on source IP addresses, destination IP addresses, protocols, and ports.
#. Implement Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to any attempts to initiate flows to rare destinations. These systems should be able to analyze traffic patterns, user behavior, and other relevant data to help you quickly respond to any potential security threats.
#. Implement Network Segmentation: Use network segmentation to separate different parts of your network and limit the spread of any potential threats related to flows to rare destinations. This can help prevent unauthorized traffic and reduce the risk of security vulnerabilities.
#. Implement Regular Security Assessments: Perform regular security assessments of your network infrastructure to identify any potential weaknesses or misconfigurations that could be exploited by attackers to initiate flows to rare destinations. This can include vulnerability scans, penetration testing, and other security assessment methods.

.. _Risk 093:

ModbusTCP Invalid Function Code
===============================
#. Configure Firewalls and Routers: Configure firewalls and routers to only allow traffic to Modbus devices from trusted sources, and block traffic from other sources. Use access control lists (ACLs) to define rules for inbound and outbound traffic based on source IP addresses, destination IP addresses, protocols, and ports.
#. Implement Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to any attempts to use invalid function codes with Modbus devices. These systems should be able to analyze traffic patterns, user behavior, and other relevant data to help you quickly respond to any potential security threats.
#. Implement Modbus Device Security Best Practices: Ensure that all Modbus devices are configured with strong passwords, access controls, and other security best practices to prevent unauthorized access or use of invalid function codes. This can include implementing two-factor authentication, disabling unnecessary features or services, and regularly updating firmware and software.
#. Implement Regular Security Assessments: Perform regular security assessments of your Modbus devices and network infrastructure to identify any potential weaknesses or misconfigurations that could be exploited by attackers to use invalid function codes. This can include vulnerability scans, penetration testing, and other security assessment methods.

.. _Risk 094:

ModbusTCP Too Many Exceptions
=============================
#. Check for physical connection problems: Ensure that all cables are properly connected, and there are no loose connections, shorts, or breaks in the network. Verify that power supplies are functioning correctly and providing stable power to the devices.
#. Inspect Modbus TCP settings: Make sure that both master and slave devices have the correct Modbus TCP settings, such as IP addresses, baud rates, data lengths, parity, stop bits, and flow control. Check if any misconfigurations or mismatches exist between the master and slave devices.
#. Implement error handling: Review the Modbus TCP protocol to ensure proper error handling is implemented, such as implementing retries or timeouts when exceptions occur. This approach will help minimize the impact of communication errors and prevent the accumulation of exceptions.
#. Check for interference: Eliminate any potential sources of electromagnetic or radiofrequency interference, such as nearby Wi-Fi routers, power lines, or other devices that could disrupt the Modbus TCP communication.

.. _Risk 095:

ModbusTCP Invalid Transition
============================
#. Configure Firewalls and Routers: Configure firewalls and routers to only allow traffic to Modbus devices from trusted sources, and block traffic from other sources. Use access control lists (ACLs) to define rules for inbound and outbound traffic based on source IP addresses, destination IP addresses, protocols, and ports.
#. Implement Intrusion Detection Systems (IDS): Implement IDS solutions that can help you detect and respond to any attempts to use invalid transitions with Modbus devices. These systems should be able to analyze traffic patterns, user behavior, and other relevant data to help you quickly respond to any potential security threats.
#. Implement Modbus Device Security Best Practices: Ensure that all Modbus devices are configured with strong passwords, access controls, and other security best practices to prevent unauthorized access or use of invalid transitions. This can include implementing two-factor authentication, disabling unnecessary features or services, and regularly updating firmware and software.
#. Implement Regular Security Assessments: Perform regular security assessments of your Modbus devices and network infrastructure to identify any potential weaknesses or misconfigurations that could be exploited by attackers to use invalid transitions. This can include vulnerability scans, penetration testing, and other security assessment methods.
