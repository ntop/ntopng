Remediations for ntopng Flow Risks
##################################

.. _Risk 084:
      
Remediations for ntopng Risks
#############################

.. _Risk 001:

NORMAL
======

#. **Description:** 
This alert signifies that no unusual activity or deviations from standard network behavior have been detected.

#. **Implied Security Risk:**
Detecting this alert indicates a stable and nominal security posture within the monitored network, as it suggests that no notable threats or vulnerabilities have been identified at this time.

.. _Risk 001:

BLACKLISTED
===========

#. **Description:**
This alert triggers when a device on the monitored network attempts to communicate with an IP address or domain that matches entries in the system's predefined blacklist.

#. **Implied Security Risk:**
Detecting this alert may indicate unauthorized access attempts, malware communications, or command and control (C2) activity directed towards compromised systems within the network. It could also signify a misconfiguration or infection by malicious software on devices attempting to communicate with blacklisted entities.

#. **Triggering conditions**:
 Outbound traffic from any device on the monitored network matches an entry in the system's predefined blacklist.

#. **Potential Causes:**
  1. Malware infection on devices within the network attempting to communicate with command and control servers.
  2. Misconfigured devices or systems accidentally communicating with blacklisted entities.
  3. Unauthorized access attempts by threat actors targeting vulnerable devices in the network.

#. **Recommended Actions:**
  1. Investigate the source device(s) triggering the alert for signs of compromise, such as the presence of malware or unusual activity.
  2. Implement additional security measures, like whitelisting trusted entities or enforcing strict outbound traffic policies.

#. **Additional Notes:**
This alert has a severity level of medium to high, depending on the frequency and nature of detections. It is particularly significant in networks with strict security requirements or those prone to malware infections. 

.. _Risk 002:

BLACKLISTED COUNTRY
===================

#. **Description:**
This alert triggers when a communication flow is detected between an internal network and a country that is present in a blacklist.

#. **Implied Security Risk:**
Detecting this alert may indicate unauthorized access attempts, data exfiltration, or command and control (C2) traffic by threat actors leveraging compromised devices in the blacklisted country. It poses a significant security risk as it could enable further network infiltration or data theft.

#. **Triggering conditions:**
- Any outgoing or incoming traffic to/from a blacklisted country's IP address.

#. **Potential Causes:**
  1. Internal users unintentionally accessing malicious or untrusted resources hosted in blacklisted countries.
  2. Misconfiguration of network policies allowing unauthorized traffic to/from blacklisted countries.

#. **Recommended Actions:**
  1. Block traffic to/from the involved IP address ranges and monitor for any attempted bypasses.

#. **Additional Notes:**
- This alert is particularly significant in networks with strict access control policies or industries subject to specific regulatory requirements (e.g., finance, healthcare).

.. _Risk 003:

FLOW BLOCKED
============

#. **Description:**
This alert indicates that a network flow has been abruptly terminated by the system before completing its natural lifecycle, which could be due to various reasons such as network congestion, configuration issues, or malicious activity.

#. **Implied Security Risk:**
Detecting this alert may suggest potential denial-of-service (DoS) attacks, misconfigured network devices, or other underlying network vulnerabilities that could impact availability and performance.

#. **Potential Causes:**
  1. Network congestion leading to flow blocking for Quality of Service (QoS) enforcement.
  2. Misconfigured network devices causing unintentional flow blocking.

#. **Recommended Actions:**
  1. Investigate the cause of network congestion or misconfiguration, and address it promptly to minimize false positives.
  2. Monitor for patterns indicative of DoS attacks, such as sudden high volumes of blocked flows from a single source.
  3. Consult network device logs and system metrics to identify potential points of failure causing flow blocking.

.. _Risk 004:

DATA EXFILTRATION
=================

#. **Description:**
This alert triggers when there's a suspected unauthorized transfer of data outside the network, potentially indicating an exfiltration attempt.

#. **Implied Security Risk:**
Detecting this alert may indicate that an attacker is actively attempting to steal valuable data, posing significant risks such as data leakage and potential compliance violations.

#. **Potential Causes:**
  1. Unauthorized insider attempting to steal data.
  2. Compromised internal host acting as an exfiltration agent controlled by external attacker.
  3. Accidental misconfiguration leading to unintended data transfer outside the network.

#. **Recommended Actions:**
  1. Investigate source IP address and user associated with the suspicious traffic.
  2. Review recent logs and changes for signs of compromise or unauthorized access.
  3. Implement Data Loss Prevention (DLP) mechanisms if not already in place.
  4. Consider blocking outbound traffic to unknown external IP addresses until further investigation.


#. **Severity level:** High, prompt investigation is recommended upon detection.
#. **Network environments:** Particularly significant in finance, healthcare, and other sectors handling confidential information.

.. _Risk 005:

DEVICE PROTOCOL NOT ALLOWED
===========================

#. **Description:**
This alert triggers when a device in the monitored network attempts to initiate or participate in communication using a protocol that has been explicitly disallowed by network policies.

#. **Implied Security Risk:**
Detection of this alert may indicate unauthorized or malicious activity attempting to bypass established security protocols, potentially exposing sensitive data or allowing unauthorized access to network resources. 

#. **Triggering conditions:**
A device sends a packet with an unsupported or disallowed protocol in the payload, header, or as the transport protocol.

#. **Potential Causes:**
  1. Misconfigured devices attempting to communicate using forbidden protocols.
  2. Malicious software or actors exploiting unknown vulnerabilities in network devices.
  3. Outdated device firmware leading to unintended usage of disallowed protocols.

#. **Recommended Actions:**
  1. Investigate the source device and its configuration to identify any misconfigurations or unauthorized changes.
  2. Review network logs for additional related alerts or unusual activities from the same device or subnet.
  3. Update device firmware and enforce strict access controls to prevent further occurrences.


#. **device_policy_violation**: 
This alert may co-occur if the device has other policy violations, suggesting potential misconfiguration or malicious activity.

#. **Additional Notes:**
This alert should be considered moderate severity in most environments. It is particularly significant in highly secure networks with strict protocol restrictions (e.g., military, government, or finance sectors). Frequent occurrences of this alert may warrant a full network security audit.


.. _Risk 006:

DNS DATA EXFILTRATION
=====================

#. **Description:**
This alert triggers when an unusual amount of DNS query traffic is detected, potentially indicating unauthorized data exfiltration via DNS tunneling.

#. **Implied Security Risk:**
Detecting this alert may signify a potential data breach where sensitive information is being covertly transmitted out of the network using DNS queries, posing significant confidentiality and compliance risks.

#. **Potential Causes:**
  1. DNS tunneling for data exfiltration or command and control communication.
  2. Malware infection causing unusual DNS activity.
  3. Misconfiguration of DNS servers leading to unexpected query spikes.

#. **Recommended Actions:**
  1. Investigate the source IP address(es) exhibiting anomalous behavior, including checking open ports, running processes, and network connections.
  2. Inspect traffic for signs of DNS tunneling by analyzing query patterns and content.
  3. Consult with security teams or external experts if evidence of malicious activity is found.

#. **Additional Notes:**
  - Frequency: Rare, but critical when triggered.
  - Severity level: High - immediate investigation is required to prevent data loss and mitigate potential risks.
  - Significance: This alert is particularly relevant in environments with high security requirements or strict data governance policies.

.. _Risk 007:

DNS INVALID QUERY
=================

#. **Description:**
This alert triggers when a DNS query contains invalid characters, exceeds its maximum length, or has other formatting issues that violate the DNS specification RFC 1035.

#. **Implied Security Risk:**
Detecting this alert may indicate attempts to bypass or exploit DNS servers through deliberate injection of malformed queries, potentially leading to denial-of-service conditions or unauthorized access to data stored within DNS records.

#. **Potential Causes:**
  1. Deliberate injection of malformed queries to cause denial-of-service conditions.
  2. Software bugs or misconfigurations leading to improperly formed DNS requests.
  3. Unintended use of non-standard characters in domain names due to software encoding issues.

#. **Recommended Actions:**
  1. Investigate the source IP address and user agent for signs of malicious activity.
  2. Check the DNS server configuration for any discrepancies or evidence of unauthorized access attempts.
  3. Implement packet filtering to drop malformed queries before they reach the DNS server.

#. **Additional Notes:**
  - Severity level: Medium
  - Frequency of occurrence: Low to moderate, typically associated with targeted attacks or software bugs.
  - This alert is particularly significant in environments with stringent security requirements and where DNS servers are critical components.

.. _Risk 008:

ELEPHANT FLOW
=============

#. **Description:**
This alert triggers when an unusually high volume of traffic (higher than predefined threshold) from a single source IP address is detected over an extended period (>60 seconds).

#. **Implied Security Risk:**
Detecting this alert may indicate data exfiltration or Distributed Denial of Service (DDoS) attack in progress, or could suggest a compromised device being used as a spam source within the network.

#. **Potential Causes:**
  1. Hosts downloading big size files (file transfer)
  2. Compromised device exfiltrating data
  3. Software updates 

#. **Recommended Actions:**
  1. Immediately investigate the identified source IP address for signs of compromise.
  2. Implement rate-limiting on network hardware and software to prevent future occurrences.

#. **Additional Notes:**
  - Severity level: High
  - Frequency of occurrence: Low, but can lead to significant network disruption when triggered

.. _Risk 009:

BLACKLISTED CLIENT CONTACT
==========================

#. **Description:**
This alert triggers when a blacklisted client (flow source IP) attempts to establish contact with a destination IP address which belongs to the local network.

#. **Implied Security Risk:**
Detecting this alert suggests that potentially malicious traffic is trying to initiate communication within your network, indicating possible command and control (C2) activity from known threat actors. It may also imply that your blacklist needs updating or that there are unknown infected systems, these systems could be the source IPs that triggered this alert or other IPs that contacted the same destination IP as this within your network attempting to communicate with external threats.

#. **Potential Causes:**
  1. An infected system within your network is attempting to communicate with a known threat actor.
  2. Outdated blacklists leading to false positives.

#. **Recommended Actions:**
  1. Investigate the source IP address to determine if it's compromised and isolate it if necessary.
  2. Verify that your blacklist is up-to-date, and update it as needed.
  3. Review network configurations to ensure no legitimate systems are communicating with blacklisted entities.

#. **Additional Notes:**
This alert is considered high severity, as it indicates potential C2 activity. It's particularly significant in enterprise environments where maintaining an up-to-date blacklist and monitoring network communications are crucial. The frequency of this alert may vary depending on the size of your network and its exposure to threats.

.. _Risk 010:

EXTERNAL ALERT
==============

#. **Description:**
This alert is triggered when an event is received from an external third-party security tool. An example of this is when ntopng is integrated with Suricata, which exports alerts in EVE JSON format to syslog. ntopng collects Suricata alerts though the syslog interface and exports them as ntopng alerts to the configured endpoints for dispatching.

#. **Implied Security Risk:**
Detecting this alert may indicate a multitude of different issues, depending on the source.

#. **Recommended Actions:**
Investigate and identify any security risk based on the reported message, which comes from the alert source.
In case the alert comes from Suricata, check the signature matching the specific alert for remediation.

.. _Risk 011:

LONG LIVED FLOW
==============

#. **Description:**
The long lived flow alert is triggered when a flow is active for at least a configurable period of time (e.g. 5 minutes), potentially indicating a botnet or other persistent threat.

#. **Implied Security Risk:**
Detecting this alert may indicate the presence of compromised devices or systems engaged in data exfiltration, command and control (C&C) communications, or other malicious activities using long-lived, idle connections to avoid detection.

#. **Potential Causes:**
  1. Botnet C&C communications using long-lived idle connections to evade detection.
  2. Compromised systems used as proxies or zombies for further attacks.
  3. Misconfiguration or improper usage of network services leading to unnecessary long-lived idle connections.

#. **Recommended Actions:**
  1. Investigate the source and destination IP addresses, ports, and other relevant packet metadata to identify potential compromised hosts or malicious activities.
  2. Review the traffic patterns associated with these long-lived idle connections for anomalies that may indicate command and control communications.
  3. Implement rate-limiting or connection time-out policies to mitigate the risk of excessive long-lived idle connections.

#. **Additional Notes:**
This alert is particularly significant in enterprise environments with strict network access controls and large numbers of connected devices. Regular monitoring and threshold tuning may be necessary to adapt to normal traffic patterns during peak usage hours. The severity level associated with this alert should be configurable based on the organization's risk tolerance and the specific threshold values for idle connection duration and count.

.. _Risk 012:

LOW GOODPUT
===========

#. **Description:**
The `low_goodput` alert triggers when the ratio of goodput to throughput for a network flow falls below a predefined threshold, indicating potential congestion or efficiency issues.

#. **Implied Security Risk:**
Low goodput may indicate resource exhaustion attacks, misconfigured QoS settings, or denial-of-service conditions that could degrade network performance and availability.

#. **Potential Causes:**
1. **Congestion:** High traffic load or insufficient bandwidth leading to queuing delays and reduced goodput.
2. **Misconfigured QoS:** Incorrect Quality of Service settings causing preferential treatment for other flows, starving the monitored flow of resources.
3. **DoS/DDoS attacks:** Targeted flooding of network links or services, consuming available bandwidth and lowering goodput.

#. **Recommended Actions:**
1. Investigate traffic sources and patterns contributing to congestion; consider rate-limiting, traffic shaping, or load balancing techniques to manage high-traffic flows.
2. Review QoS settings for accurate prioritization of critical services and applications.
3. Monitor for signs of DoS/DDoS attacks, such as sudden spikes in traffic volume or source IP addresses, and implement appropriate countermeasures.

#. **Additional Notes:**
- *Frequency:**Moderate to high frequency in high-traffic environments.
- *Severity:**Medium; persistent low goodput may impact service performance but is less critical than complete denial of service.

.. _Risk 013:

BLACKLISTED SERVER CONTACT
==========================

#. **Description:**
This alert triggers when a localhost (source IP address) on the monitored network initiates contact with an IP destination address or domain listed in the system's predefined blacklist.

#. **Implied Security Risk:**
Detecting this alert may indicate that an infected machine within the network is attempting to communicate with command and control (C2) servers, potentially facilitating unauthorized data exfiltration or receiving malicious commands. It could also suggest that an attacker has compromised a device and is using it to reach out to their own infrastructure.

#. **Potential Causes:**
  1. Compromised devices within the network attempting to communicate with blacklisted servers.
  2. Inadvertent inclusion of legitimate internal IP addresses or domains in the blacklist, leading to false positives.
  3. Misconfiguration or errors during blacklist maintenance causing irrelevant entries.

#. **Recommended Actions:**
  1. Investigate the originating device(s) to identify any signs of infection or unauthorized changes.
  2. Check the blacklist for accuracy and remove any false-positive entries if necessary.
  3. Monitor further network activity from the affected devices for related threats, such as data exfiltration or lateral movement.

#. **Additional Notes:**
- The frequency of occurrence and severity level depend on the size of the blacklist and the number of infected or compromised devices within the network.
- This alert is particularly significant in environments with strict security policies regarding outbound traffic.

.. _Risk 014:

INTERNAL DATA LEAKAGE
=====================

#. **Description:**
This alert triggers when internal network data, such as sensitive information or confidential communications, is exfiltrated via unusual or unauthorized channels like unsanctioned cloud services or unknown external hosts.

#. **Implied Security Risk:**
Detecting this alert may indicate a potential data breach due to compromised credentials, malicious insiders, or advanced persistent threats (APTs). It could also reveal unauthorized data sharing practices that violate regulatory compliance policies.

#. **Potential Causes:**
  1. Malware infection on internal systems leading to data exfiltration.
  2. Insider threats intentionally leaking sensitive information.
  3. Configuration errors or misinterpretations of access policies.

#. **Recommended Actions:**
  1. Investigate the source IP address and system that initiated the data transfer.
  2. Review access logs for suspicious user activities or unauthorized access attempts.
  3. Inspect the affected systems for signs of infection by malware or other malicious software.
  4. Implement strict access controls and whitelisting policies for cloud services.

#. **Additional Notes:**
- This alert is typically considered high severity due to the potential loss of sensitive data.
- It is particularly significant in environments with strict regulatory compliance requirements, such as finance or healthcare sectors.

.. _Risk 016:

REMOTE TO REMOTE
================

#. **Description:**
This alert triggers when a device on the monitored network is detected to be communicating directly with another device outside of its normal subnet, potentially indicating an attempt at unauthorized inter-VLAN routing or bypassing network segmentation controls.

#. **Implied Security Risk:**
Detecting this alert may suggest that an attacker has gained unauthorized access to restricted segments of the network, leading to potential data leakage or lateral movement of threats. It could also indicate a misconfiguration in network segmentation controls.

#. **Potential Causes:**
  1. Misconfigured network segmentation controls.
  2. Attempted unauthorized access or lateral movement of threats within the network.
  3. Potential existence of rogue devices or unauthorized VLANs.

#. **Recommended Actions:**
  1. Investigate and verify if the communication is authorized and necessary. If not, block the traffic at the network level.
  2. Review and reconfigure network segmentation controls to prevent unauthorized direct communication between subnets.
  3. Consider conducting a thorough network scan to identify any unknown devices or rogue VLANs.

#. **Additional Notes:**
This alert is particularly significant in environments with strict network segmentation policies or those containing sensitive data, such as data centers and financial institutions. The frequency of occurrence depends on the network's traffic patterns and security posture.

.. _Risk 019:

TCP PACKET ISSUES
=================

#. **Description:**
This alert is triggered when Deep Packet Inspection (DPI) identifies inconsistent or improper handling of TCP packets, such as missing flags, unexpected options, or invalid sequence numbers.

#. **Implied Security Risk:**
Detecting this alert may indicate misconfigured network devices, protocol anomalies that could facilitate attacks like session hijacking or denial-of-service, or even malicious activity exploiting TCP vulnerabilities to disrupt communications or gather sensitive data.


#. **Potential Causes:**
  1. Misconfigured network devices (firewalls, routers) resulting in improper packet handling.
  2. Malicious activity exploiting TCP vulnerabilities or implementing custom TCP protocols for evasive purposes.
  3. Network congestion or interference causing TCP sequence number wraparound.

#. **Recommended Actions:**
  1. Investigate the source and destination IP addresses of suspicious packets to identify potential problematic hosts or network segments.
  2. Analyze traffic patterns between these hosts to determine if there are any suspicious activities or anomalies.
  3. Review and update configurations of relevant network devices to ensure proper TCP handling and mitigate potential vulnerabilities.

#. **Additional Notes:**
- This alert is typically considered medium severity, as it may indicate both benign misconfigurations and serious security threats.
- It is particularly significant in environments with high network traffic loads or critical systems relying on secure TCP communications.

.. _Risk 020:

TCP CONNECTION REFUSED
======================

#. **Description:**
This alert triggers when a TCP connection attempt is refused by the target host, indicating potential issues with network connectivity or service availability.

#. **Implied Security Risk:**
A high number of refused connections could indicate a DoS attack, misconfiguration, or service outage, potentially disrupting network services and impacting users.

#. **Potential Causes:**
  1. Network misconfiguration or firewall rules blocking connections.
  2. Service outage or unavailability on the target host.
  3. DoS attack targeting network services with refused connection attempts.

#. **Recommended Actions:**
  1. Check the target host's service status and network connectivity.
  2. Review and update firewall rules to allow legitimate traffic.
  3. Implement rate-limiting or other countermeasures against potential DoS attacks.
  4. Monitor refused connections over time to identify persistent issues or trends.

#. **Additional Notes:**
- High frequency of this alert may indicate a network under stress or under attack.
- Severity level is typically low to medium, depending on the context and number of refused connections.

.. _Risk 021:

TCP SEVERE CONNECTION ISSUES
============================

#. **Description:**
This alert triggers when a TCP connection experiences severe issues such as excessive retransmissions, resets, or timeouts, indicating potential network problems or malicious activity.

#. **Implied Security Risk:**
Detecting this alert may suggest a Denial of Service (DoS) attack targeting network availability, or it could indicate misconfigured or faulty network devices that need immediate attention to prevent service disruptions.

#. **Potential Causes:**
  1. TCP state exhaustion attacks.
  2. Misconfigured or failing network devices, such as load balancers or firewalls.
  3. High traffic volumes causing temporary network congestion.

#. **Recommended Actions:**
  1. Investigate the source IP addresses triggering the alert for suspicious activity or patterns.
  2. Check network devices' logs and configurations for signs of misconfiguration or failures.
  3. Monitor CPU and memory usage on affected systems to identify potential resource exhaustion issues.
  4. Consider implementing rate-limiting or connection throttling measures to protect against future attacks.

#. **Additional Notes:**
This alert has a high severity level ( Critical ). It is particularly significant in networks with strict availability requirements, such as data centers or financial institutions. Frequent occurrences of this alert may warrant network infrastructure upgrades to improve performance and reliability.

.. _Risk 022:

TLS CERTIFICATE EXPIRED
=======================

#. **Description:**
This alert is triggered when a Transport Layer Security (TLS) certificate used in network communication is found to be expired during deep packet inspection.

#. **Implied Security Risk:**
An expired TLS certificate can compromise secure communications by allowing man-in-the-middle attacks and potentially exposing sensitive data, indicating a high-risk vulnerability in the monitored network.

#. **Potential Causes:**
  1. Negligence in renewing the certificate before expiration.
  2. Misconfiguration of certificate renewal processes or automated systems.
  3. Spoofed or malicious certificates intended to disrupt secure communications.

#. **Recommended Actions:**
  1. Immediately replace the expired certificate with a valid one from a trusted Certificate Authority (CA).
  2. Review and update certificate management procedures to ensure timely renewals.
  3. Investigate potential indicators of compromise, as expired certificates may be signs of tampering or unauthorized access attempts.


#. **Additional Notes:**
- Severity level: High
- Frequency of occurrence: Low to moderate in well-maintained networks, but may increase due to misconfigurations or neglect.
- Environments where this alert is particularly significant: Critical infrastructure and high-security networks handling sensitive data.

.. _Risk 023:

TLS CERTIFICATE MISMATCH
========================

#. **Description:**
This alert triggers when a TLS/SSL handshake contains a mismatch between the expected and presented server certificate, indicating potential man-in-the-middle attacks or misconfigured servers.

#. **Implied Security Risk:**
Detecting this alert may suggest that an attacker is impersonating a legitimate service (e.g., via certificate spoofing) to intercept sensitive data or disrupt communication. Alternatively, it could indicate a misconfiguration on the server side where certificates do not match the expected hostnames.

#. **Potential Causes:**
  1. Man-in-the-middle (MitM) attacks using certificate spoofing or certificate authority (CA) compromise.
  2. Incorrectly issued or renewed server certificates not matching the expected hostnames.
  3. Misconfigured load balancers or proxy servers causing certificate mismatch.

#. **Recommended Actions:**
  1. Verify server certificates and ensure they match the intended hostnames. Renew or update them if necessary.
  2. Investigate potential MitM attacks by examining network traffic for unusual behavior, such as unexpected intermediate certificates or unauthorized proxies.
  3. Monitor certificate revocation lists (CRLs) and Certificate Transparency logs to detect compromised or tampered certificates.

#. **Additional Notes:**
This alert is particularly significant in environments where strict certificate validation policies are enforced. It should be investigated promptly due to the potential severity of MitM attacks targeting sensitive data or critical systems.

.. _Risk 025:

TLS UNSAFE CIPHER
=================

#. **Description:**
This alert triggers when deep packet inspection detects Transport Layer Security (TLS) connections using weak or deprecated cipher suites that do not meet current security standards.

#. **Implied Security Risk:**
Detecting tls_unsafe_ciphers  alerts indicates potential man-in-the-middle attacks, data interception, and unauthorized access to sensitive information being transmitted over the network. Weak cipher suites can be exploited by attackers due to their lower encryption strengths or known vulnerabilities.

#. **Potential Causes:**
  1. Outdated client software that supports only weak cipher suites.
  2. Misconfiguration of servers, allowing connections with weak ciphers.
  3. Intentional use of weak cipher suites for compatibility purposes in legacy systems.

#. **Recommended Actions:**
  1. Identify and upgrade/downgrade clients supporting weak cipher suites to newer versions that support strong cipher suites like AES-GCM or ChaCha20-Poly1305.
  2. Review server configurations to disallow connections using weak cipher suites.
  3. Monitor network traffic regularly for `tls_unsafe_ciphers` alerts and investigate any recurring occurrences.

#. **Additional Notes:**
- Severity level: Medium to High
- Frequency of occurrence: Moderate to High in environments with legacy systems and software
- This alert is particularly significant in financial institutions, e-commerce websites, and other organizations handling sensitive data.

.. _Risk 027:

WEB MINING
============

#. **Description:**
This alert triggers when a device on the network engages in crypto mining activities

#. **Implied Security Risk:**
Web mining can lead to unauthorized access of user data, privacy violations, and potentially enable targeted phishing attacks against individuals within the monitored network. It may also indicate the presence of malicious insiders or compromised devices used for illicit crypto mining and resource harvesting.

#. **Potential Causes:**
  1. Unauthorized use of hardware resources for personal financial gain.
  2. Compromised devices infected with malware that mines crypto currencies.
  3. Compromised devices infected with malware used by C2

#. **Recommended Actions:**
  1. Investigate the source device and user to determine if unauthorized activities are taking place.
  2. Consider deploying web content filtering solutions to block known malicious URLs used for mining.

#. **Additional Notes:**
- **Frequency:** Medium to low frequency, depending on the specific environment and user behavior.
- **Severity:** Medium. While not immediately critical, unauthorized web mining could lead to significant resources utilizationover time.
- **Significance:** Particularly relevant in environments with strict data protection regulations.

.. _Risk 028:

TLS SELF SIGNED CERTIFICATE
===========================

#. **Description:**
This alert is triggered when a TLS/SSL certificate presented by a server during a handshake is self-signed, indicating it was not issued by a trusted Certificate Authority (CA).

#. **Implied Security Risk:**
Detecting this alert may indicate that an unauthorized or untrusted service is running on the network, potentially exposing sensitive data to eavesdropping or manipulation. It could also suggest the presence of malware or a man-in-the-middle attack.

#. **Potential Causes:**
  1. Misconfigured or unauthorized service running on the network, presenting its own certificate instead of one issued by a trusted CA.
  2. Man-in-the-middle attack using a self-signed certificate to intercept communication between clients and legitimate servers.
  3. Malware or malicious software attempting to masquerade as a trusted service.

#. **Recommended Actions:**
  1. Investigate the source IP address and port number associated with the self-signed certificate to identify the unauthorized service or potential threat.
  2. Verify that all services running on the network are configured correctly and present valid certificates issued by trusted CAs.
  3. Consider deploying network security solutions like certificate pinning or public key infrastructure (PKI) enforcement to prevent man-in-the-middle attacks.

#. **Additional Notes:**
- This alert is considered high severity as it may indicate significant security risks on the network.
- It is particularly significant in environments where strict certificate validation policies are enforced.

.. _Risk 029:

BINARY APPLICATION TRANSFER
===========================

#. **Description:**
This alert triggers when an unencrypted transfer happens on the monitoried network.

#. **Implied Security Risk:**
Detecting this alert could indicate the presence of advanced persistent threats (APTs), malware, or other malicious activities attempting to evade detection by hiding in legitimate application traffic. It may also suggest that an attacker is exfiltrating sensitive data from the network. Another possibility is a misconfigured web server with old serving engines which lack encryption.

#. **Potential Causes:**
  1. Exfiltration: Unauthorized transfer of sensitive data from the network, such as stolen credentials, proprietary information, or personal data.
  2. Legitimate binary transfers: While rare, some legitimate applications may trigger this alert due to their nature (e.g., file-sharing application or legacy applications which lack encrypted transfers).

#. **Recommended Actions:**
  1. Isolate and analyze the affected hosts to identify any malicious processes or unusual activity.
  2. Investigate the application(s) involved in the transfer to determine if they are legitimate and properly configured, or if they have been compromised.
  3. Review firewall and intrusion prevention system (IPS) logs for related alerts or suspicious traffic.

#. **Additional Notes:**
This alert is typically considered high severity in environments with strict data loss prevention (DLP) policies, such as finance, healthcare, or government networks.


.. _Risk 030:

KNOWN PROTOCOL ON NON STANDARD PORT
===================================

#. **Description:**
This alert triggers when a known protocol is detected using an uncommon or non-standard port number.

#. **Implied Security Risk:**
The use of non-standard ports for well-known protocols may indicate attempts to evade security measures, hide malicious activity, or facilitate unauthorized communication channels within the network. It could potentially expose hidden backdoors, command and control (C2) traffic, or data exfiltration activities.

#. **Potential Causes:**
  1. Misconfiguration or experimental testing by internal users. In this case the event is not relevant and can be silenced. 
  2. Malicious activity attempting to evade security controls by using non-standard ports for covert communication.
  3. Internal applications or services running on non-standard ports due to port conflicts or explicit configuration. In this case the event is not relevant and can be silenced if the network administrator are sure regarding the service running. 

#. **Recommended Actions:**
  1. Investigate the purpose and origin of the observed traffic to determine if it is legitimate or malicious.
  2. Review network configuration and access logs to identify any unauthorized changes or activities related to the detected ports.
  3. Consider implementing stricter port controls or application layer filtering rules to prevent unwanted traffic on non-standard ports.

#. **Additional Notes:**
- This alert is particularly significant in network environments where strict security policies are enforced, as it can help uncover potential evasion attempts or misconfigurations.
- The severity level of this alert may vary depending on the specific well-known protocol and port combination detected.

.. _Risk 031:

INVALID SOURCE IP
=================

#. **Description:**
This alert is triggered when a device sends network traffic with an invalid or reserved IP address as the source IP, indicating potential spoofing attempts or misconfigured devices.

#. **Implied Security Risk:**
Detecting this alert may indicate IP address spoofing, allowing attackers to hide their true origin and launch denial-of-service (DoS) attacks or perform unauthorized activities within the network. It could also signify misconfiguration of devices, leading to unwanted traffic and potential vulnerabilities.

#. **Potential Causes:**
  1. IP spoofing attempts by attackers to hide their true origin and bypass security measures.
  2. Misconfigured devices sending traffic with incorrect or reserved IP addresses.
  3. Network misconfigurations leading to overlapping or conflicting IP address assignments.

#. **Recommended Actions:**
  1. Investigate the device(s) using the invalid source IP addresses to determine if it's a configuration error or malicious activity.
  2. Check for any unusual traffic patterns associated with the invalid IP addresses and block them if necessary.
  3. Implement ingress/egress filtering on network edges to prevent IP spoofing attempts.

#. **Additional Notes:**
This alert is considered high severity due to the potential security risks associated with IP address spoofing. It may occur frequently in networks with misconfigured devices or inadequate ingress/egress filtering.

.. _Risk 032:

UNEXPECTED DHCP SERVER
======================

#. **Description:**
This alert triggers when an unexpected DHCP server is detected on the network, i.e., a DHCP server other than those configured in the system's trusted DHCP servers list.

#. **Implied Security Risk:**
Detecting this alert may indicate a rogue DHCP server operating on the network, which could lead to unauthorized IP address assignments, man-in-the-middle attacks, or denial-of-service conditions. Unauthorized DHCP servers can also facilitate unauthorized devices joining the network undetected.

#. **Potential Causes:**
  1. A misconfigured or unauthorized DHCP server has been introduced onto the network. .Please configure the list of expected DHCP servers
  2. Someone is attempting to spoof DHCP packets to redirect network traffic.
  3. A buggy DHCP client software is acting as a rogue server.

#. **Recommended Actions:**
  1. Investigate and locate the source of the unexpected DHCP traffic, and determine if it's authorized or not.
  2. Update the trusted DHCP servers list in the system's configuration to include any newly identified legitimate servers.
  3. Implement stricter network access controls to prevent unauthorized devices from introducing rogue services.

#. **Additional Notes:**
- High severity alert due to its potential impact on network integrity and security.
- This alert is particularly significant in networks with strict access controls or highly sensitive data.
- Frequency of occurrence may vary depending on the network's size, complexity, and security measures in place.

.. _Risk 033:

UNEXPECTED DNS SERVER
=====================

#. **Description:**
This alert triggers when a client sends DNS queries to an IP address other than its configured DNS server(s), indicating potential misconfiguration or suspicious activity.

#. **Implied Security Risk:**
Detecting this alert may indicate that the client is attempting to bypass standard DNS resolution, potentially for malware communication or data exfiltration purposes. It could also signify a misconfigured network setting, leaving the client vulnerable to DNS hijacking attacks.

#. **Potential Causes:**
  1. Malware infection: The client may be infected with malware that changes its DNS settings for command-and-control communication.
  2. Misconfiguration: The client's network configuration might have been inadvertently changed, causing it to use an incorrect DNS server. Please configure the list of expected DHCP servers
  3. Internal DNS hijacking: An attacker on the same network could be intercepting and altering DNS queries.

#. **Recommended Actions:**
  1. Investigate the client's network configuration for signs of tampering or misconfiguration.
  2. Check for malware infection using up-to-date antivirus software.
  3. Analyze network traffic around the affected client for any unusual patterns or outliers that might indicate an internal attack.
  4. Monitor DNS queries globally on your network to identify potential hijacking attempts.

#. **Additional Notes:**
- This alert is particularly significant in networks with strict security policies and limited outbound traffic.
- The frequency of occurrence depends on the specific network environment; it may be rare under normal conditions but could spike during malware outbreaks.

.. _Risk 034:

UNEXPECTED SMTP SERVER
======================

#. **Description:**
This alert triggers when a client communicates with an IP address other than its configured SMTP server(s), indicating potential misconfiguration or suspicious activity.

#. **Implied Security Risk:**
Detecting this alert may indicate that the SMTP server is not a know SMTP server due to improper configuration or it being targeted by malicious actors attempting to disrupt mail services.

#. **Potential Causes:**
  1. Misconfigured SMTP server software causing unexpected responses.
  2. Malware infection on the mail server resulting in anomalous behavior.
  3. Attempts by threat actors to exploit vulnerabilities or disrupt services.
  4. False positive due to the IP address not being configured as expected SMTP server

#. **Recommended Actions:**
  1. Investigate the affected SMTP server's configuration and logs for signs of misconfiguration or compromise.
  2. If no apparent issues are found, consider restricting network access to the SMTP server to minimize potential threats.
  3. Monitor traffic patterns around the SMTP server to detect any suspicious activity following an unexpected response.

#. **Additional Notes:**
  - Critical in enterprise networks with centralized SMTP servers and service providers offering email hosting.

.. _Risk 035:

UNEXPECTED NTP SERVER
=====================

#. **Description:**
This alert triggers when a device on your monitored network communicates with an NTP server that is not part of your predefined trusted NTP server list.

#. **Implied Security Risk:**
Detecting this alert may indicate potential DNS poisoning or man-in-the-middle attacks, where an attacker has spoofed legitimate NTP servers to disrupt time synchronization and compromise network security. It could also suggest unauthorized use of external NTP services for evading internal restrictions or data exfiltration.

#. **Potential Causes:**
  1. Malicious activity: Attackers may be attempting DNS poisoning or man-in-the-middle attacks.
  2. Misconfiguration: A device may have been incorrectly configured with an untrusted NTP server. 
  3. Software updates: Recent software changes might have introduced new, unknown dependencies on external NTP servers which is not present in the configured values of expected NTP servers

#. **Recommended Actions:**
  1. Investigate the unknown NTP server to determine its legitimacy and potential security implications.
  2. If deemed malicious or unauthorized, block further communication with that server using your network's firewalls or access controls.
  3. Update your trusted NTP server list to include any legitimate new dependencies.

.. _Risk 036:

ZERO TCP WINDOW
===============

#. **Description:**
This alert is triggered when a TCP connection has a window size of zero, indicating that no data can be sent or received by either endpoint.

#. **Implied Security Risk:**
A persistent zero window condition may suggest a denial-of-service attack, where an adversary exhausts resources by opening numerous idle connections, or it could indicate a misconfiguration issue leading to network instability and performance degradation.

#. **Potential Causes:**
  - Denial-of-service attack using idle connections ("SYN flood")
  - Network congestion or high load causing temporary resource exhaustion

#. **Recommended Actions:**
  1. Analyze the affected hosts and applications to identify any abnormal behavior, such as sudden spikes in connection attempts.
  2. Inspect firewall and intrusion detection system logs for related alerts indicating suspicious activity.
  3. Investigate potential software misconfigurations that could cause excessive TCP connections.

#. **Additional Notes:**
- **Frequency of occurrence:** This alert may occur infrequently but can become significant during peak hours or under heavy load.
- **Severity level:** Medium. While not indicative of a critical threat, persistent zero window conditions can lead to network instability and performance issues.

.. _Risk 037:

IEC INVALID TRANSITION
======================

#. **Description:**
This alert triggers when there's an unexpected transition between states in devices adhering to the International Electrotechnical Commission (IEC) protocol standards, such as IEC 62351 used in power line communication networks.

#. **Implied Security Risk:**
Detection of this alert may indicate potential attacks exploiting vulnerabilities like state machine bypass or unauthorized access attempts, posing risks like data tampering, command injection, or denial-of-service conditions within the affected network segments.

#. **Potential Causes:**
1. Malicious manipulation of IEC devices to bypass security checks.
2. Compatibility issues between different IEC-compliant implementations.
3. Misconfigured network equipment leading to unintended state transitions.

#. **Recommended Actions:**
1. Thoroughly investigate the source IP address and device ID triggering the alert for signs of unauthorized access or malicious activity.
2. Review the firmware versions and configurations of affected devices, ensuring they are up-to-date and properly secured.
3. Implement strict access controls and network segmentation to prevent unauthorized communication between IEC devices.

#. **Additional Notes:**
This alert is more likely to occur in power line communication networks with a mix of different vendors' implementations. Regular network monitoring and updating firmware can help mitigate potential risks associated with this alert.

.. _Risk 038:

REMOTE TO LOCAL INSECURE PROTO
==============================

#. **Description:**
This alert triggers when insecure protocols are used in remote-to-local communication patterns.

#. **Implied Security Risk:**
Detecting this alert may indicate potential data interception or unauthorized access to sensitive information. It could also suggest misconfiguration or ignorance of best security practices within the monitored network.

#. **Technical Details:**
  - Source IP address is not local to the monitored network.
  - Destination port corresponds to an insecure protocol.

#. **Potential Causes:**
  1. Misconfigured client software using insecure protocols for remote access.
  2. Legacy systems that rely on outdated, unencrypted communication methods.
  3. Malicious activity attempting to intercept sensitive information.

#. **Recommended Actions:**
  1. Identify and migrate any uses of insecure protocols to secure alternatives (e.g., SSH instead of Telnet).
  2. Implement strong authentication measures and encrypt data in transit.
  3. Regularly review and update network access policies to enforce best security practices.

#. **Additional Notes:**
- This alert has a HIGH severity level as it directly impacts the confidentiality of transmitted data.
- It is particularly significant in environments where sensitive information (e.g., financial, healthcare) is handled or transferred.

.. _Risk 055:

IEC UNEXPECTED TYPE ID
======================

#. **Description:**
This alert triggers when an unexpected type identifier (type ID) is encountered in an Industrial Ethernet Communication (IEC) protocol data unit (PDU), indicating a potential deviation from standard or configured behaviors.

#. **Implied Security Risk:**
Detecting this alert could indicate misconfigured or malicious devices attempting to communicate using unrecognized or unauthorized types, posing risks such as unauthorized access, command injection, or disruption of industrial control systems.

#. **Potential Causes:**
  1. Misconfiguration: Incorrect configuration of devices resulted in transmission of unknown type IDs.
  2. Malicious activity: An attacker attempting to exploit unknown types for unauthorized access or command injection.
  3. Device malfunction: A faulty device transmitting incorrect type IDs due to hardware or software issues.

#. **Recommended Actions:**
  1. Identify and investigate the source device(s) transmitting unexpected type IDs.
  2. Verify the configuration of identified devices; update or reconfigure if necessary.


#. **Additional Notes:**
- This alert is significant in industrial control networks where unauthorized access can result in severe consequences.
- Severity level: Medium to High, based on the potential impact on industrial control systems.

.. _Risk 056:

TCP NO DATA EXCHANGED
=====================

#. **Description:**
This alert triggers when a TCP connection remains idle for an extended period without exchanging any data, indicating potential reconnaissance or dormant malicious activity.

#. **Implied Security Risk:**
Prolonged inactive TCP connections may suggest network scanning or probing activities by potential attackers attempting to gather information about the target environment. Additionally, such connections could be used as a backdoor into the network for future unauthorized access attempts.

#. **Potential Causes:**
  1. Network scanning: Attackers may open idle connections to enumerate targets and map out network services.
  2. Dormant malware: Malicious software could maintain dormant TCP connections awaiting commands from a C&C server.
  3. Misconfigured systems: Some systems might have persistent TCP connections configured incorrectly, leading to unnecessary idle connections.

#. **Recommended Actions:**
  1. Investigate the source and destination IP addresses of the idle connection to identify any suspicious activities or misconfigured systems.
  2. Implement a time-out policy for TCP connections to automatically close inactive connections after a specified duration.
  3. Monitor network traffic for sudden spikes in idle TCP connections, which may indicate scanning activities.

#. **Additional Notes:**
- The frequency of this alert depends on the network's normal activity level and idle connection threshold settings. Adjusting these thresholds may help reduce false positives.
- In high-traffic networks with many legitimate idle connections, this alert might have a higher severity level due to increased potential for malicious activities hiding among normal traffic.

.. _Risk 057:

REMOTE ACCESS
=============

#. **Description:**
This alert triggers when the source IP address initiates Remote Desktop Protocol (RDP) connections to destination IP addresses, potentially indicating unauthorized access attempts or brute-force attacks such as scanning.

#. **Implied Security Risk:**
Detecting this alert may suggest that the network is under attack by threat actors attempting to gain unauthorized remote access to devices, leading to potential data breaches, lateral movement of attackers within the network, or establishment of persistent backdoors.

#. **Potential Causes:**
  1. Brute-force attacks targeting weak or default Remote Desktop credentials
  2. Unauthorized access attempts by insider threats or external attackers with stolen credentials
  3. Malware infections attempting to establish remote command and control (C&C) communication

#. **Recommended Actions:**
  1. Investigate the device(s) involved in the alert and review their network connections before and after the event.
  2. Temporarily restrict RDP access from external sources until further investigation is complete, and consider implementing multi-factor authentication (MFA) to enhance security.
  3. Review and strengthen Remote Desktop credentials across the network, ensuring they meet complexity requirements and are not based on default values.

.. _Risk 058:

LATERAL MOVEMENT
================

#. **Description:**
This alert triggers when there's evidence of unauthorized movement of data or credentials between devices within a network segment, suggesting potential internal threat propagation.

#. **Implied Security Risk:**
Detecting this alert may indicate that an entity is moving laterally to escalate privileges or spread malware, posing significant threats to the network's confidentiality and integrity.

#. **Potential Causes:**
  1. Malware infection propagating through the network.
  2. Insider threat moving laterally to escalate privileges or access sensitive data.
  3. Misconfigured systems or software vulnerabilities allowing unauthorized access.

#. **Recommended Actions:**
  1. Isolate affected devices and perform a thorough scan for malware infections.
  2. Review user accounts and permissions to identify any anomalies or unauthorized access.
  3. Implement strict access controls, consider using the principle of least privilege (PoLP), and keep all systems and software patched up-to-date.

#. **Additional Notes:**
- This alert is particularly significant in environments with high user mobility or Bring Your Own Device (BYOD) policies.
- Severity level: High

.. _Risk 059:

PERIODICITY CHANGED
===================

#. **Description:**
This alert triggers when there's a change in the periodicity of specific flows.

#. **Implied Security Risk:**
An abrupt change in periodicity could signify a man-in-the-middle attack, a denial-of-service attack, or an attacker attempting to evade detection by varying their traffic patterns. It may also indicate unexpected network congestion or hardware failures.

#. **Potential Causes:**
  1. Man-in-the-middle attacks: An attacker may interleave packets to disrupt communication.
  2. Denial-of-service attacks: An attacker might flood the network with irregular traffic to cause congestion or disruption.
  3. Traffic evasion techniques: An attacker could vary packet intervals to avoid detection by signature-based intrusion prevention systems.

#. **Recommended Actions:**
  1. Investigate the host(s) involved for any suspicious activity or unauthorized access attempts.
  2. Review network infrastructure health, as hardware failures or misconfigurations may cause unexpected traffic patterns.

#. **Additional Notes:**
- This alert is typically low to medium severity, depending on the configured thresholds and the network environment.
- It's particularly significant in networks with strict quality-of-service (QoS) requirements, where even small deviations in packet interval can cause noticeable impacts.

.. _Risk 067:

BROADCAST NON UDP TRAFFIC
=========================

#. **Description:**
This alert triggers when non-UDP traffic is detected on a broadcast IP address, which deviates from standard network protocols and could indicate malicious activity.

#. **Implied Security Risk:**
Detecting this alert may indicate the presence of unauthorized network scanning tools or worms exploiting network vulnerabilities by using non-UDP traffic over broadcasts, potentially leading to unauthorized access attempts or data compromise.

#. **Potential Causes:**
  1. Unauthorized network scanning tools probing for vulnerable hosts.
  2. Worm or malware propagation exploiting vulnerable systems on the broadcast IP address.
  3. Misconfigured network devices accidentally broadcasting non-UDP traffic.

#. **Recommended Actions:**
  1. Identify and isolate affected systems to contain any potential infection or unauthorized access attempts.
  2. Investigate source of non-UDP broadcast traffic, including checking for misconfigurations in network devices or protocols.
  3. Implement strict egress filtering to prevent unwanted outbound traffic on broadcast IP addresses.

#. **Additional Notes:**
- This alert is particularly significant in environments with strict network access controls or where worm propagation risks are high. It has a severity level of MEDIUM to HIGH, depending on the frequency and scope of detected incidents.

.. _Risk 074:

IEC INVALID COMMAND TRANSITION
==============================

#. **Description:**
This alert triggers when a device on the network performs an invalid or out-of-sequence command transition according to the International Electrotechnical Commission (IEC) protocol standards.

#. **Implied Security Risk:**
Detecting this alert may indicate misconfiguration or malfunction of devices, potentially leading to unexpected behavior or vulnerabilities that could be exploited by attackers. It might also suggest a compromised device attempting to issue unauthorized commands.

#. **Potential Causes:**
  1. Misconfigured devices sending commands out of sequence.
  2. Attempted unauthorized access by malicious actors exploiting software vulnerabilities.
  3. Malware or viruses manipulating network traffic to trigger false alerts.

#. **Recommended Actions:**
  1. Investigate the affected device(s) and review their configuration settings.
  2. Implement strict access controls to prevent unauthorized command transitions.
  3. Consider upgrading or patching vulnerable devices to protect against known exploits.

#. **Additional Notes:**
- This alert is particularly significant in industrial control systems (ICS) and critical infrastructure networks where IEC protocols are commonly used.


.. _Risk 075:

CONNECTION FAILED
=================

#. **Description:**
This alert triggers when deep packet inspection detects a failure in establishing a TCP connection.

#. **Implied Security Risk:**
Detecting connection_failed alerts could indicate potential Denial of Service (DoS) attacks, misconfiguration issues, or network instability that might allow adversaries to exploit these failures for further attacks.

#. **Potential Causes:**
  1. Resource exhaustion attacks (e.g., SYN flood)
  2. Network congestion or latency issues
  3. Remote host unreachable due to firewall rules, routing issues, or target offline

#. **Recommended Actions:**
  1. Investigate the source and destination of failed connections for unusual patterns or suspicious activity.
  2. Check network infrastructure for signs of resource exhaustion, congestion, or misconfiguration.
  3. Implement rate-limiting mechanisms to mitigate SYN flood attacks.

#. **Additional Notes:**
- Severity level: Medium low, depending on the cause and frequency of occurrences
- Significant environments: Web servers, VPN gateways, and other network services with high connection rates

.. _Risk 077:

UNIDIRECTIONAL TRAFFIC
======================

#. **Description:**
This alert triggers when there's one-way traffic between source IP address and destination IP address, indicating potential disservices if the destionation IP address is not responding (service down), possible communication limiting such as firewall that prevents responses or simply the service being off.

#. **Implied Security Risk:**
Unidirectional traffic could indicate an infected host acting as a bot, communicating with its command and control server but not receiving any response due to blocking or tampering. This could also signify data exfiltration where only outgoing traffic is permitted.

#. **Potential Causes:**
  1. Botnet communication where infected hosts receive commands but don't respond due to network restrictions or command & control server tampering.
  2. Data exfiltration where an attacker sends data out but doesn't receive any response from the external server.
  3. Misconfigured or compromised load balancers or firewalls causing unidirectional traffic.

#. **Recommended Actions:**
  1. Investigate the source of the unidirectional traffic to identify potentially infected hosts.
  2. Check if there's a known legitimate cause for the one-way communication, such as a specific application's behavior.
  3. Inspect firewall rules and other network policies to ensure they're not inadvertently blocking responses.

#. **Additional Notes:**
- This alert is particularly significant in enterprise networks with strict firewall rules or in environments where botnet activity is prevalent.
- The severity level of this alert depends on the threshold set for unidirectional traffic and the duration over which it occurs.

.. _Risk 087:

CUSTOM LUA Script
=================

#. **Description:**
This alert triggers when a custom Lua script generates an alert based on a user custom alert definition.

#. **Implied Security Risk:**
Depends on the lua script content

#. **Potential Causes:**
  1. Depends on what the lua script is designed to trigger alerts on

#. **Recommended Actions:**
  1. Depends on what the lua script is designed to trigger alerts on

.. _Risk 091:

VLAN BIDIRECTIONAL TRAFFIC
==========================

#. **Description:**
This alert triggers when bi-directional traffic is detected within a single VLAN, indicating potential spanning tree loop or misconfiguration issues.

#. **Implied Security Risk:**
Bi-directional traffic in a VLAN may suggest loops or improper configuration, leading to broadcast storms and increased susceptibility to Denial of Service (DoS) attacks. It could also indicate an attacker manipulating the network topology for malicious purposes.

#. **Potential Causes:**
  1. Misconfigured STP or RSTP settings, leading to loops.
  2. Physical layer issues such as cross-over cables or hubs connected to switches.
  3. Manipulation of network topology by an attacker for illicit activities like DoS attacks.

#. **Recommended Actions:**
  1. Investigate and rectify any potential spanning tree loops using tools like `show spanning-tree interface` (Cisco) or check STP/RSTP configuration for inconsistencies.
  2. Monitor traffic patterns and inspect physical cabling to ensure correct connections and detect anomalies.
  3. Implement port security measures to prevent unauthorized MAC address changes.


#. **Additional Notes:**
- This alert is particularly significant in environments with high VLAN segmentation, as it can help identify potential misconfigurations or attacks targeting specific broadcast domains.

.. _Risk 092:

RARE DESTINATION
================

#. **Description:**
This alert triggers when a monitored device communicates with a destination IP address which is not frequent in the monitored network.

#. **Implied Security Risk:**
Detecting this alert may suggest that the source IP address communicated with a new destination IP address, suggesting a behaviour change.

#. **Potential Causes:**
  1. Internal threat: Compromised devices or malware communicating with a new destination IP address which is rare in the context of the monitored network.
  2. Brute-force attack: External attackers scanning the network for vulnerabilities or weak points.
  3. Misconfigured applications: Legitimate applications incorrectly configured to connect excessively to external destinations.

#. **Recommended Actions:**
  ....

#. **Additional Notes:**
This alert is designed to be rare, hence its name; therefore, false positives are less likely. However, network administrators should still validate alerts with low occurrence rates before taking action. This alert has a severity level of high and is particularly significant in environments with tight security controls or critical systems.

.. _Risk 093:

MODBUS UNEXPECTED FUNCTION CODE
===============================

#. **Description:**
This alert triggers when a MODBUS message contains an unexpected function code, indicating either a protocol error or potentially malicious activity.

#. **Implied Security Risk:**
Detecting this alert may suggest a configuration error, misbehaving device, or a sophisticated attack attempting to exploit unknown or undocumented MODBUS functionality. It could allow unauthorized data access or manipulation, leading to system compromise or disruption of service availability.

#. **Potential Causes:**
  1. Misconfigured MODBUS device sending invalid messages.
  2. Attempted exploit of undocumented MODBUS functionality by a malicious actor.
  3. Software bug or implementation error in MODBUS client/server.

#. **Recommended Actions:**
  1. Identify and isolate the source device(s) generating unexpected function codes.
  2. Investigate and validate the configuration and software version of the offending device(s).
  3. Review MODBUS message logs for any suspicious patterns or repeated occurrences of this alert.
  4. Consider implementing access control lists (ACLs) to restrict MODBUS traffic to trusted sources and destinations.


#. **Additional Notes:**
- This alert is particularly significant in industrial networks, building automation systems, and other environments where MODBUS devices are prevalent.
- Frequency of occurrence may vary depending on the network's size and complexity.

.. _Risk 094:

MODBUS TOO MANY EXCEPTIONS
========================

#. **Description:**
This alert is triggered when an excessive number of Modbus exceptions are observed within a short time frame, indicating potential communication issues or malicious activity.

#. **Implied Security Risk:**
A high frequency of Modbus exceptions may suggest either misconfiguration or tampering attempts targeting Modbus-enabled devices. Prolonged abnormal behavior could lead to device malfunction or unauthorized access to sensitive data.

#. **Potential Causes:**
  1. Device malfunction or misconfiguration causing frequent errors.
  2. Denial-of-service (DoS) attacks targeting Modbus devices to disrupt operations.
  3. Malicious attempts to exploit vulnerabilities via exception-based attacks.

#. **Recommended Actions:**
  1. Investigate the source of excessive exceptions and address any device configuration issues promptly.
  2. Implement intrusion detection/prevention mechanisms to safeguard against DoS attacks or unauthorized access.
  3. Monitor Modbus devices for unusual behavior patterns indicative of potential threats.

#. **Additional Notes:**
This alert is particularly significant in industrial control systems (ICS) and supervisory control and data acquisition (SCADA) environments where Modbus is prevalent. It has a severity level of MEDIUM, as frequent exceptions may indicate ongoing issues but are not necessarily immediately critical.

.. _Risk 095:

MODBUS INVALID TRANSITION
=========================

#. **Description:**
This alert triggers when an invalid transition in a Modbus Protocol Data Unit (PDU), indicating potential protocol violations or malformed packets.

#. **Implied Security Risk:**
Detecting modbus_invalid_transition alerts may suggest network reconnaissance activities, protocol attacks such as replay or spoofing attempts, or misconfigured devices introducing instability and vulnerabilities into the monitored network.

#. **Potential Causes:**
  1. Misconfiguration errors in Modbus devices leading to incorrect message structures.
  2. Protocol attacks such as replay attacks or spoofing attempts targeting Modbus networks.
  3. Unpatched vulnerabilities or software bugs in Modbus implementations causing unexpected behavior.

#. **Recommended Actions:**
  1. Verify the integrity of Modbus messages by inspecting the function codes, sub-function codes, and PDU lengths for compliance with RFC 6418 standards.
  2. Isolate affected devices or networks pending further investigation and apply necessary patches or firmware updates to address potential vulnerabilities.
  3. Implement protocol filtering and intrusion prevention mechanisms on network perimeter devices to protect against Modbus-specific attacks.

#. **Additional Notes:**
This alert is particularly significant in Industrial Control Systems (ICS) and Supervisory Control and Data Acquisition (SCADA) environments where Modbus protocols are widely used. Frequent occurrences of this alert may warrant closer scrutiny for signs of targeted attacks or widespread misconfigurations.

.. _Risk 100:

TCP FLOW RESET
==============

#. **Description:**
This alert triggers when a TCP connection is abruptly terminated by the peer without completing the standard closure sequence, indicating an unexpected disconnection or possible denial-of-service attack.

#. **Implied Security Risk:**
Detecting this alert may suggest potential Distributed Denial of Service (DDoS) attacks using state exhaustion techniques, or unauthorized network scanning activities targeting vulnerable TCP services.

#. **Potential Causes:**
  1. Distributed Denial of Service (DDoS) attacks targeting TCP services to exhaust resources and degrade performance.
  2. Unauthorized network scanning activities or probes attempting to identify open ports and vulnerable services.
  3. Software bugs or misconfigurations causing unintended abrupt disconnections.

#. **Recommended Actions:**
  1. Investigate the source IP address(es) associated with the reset packets to identify potential malicious activity or misconfigured devices.
  2. Check for any ongoing DDoS attacks targeting TCP services on your network and implement appropriate countermeasures.

#. **Additional Notes:**
This alert is more relevant in networks with high volumes of TCP traffic or where TCP-based services are exposed to the internet. Regular monitoring and thresholding can help identify abnormal reset patterns indicative of potential attacks. The severity level of this alert is typically considered MEDIUM.

.. _Risk 102:

ACCESS CONTROL LIST
===================

#. **Description:**
This alert is triggered whenever a network flow violates the specified ACL policy defined under Settings -> Network Configuration

#. **Potential Causes:**
Detecting this alert may suggest a potential host misbehaviour, misconfiguration or security problem.

#. **Recommended Actions:**
Check if the configured policy is properly configured, or if the host that triggered the alerted host is misconfigured or it has been infected by some malware.


.. _Risk 103:

HOST POLICY
===========

#. **Description:**
This alert is triggered whenever a network flow violates the specified policy defined under Settings -> Network Configuration -> Policies

#. **Potential Causes:**
Detecting this alert may suggest a potential host misbehaviour, misconfiguration or security problem.

#. **Recommended Actions:**
Check if the configured policy is properly configured, or if the host that triggered the alerted host is misconfigured or it has been infected by some malware. Typically these issues might also be caused by network devices that perform unexpected activites (e.g. silent softwrae updates): if acceptable, the contacted hosts need to be added to the whitelisted hosts list (see the host policy configuration).

