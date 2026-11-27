---
title: "Remediations for nDPI Risks"
description: "Remediations for nDPI Risks in the ntopng User's Guide."
outline: [2, 3]
lastUpdated: 2026-05-16T10:05:32+02:00
---
# Remediations for nDPI Risks {#remediations-for-ndpi-risks}


<a id="risk-001"></a>

## POSSIBLE XSS {#possible-xss}

1. **Description**: A URL pattern suggesting a potential Cross-Site Scripting (XSS) vulnerability.
2. **Possible attacks**: he detection of this risk indicates that malicious JavaScript code could be embedded within a URL, posing a threat to users' security and integrity when they access the affected resource.
3. **Remediation**: Upon detection, it is recommended to:

> 1. Validate all user inputs for possible XSS vulnerabilities, especially URL parameters.
> 2. Sanitize any user-supplied data before rendering it in HTML or JavaScript contexts.
> 3. Ensure that your application's security policies and frameworks are up-to-date to protect against known XSS attack vectors.
> 4. Monitor the network for other signs of compromise related to potential XSS attacks, such as unusual traffic patterns or user behavior changes.
> 5. Educate users about the risks of clicking untrusted links and the importance of security best practices.


<a id="risk-002"></a>

## POSSIBLE SQL INJECTION {#possible-sql-injection}

1. **Description**: Detection of a URL pattern that potentially contains SQL injection vulnerabilities in the monitored network's web traffic.
2. **Possible attacks**: The presence of this risk indicates an attempt to inject malicious SQL commands into a database by manipulating input parameters via the URL, which could result in unauthorized access or data modification.
3. **Remediation**: Upon detection of this risk, it is recommended to perform the following actions:

> 1. Block further requests containing the suspicious URL pattern to prevent potential exploitation.
> 2. Investigate the source and destination of the traffic, as well as any associated user accounts or systems.
> 3. Implement input validation on all web-based forms that accept user inputs to help prevent SQL injection attacks.
> 4. Ensure that web applications are up-to-date with the latest security patches to minimize known vulnerabilities.
> 5. Regularly audit and monitor for changes in traffic patterns or suspicious activity related to this risk.


<a id="risk-003"></a>

## POSSIBLE REMOTE CODE INJECTION {#possible-remote-code-injection}

1. **Description**: Detection of a potential Remote Code Execution (RCE) injection in the URL field within network packets.
2. **Possible attacks**: This risk signals that an attacker might be attempting to exploit a vulnerability in the system, injecting malicious code into the network through a crafted URL. If successful, this could lead to unauthorized command execution and potential data breaches or network disruptions.
3. **Remediation**: Upon detection of NDPI_URL_POSSIBLE_RCE_INJECTION, immediately block the suspicious traffic and investigate its origin. Review web application firewall rules, update software patches to address known vulnerabilities, and implement strict URL input validation to prevent similar incidents in the future. Regular security audits should be conducted to ensure network security measures are up#.to#.date and effective.


<a id="risk-004"></a>

## BINARY APPLICATION TRANSFER {#binary-application-transfer}

1. **Description**: Transfer of binary application data without proper protocol encapsulation.
2. **Possible attacks**: This detection can indicate unsecured file transfers or unknown applications using custom protocols, which may be susceptible to data interception, manipulation, or malware infections.
3. **Remediation**: Implement secure communication channels for binary application transfers using industry#.standard protocols such as HTTPS, SFTP, or SCP. Additionally, investigate any unknown applications or custom protocols and assess their potential risks before allowing them on the network. Regularly update software to protect against known vulnerabilities in both applications and protocols.


<a id="risk-005"></a>

## KNOWN PROTOCOL ON NON STANDARD PORT {#known-protocol-on-non-standard-port}

1. **Description**: Known protocol detected on a non-standard port.
2. **Possible attacks**: The detection of this risk in deep packet inspection indicates unconventional network activity, which can be used for evading firewall rules, data exfiltration, or launching DDoS attacks through unexpected ports.
3. **Remediation**: When detected, review firewall configurations to ensure that known protocols are only allowed on standard ports and implement intrusion detection/prevention systems (IDS/IPS) to monitor for anomalous network traffic on non-standard ports. Additionally, consider using a whitelist approach to limit the list of accepted applications and their corresponding ports.


<a id="risk-006"></a>

## TLS SELFSIGNED CERTIFICATE {#tls-selfsigned-certificate}

1. **Description**: A self-signed TLS certificate is one that has been created and signed by the same entity responsible for the domain being secured. This can be a potential security risk as these certificates are not verified by any trusted Certificate Authority (CA).
2. **Possible attacks**: The detection of this risk in deep packet inspection signals a problem in the monitored network, as self-signed TLS certificates can allow for man-in-the-middle (MitM) attacks. Attackers can intercept and modify communications, since the certificate is not verified by a trusted third party.
3. **Remediation**: When detected, the remediation for this risk involves validating the necessity of using self-signed certificates. If they are indeed required (e.g., for internal testing purposes), implement a proper Certificate Authority (CA) and enforce its use to avoid MitM attacks. For production environments, always use trusted CA-signed certificates to ensure secure TLS communications.


<a id="risk-007"></a>

## TLS OBSOLETE VERSION {#tls-obsolete-version}

1. **Description**: Detection of an outdated Transport Layer Security (TLS) version in use, potentially exposing the monitored network to vulnerabilities.
2. **Possible attacks**: The use of obsolete TLS versions can be exploited by attackers using known vulnerabilities that have been patched in newer versions, leading to data breaches or man-in-the-middle attacks.
3. **Remediation**: To secure the monitored network when this risk is detected, it's recommended to update the TLS version to a more recent and secure one as soon as possible. This can typically be done by applying relevant security patches for the affected software or hardware components. Additionally, implementing stricter TLS protocol policies such as disabling older versions entirely can help protect against attacks leveraging obsolete TLS versions.


<a id="risk-008"></a>

## TLS WEAK CIPHER {#tls-weak-cipher}

1. **Description**: Use of weak encryption ciphers in Transport Layer Security (TLS) connections.
2. **Possible attacks**: The use of weak ciphers can make the data transmitted vulnerable to eavesdropping, man-in-the-middle attacks, or decryption by unauthorized entities.
3. **Remediation**: Update TLS libraries and configurations to disable weak encryption algorithms (such as RC4) and enforce the use of stronger, more secure ciphers (e.g., AES 128 GCM, ECDHE RSA with P-256). Regularly monitor for and apply updates to keep up with changes in security best practices and vulnerabilities discovered in encryption algorithms.


<a id="risk-009"></a>

## TLS CERTIFICATE EXPIRED {#tls-certificate-expired}

1. **Description**: A TLS certificate has expired, potentially allowing for unauthenticated connections.
2. **Possible attacks**: Detection of this risk indicates that a man-in-the-middle attack or data interception could occur due to the use of an outdated or invalid certificate. Unsecured communication could lead to sensitive data being exposed.
3. **Remediation**: Update the expired TLS certificate as soon as possible, ensuring it is issued by a trusted Certificate Authority (CA). If the certificate cannot be updated immediately, consider disabling the service that uses this expired certificate or implementing alternative secure communication methods temporarily. Additionally, monitor network traffic for any suspicious activity and investigate any potential breaches.


<a id="risk-010"></a>

## TLS CERTIFICATE MISMATCH {#tls-certificate-mismatch}

1. **Description**: A TLS certificate mismatch occurs when the server presents a different SSL/TLS certificate than expected during the TLS handshake process.
2. **Possible attacks**: The detection of this risk in deep packet inspection signals a problem in the monitored network, as it may indicate a man-in-the-middle (MitM) attack or an unintended use of self-signed certificates. In either case, data being transmitted could be intercepted and potentially modified.
3. **Remediation**: When this risk is detected, administrators should investigate the source of the TLS certificate mismatch. If it's a MitM attack, affected connections should be terminated immediately. If the issue is due to an unintended use of self-signed certificates, consider implementing proper digital certificate management and revoke the current self-signed certificate. Additionally, ensure that all clients trust the newly installed certificate or update them with the new one.


<a id="risk-011"></a>

## HTTP SUSPICIOUS USER AGENT {#http-suspicious-user-agent}

1. **Description**: Detection of an unusual or modified User Agent string in HTTP traffic
2. **Possible attacks**: Use of a custom or altered User Agent string can be indicative of bot traffic, data scraping, or other malicious activities that aim to bypass security mechanisms or evade detection.
3. **Remediation**: Monitor and analyze the source IP address associated with the suspicious traffic, and consider implementing rate limiting, access control lists (ACLs), or intrusion prevention systems (IPS) to block or restrict traffic from known malicious sources. Additionally, regularly update and maintain a comprehensive database of known good User#.Agent strings to improve detection accuracy and minimize false positives.


<a id="risk-012"></a>

## NUMERIC IP HOST {#numeric-ip-host}

1. **Description**: The detection of numeric IP addresses being used as hostnames indicates potential misconfigurations or malicious activities.
2. **Possible attacks**: Using numeric IP addresses as hostnames can bypass DNS resolution, enabling data exfiltration, phishing attacks, and other malicious activities that would otherwise be blocked by DNS filtering.
3. **Remediation**: If NDPI NUMERIC IP HOST is detected, investigate the traffic to determine if it's caused by misconfiguration or malicious activity. Correct any misconfigurations in network infrastructure such as DNS servers and firewalls. Implement strict policies for hostname usage and enforce their adherence. Monitor traffic closely for suspicious activities related to numeric IP addresses and take appropriate action when necessary, such as blocking the source of the traffic or isolating compromised systems.


<a id="risk-013"></a>

## HTTP SUSPICIOUS URL {#http-suspicious-url}

1. **Description**: Detection of HTTP traffic to suspicious URLs in the monitored network.
2. **Possible Attacks**: This risk signals potential web#.based threats such as malware downloads, phishing attempts, or unauthorized data exfiltration when users visit or interact with these URLs.
3. **Remediation**: When this risk is detected, it's recommended to:

> 1. Block access to the suspicious URLs at the network level until their legitimacy is confirmed.
> 2. Implement web filtering policies to prevent users from visiting known malicious or suspect websites.
> 3. Regularly update blacklists of known threat sources and ensure they're properly integrated into your network security measures.
> 4. Utilize intrusion prevention systems (IPS) to automatically block malicious traffic attempting to access the network via these suspicious URLs.
> 5. Educate users on the importance of safe browsing practices, such as not clicking on links from unknown sources or opening unexpected email attachments.


<a id="risk-014"></a>

## HTTP SUSPICIOUS HEADER {#http-suspicious-header}

1. **Description**: The presence of unusual or unexpected HTTP headers in a network packet.
2. **Possible Attacks**: Detection of this risk could signal unauthorized activity such as data exfiltration, malware injection, or manipulation of web traffic in the monitored network. Malicious actors may use custom or modified HTTP headers to evade detection or perform unauthorized actions.
3. **Remediation**: When detected, the network administrator should investigate the source and destination of the suspicious packet, review the content of the HTTP header, and take appropriate action based on their findings. Possible remediations include blocking the offending IP address, resetting connections, or further analyzing the traffic with a security information and event management (SIEM) system for pattern recognition and response. It's also essential to keep the deep packet inspection software up#.to#.date and configure it with appropriate rules to identify known malicious HTTP headers.


<a id="risk-015"></a>

## TLS NOT CARRYING HTTPS {#tls-not-carrying-https}

1. **Description**: Traffic using Transport Layer Security (TLS) but not carrying HTTPS. This can indicate a potential security misconfiguration.
2. **Possible Attacks**: If detected, this could signal an unencrypted HTTP traffic being sent over TLS, exposing sensitive data to eavesdropping or manipulation.
3. **Remediation**: To secure the monitored network when this risk is detected:

> 1. Validate that the application using TLS should indeed be using HTTPS and not HTTP.
> 2. Investigate and correct any misconfigurations found in the server or client#.side applications, ensuring they are configured to use HTTPS instead of TLS alone.
> 3. Implement proper security controls such as encryption and secure communications protocols to minimize data exposure risks when transmitting sensitive information over networks.
> 4. Keep systems and applications updated with the latest security patches to mitigate known vulnerabilities that could be exploited in attacks against unencrypted traffic.


<a id="risk-016"></a>

## SUSPICIOUS DGA DOMAIN {#suspicious-dga-domain}

1. **Description**: Detection of a Domain Generated Algorithm (DGA) domain indicates potential malicious activity.
2. **Possible attacks**: The detection of this risk signals the use of Domain Generation Algorithms, which are typically employed by malware to evade detection by changing its command and control (C&C) servers frequently. This could indicate a network compromise or an ongoing attack.
3. **Remediation**: When this risk is detected, it's crucial to investigate the origin of the suspicious DGA domain. Block access to the domain at network level and isolate any affected systems immediately to prevent further spread of the potential threat. Conduct a thorough analysis of the system logs to identify any additional compromised systems and perform a full system scan using trusted anti#.malware software. Additionally, consider implementing a more robust security strategy that includes real#.time threat intelligence feeds for rapid response to emerging threats.


<a id="risk-017"></a>

## MALFORMED PACKET {#malformed-packet}

1. **Description**: Packet structure does not comply with specified protocol standards.
2. **Possible attacks**: Malformed packets may hide malicious content or be part of a denial#.of#.service attack, exploiting weaknesses in the network's protocol processing.
3. **Remediation**: Validate and discard any non#.compliant packets to prevent potential security threats. Implement strict access controls, firewalls, and intrusion detection systems (IDS/IPS) to filter out suspicious traffic based on protocol violations. Regularly update software components for bug fixes related to packet processing vulnerabilities.


<a id="risk-018"></a>

## SSH OBSOLETE CLIENT VERSION OR CIPHER {#ssh-obsolete-client-version-or-cipher}

1. **Description**: Outdated SSH client version or cipher suite being used in the network connection.
2. **Possible attacks**: The detection of this risk indicates that a potentially vulnerable client software is being used, which could expose the network to brute force and dictionary attacks, man#.in#.the#.middle (MitM) attacks, and other forms of intrusion.
3. **Remediation**: To secure the monitored network when this risk is detected:

> 1. Update SSH client software to the latest version, ensuring that all patches are applied.
> 2. Review and update the configured cipher suites on the SSH server to use modern and secure algorithms.
> 3. Implement strong password policies or consider using public key authentication.
> 4. Regularly monitor and audit network traffic for any suspicious activities related to SSH connections.


<a id="risk-019"></a>

## SSH OBSOLETE SERVER VERSION OR CIPHER {#ssh-obsolete-server-version-or-cipher}

1. **Description**: Detection of an outdated SSH server version or cipher algorithm indicates potential vulnerabilities in the network security.
2. **Possible attacks**: Outdated versions and weak ciphers may expose the network to brute force, dictionary, and man#.in#.the#.middle (MITM) attacks, compromising sensitive data transmissions.
3. **Remediation**: Update SSH server software to the latest version, ensuring it addresses all known vulnerabilities. Use strong cipher algorithms such as AES#.256#.CBC or Chacha20#.Poly1305. Regularly apply security patches and configure SSH to allow only trusted key pairs for authentication. Implement network segmentation to minimize the potential damage of an attack. Monitor the SSH server for unusual activity and set up intrusion detection/prevention systems (IDS/IPS) for enhanced protection.


<a id="risk-020"></a>

## SMB INSECURE VERSION {#smb-insecure-version}

1. **Description**: Detection of an SMB protocol version with known security vulnerabilities
2. **Possible attacks**: The detection signals potential exploitation of weaknesses such as EternalBlue, which can lead to unauthorized access, data corruption, or denial of service
3. **Remediation**: Upgrade the SMB protocol to a secure version (e.g., SMBv3 with signing and encryption enabled), apply relevant security patches for the current version in use, and implement strong access controls and firewall rules to limit exposure. Regularly monitor and update network security measures to ensure continuous protection against evolving threats.


<a id="risk-021"></a>

## TLS SUSPICIOUS ESNI USAGE {#tls-suspicious-esni-usage}

1. **Description**: Usage of Encrypted Server Name Indication (ESNI) in a suspicious or unexpected manner within Transport Layer Security (TLS) connections.
2. **Possible attacks**: The detection of this risk could indicate the use of stealthy phishing attacks, man#.in#.the#.middle (MitM) attacks, or non#.compliant applications that bypass Certificate Authority (CA) checks, potentially allowing unauthorized access or data exfiltration.
3. **Remediation**: When detected, verify the legitimacy of the application or service using ESNI. Ensure all TLS connections adhere to standard practices and are properly configured. Implement security policies that limit the use of ESNI to approved applications only. Regularly update certificate authorities and revoke any outdated certificates. Monitor network traffic for anomalies related to ESNI usage and maintain a consistent security posture across the network infrastructure.


<a id="risk-022"></a>

## UNSAFE PROTOCOL {#unsafe-protocol}

1. **Description**: Detection of an unsafe protocol not explicitly authorized on the network, which may pose a security risk.
2. **Possible attacks**: The use of unapproved or unknown protocols can provide opportunities for malicious actors to bypass security controls, introduce vulnerabilities, and facilitate data exfiltration or other forms of cyberattacks.
3. **Remediation**: When this risk is detected, network administrators should:
   : 1. Identify the source and destination of the unauthorized traffic.
     2. Investigate the purpose and legitimacy of the protocol in question.
     3. If deemed necessary, implement firewall rules to block or limit traffic from the unapproved protocol.
     4. Consider updating network security policies and conducting employee training on secure networking practices to minimize such occurrences in the future.


<a id="risk-023"></a>

## SUSPICIOUS DNS TRAFFIC {#suspicious-dns-traffic}

1. **Description**: Suspicious DNS traffic that does not conform to standard protocol or is anomalous in behavior.
2. **Possible Attacks**: This detection indicates potential DNS tunneling, phishing, botnet communication, or malware propagation through non#.standard DNS requests and responses.
3. **Remediation**: When this risk is detected, investigate the source of the traffic to identify any compromised devices or services. Implement network segmentation and whitelist/blacklist DNS servers to limit potential exposure. Regularly update DNS server software and security policies to counteract emerging threats. Additionally, monitor outbound traffic from internal networks for unusual DNS activity and enforce strict access control measures on DNS servers to prevent unauthorized access.


<a id="risk-024"></a>

## TLS MISSING SNI {#tls-missing-sni}

1. **Description**: The TLS Server Name Indication (SNI) extension is not present in the Transport Layer Security (TLS) handshake.
2. **Possible attacks**: Detection of this risk indicates that an unencrypted or non#.standard protocol may be used, potentially allowing man#.in#.the#.middle attacks, data tampering, and interception of sensitive information during communication.
3. **Remediation**: Ensure that the TLS Server Name Indication (SNI) extension is properly configured on all servers. If a server does not support SNI, consider upgrading or using alternatives such as DNS#.based Server Name Indication (DNSSNI). Regularly monitor and update the system to mitigate potential vulnerabilities.


<a id="risk-025"></a>

## HTTP SUSPICIOUS CONTENT {#http-suspicious-content}

1. **Description**: Detection of non#.standard HTTP content in network traffic.
2. **Possible attacks**: This risk indicates that the monitored network may be subjected to malicious activities such as data manipulation, unauthorized data transmission, or the use of obscure protocols not commonly used in legitimate web traffic.
3. **Remediation**: Upon detection of NDPI HTTP SUSPICIOUS CONTENT, perform a thorough investigation on the affected connection to identify the source and nature of the suspicious content. If deemed necessary, isolate the suspect device from the network, apply appropriate security patches, update web application firewalls, and enhance intrusion detection/prevention systems. Additionally, monitor network traffic patterns for unusual behavior and implement a comprehensive network security policy that includes proper data encryption, access controls, and regular system updates.


<a id="risk-026"></a>

## RISKY ASN {#risky-asn}

1. **Description**: Monitoring of a network using an ASN (Autonomous System Number) associated with known malicious or high#.risk networks
2. **Possible attacks**: The detection of this risk indicates that traffic originating from or destined for such networks may pose a security threat, potentially exposing the monitored network to various types of attacks, including DDoS (Distributed Denial of Service), malware distribution, phishing, and more.
3. **Remediation**: When detected, it is recommended to block traffic from or to the identified risky ASN. Additionally, monitoring the behavior of this traffic for further indicators of compromise can help ensure network security. Keeping network software updated and implementing proper firewall rules are also crucial in mitigating potential threats associated with this risk.


<a id="risk-027"></a>

## RISKY DOMAIN {#risky-domain}

1. **Description**: Detection of a connection to a domain identified as potentially malicious or high#.risk.
2. **Possible attacks**: A connection to such domains can signal phishing attempts, malware downloads, botnet communication, or other forms of cyber threats.
3. **Remediation**: Upon detection, immediately block access to the risky domain and investigate further to determine the origin and nature of the threat. Implement a robust whitelist/blacklist management system for domains in your network's security policy. Monitor traffic patterns and user activity related to this incident to prevent similar occurrences in the future. Regularly update your network's threat intelligence feeds to stay informed about emerging threats and risky domains.


<a id="risk-028"></a>

## MALICIOUS FINGERPRINT {#malicious-fingerprint}


<a id="risk-029"></a>

## MALICIOUS SHA1 CERTIFICATE {#malicious-sha1-certificate}

1. **Description**: Detection of a certificate with an SHA#.1 signature in the monitored network traffic. SHA#.1 is no longer considered secure for digital certificates.
2. **Possible attacks**: This risk indicates that a connection may be using a weak or compromised digital certificate, potentially allowing man#.in#.the#.middle (MitM) attacks or data interception.
3. **Remediation**: Update the network to use modern digital certificate standards such as SHA#.256 or SHA#.3. Revoke and replace any existing SHA#.1 certificates. Implement a robust security policy for certificate management, including regular audits and revocation checking.


<a id="risk-030"></a>

## DESKTOP OR FILE SHARING SESSION {#desktop-or-file-sharing-session}

1. **Description**: A network data packet exchange that resembles a desktop or file sharing session.
2. **Possible Attacks**: This detection signals potential unauthorized data transfers, which could expose sensitive information or introduce malware into the monitored network. It may also indicate inappropriate use of network resources for non#.work related activities.
3. **Remediation**: When detected, promptly investigate the source and nature of the traffic to determine whether it is legitimate or malicious. Implement strict access controls to prevent unauthorized users from sharing files or accessing sensitive data. Regularly update antivirus software to protect against potential malware threats. Additionally, monitor network usage policies to ensure they are being adhered to and enforce penalties for non#.compliance.


<a id="risk-031"></a>

## TLS UNCOMMON ALPN {#tls-uncommon-alpn}

1. **Description**: The detection of an unusual Application#.Layer Protocol Negotiation (ALPN) extension in Transport Layer Security (TLS) traffic signifies the use of an uncommon ALPN protocol.
2. **Possible attacks**: An uncommon ALPN may indicate the use of a non#.standard or proprietary protocol, which can be exploited by attackers to bypass security measures and perform man#.in#.the#.middle (MitM) attacks, data exfiltration, or other malicious activities.
3. **Remediation**: To secure the monitored network when NDPI TLS UNCOMMON ALPN is detected:

> 1. Investigate the uncommon ALPN protocol to determine if it is approved for use and not vulnerable to known attacks. If the usage of this protocol is legitimate, whitelist it in your security policy.
> 2. Implement stricter access controls for traffic using the uncommon ALPN protocol to minimize potential attack vectors.
> 3. Regularly update TLS libraries and software components to ensure that they include the latest ALPN protocol updates and mitigate any discovered vulnerabilities.
> 4. Utilize a network security solution capable of deep packet inspection to maintain visibility into TLS traffic, enabling prompt detection and remediation of any potential threats associated with uncommon ALPNs.


<a id="risk-032"></a>

## TLS CERTIFICATE VALIDITY TOO LONG {#tls-certificate-validity-too-long}

1. **Description**: Certificate validity exceeding the defined time limit in Transport Layer Security (TLS) protocol.
2. **Possible attacks**: Extended certificate validity periods can hide long#.term compromises, allowing attackers to remain undetected for extended durations and performing malicious activities.
3. **Remediation**: Ensure that TLS certificates are properly renewed within their validity period. Regularly monitor and audit the expiration dates of all TLS certificates in use across the network. Implement automated systems for certificate management where possible, ensuring they are configured to notify administrators before the expiration date. Use a trusted Certificate Authority (CA) for issuing and managing your TLS certificates.


<a id="risk-033"></a>

## TLS SUSPICIOUS EXTENSION {#tls-suspicious-extension}

1. **Description**: The presence of unexpected or uncommon TLS (Transport Layer Security) extensions.
2. **Possible attacks**: Detection of this risk could signal potential man#.in#.the#.middle (MitM) attacks, malware injections, or other malicious activities that are attempting to bypass standard security protocols by using non#.standard TLS extensions.
3. **Remediation**: When detected, network administrators should immediately investigate the traffic source and verify if it is legitimate or suspicious. If deemed suspicious, the connection can be terminated, and the originating IP address could be blocked. Additionally, it's essential to ensure that up#.to#.date TLS libraries are being used and monitor for updates on known malicious TLS extensions to prevent future attacks.


<a id="risk-034"></a>

## TLS FATAL ALERT {#tls-fatal-alert}


<a id="risk-035"></a>

## SUSPICIOUS ENTROPY {#suspicious-entropy}

1. **Description**: High level of entropy in a data packet, indicating potential random or encrypted data.
2. **Possible attacks**: Detecting this risk signals the presence of unusual or unexpected data patterns that could indicate encryption evasion techniques, obfuscation, or malicious activity such as data exfiltration or botnet communication.
3. **Remediation**: Upon detection, analyze further to verify the legitimacy of the packet and its content. Implement robust encryption standards and ensure proper use of encryption protocols throughout the network. Regularly update and patch all devices to mitigate known vulnerabilities that could be exploited for data encryption manipulation. Monitor traffic patterns for abnormalities and configure intrusion detection/prevention systems accordingly to block or flag suspicious activity.


<a id="risk-036"></a>

## CLEAR TEXT CREDENTIALS {#clear-text-credentials}

1. **Description**: Transmission of unencrypted login credentials in clear text over the network.
2. **Possible attacks**: Detection of this risk indicates that sensitive usernames and passwords may be intercepted by malicious actors, leading to potential account takeover or unauthorized access.
3. **Remediation**: To secure the monitored network when this risk is detected:

> 1. Implement strong encryption protocols such as SSL/TLS for all login credentials transmission.
> 2. Enforce multi#.factor authentication (MFA) to reduce reliance on passwords alone.
> 3. Educate users about safe internet practices and the importance of not sharing their login credentials with others.
> 4. Regularly update system software and applications to patch any known vulnerabilities that could expose clear text credentials.


<a id="risk-037"></a>

## LARGE DNS PACKET {#large-dns-packet}

1. **Description**: A DNS (Domain Name System) packet exceeding the standard size limit.
2. **Possible attacks**: Large DNS packets can indicate a DDoS amplification attack, where an attacker exploits a vulnerable DNS server to flood the target with excessive traffic. This can lead to network congestion and potential service disruption.
3. **Remediation**: Implement rate limiting on DNS servers to control the flow of data and prevent excessive packets from being sent. Keep DNS servers updated and patch any known vulnerabilities. Monitor DNS traffic for anomalies and configure intrusion detection systems (IDS) or Intrusion Prevention Systems (IPS) to alert when large DNS packets are detected. Implementing these measures can help mitigate the risk of DDoS amplification attacks.


<a id="risk-038"></a>

## DNS FRAGMENTED {#dns-fragmented}

1. **Description**: Fragmented DNS responses are sent in multiple packets due to being larger than the maximum transmission unit (MTU).
2. **Possible attacks**: Fragmented DNS responses can hide malicious payloads, making them difficult to detect by traditional methods. Malware and phishing attacks often use this technique to evade network security controls.
3. **Remediation**: To mitigate the risk of NDPI DNS FRAGMENTED, consider implementing solutions that allow for larger MTU sizes or reassembly of fragmented packets at network edges. Regularly updating and maintaining DNS servers and firewalls can also help prevent malicious activities associated with this risk. Additionally, implementing intrusion detection/prevention systems (IDPS) can help in detecting and blocking suspicious traffic patterns that may indicate a potential attack using fragmented DNS responses.


<a id="risk-039"></a>

## INVALID CHARACTERS {#invalid-characters}

1. **Description**: The presence of invalid characters in network packets, which may indicate an attempt to circumvent security measures or introduce malicious content.
2. **Possible attacks**: Detection of this risk can signal a problem such as packet injection with malformed data, SQL injection attempts, or the use of unauthorized or non#.standard protocols.
3. **Remediation**: When detected, take immediate action to isolate and investigate affected systems. Implement strict access controls, filtering rules, and whitelists to prevent invalid characters from being transmitted on the network. Regularly update network security policies and software to mitigate new threats and vulnerabilities.


<a id="risk-040"></a>

## POSSIBLE EXPLOIT {#possible-exploit}

1. **Description**: Detection of potentially malicious traffic related to known software exploits such as Log4j or WordPress.
2. **Possible attacks**: This risk signal indicates the presence of network traffic that matches patterns associated with known software vulnerabilities (exploits). If left unchecked, these exploits can lead to unauthorized access, data breaches, and even remote code execution.
3. **Remediation**: Upon detection of this risk:
   : 1. Immediately isolate the affected devices or services from the network to prevent any further damage.
     2. Apply available security patches for the vulnerable software (Log4j, WordPress, etc.) as soon as possible.
     3. Review and update firewall rules to block known exploit traffic.
     4. Monitor logs and alerts for any related activity.
     5. Implement intrusion detection and prevention systems to further protect against such threats.
     6. Regularly update your system's security policies based on the latest threat intelligence.


<a id="risk-041"></a>

## TLS CERTIFICATE ABOUT TO EXPIRE {#tls-certificate-about-to-expire}

1. **Description**: A Transport Layer Security (TLS) certificate is about to expire. TLS certificates are used for secure communication over the internet. Expired or invalid certificates can lead to data breaches and man#.in#.the#.middle attacks.
2. **Possible attacks**: If a TLS certificate is about to expire, it may not be trusted by clients trying to connect. This can cause connections to fail, leading to service disruptions. An expired certificate also opens the door for man#.in#.the#.middle (MITM) attacks, where an attacker can intercept and modify data between the communicating parties.
3. **Remediation**: To secure your network when this risk is detected, immediately update or renew the affected TLS certificate(s). Ensure that all servers and clients are configured to trust the new certificate and remove any expired certificates from trusted certificate stores. Regularly monitor your TLS certificates for upcoming expiration dates and ensure timely updates to maintain a secure network.


<a id="risk-042"></a>

## PUNYCODE IDN (PUNYCODE INTERNATIONALIZED DOMAIN NAMES) {#punycode-idn-punycode-internationalized-domain-names}

1. **Description**: Identification of non#.ASCII domain names using Punycode encoding in DNS packets
2. **Possible Attacks**: This detection signals a potential for homograph attacks, where malicious actors can disguise their domain as a legitimate one, leading to phishing or other cyber threats.
3. **Remediation**: To secure the monitored network when this risk is detected:
   : 1. Implement strict DNS security measures such as DNSSEC and use of trusted recursive resolvers.
     2. Regularly update and patch DNS server software to protect against known vulnerabilities.
     3. Monitor DNS traffic for anomalies and configure firewalls to block suspicious or unusual requests.
     4. Implement a robust email security solution to detect and prevent phishing attempts.
     5. Educate users about potential phishing threats and how to identify and avoid them.


<a id="risk-043"></a>

## ERROR CODE DETECTED {#error-code-detected}

1. **Description**: Detection of an unrecognized or unsupported Network Data Protocol Inspection (NDPI) error code in the monitored network traffic.
2. **Possible attacks**: This can indicate the presence of unusual or potentially malicious protocols, as well as outdated or misconfigured software that may be susceptible to exploitation by attackers.
3. **Remediation**: To secure the monitored network when this risk is detected, perform the following actions:

> 1. Investigate the source of the unrecognized NDPI error code to identify any suspicious activity or misconfigured devices.
> 2. Update the deep packet inspection software and related protocol definitions to ensure comprehensive coverage against known and emerging threats.
> 3. Implement network segmentation to isolate critical infrastructure from potential attacks originating from untrusted sources or systems.
> 4. Enforce strict access controls and strong authentication measures on all network devices, including firewalls, routers, and switches.
> 5. Regularly monitor network traffic for anomalies and suspicious behavior, and respond promptly to any detected issues.


<a id="risk-044"></a>

## HTTP CRAWLER BOT {#http-crawler-bot}

1. **Description**: A network device or software, often malicious, that systematically accesses and collects information from the web using HTTP protocol.
2. **Possible attacks**: The detection of this risk in deep packet inspection signals potential unauthorized data gathering, excessive bandwidth consumption, and potentially a precursor to further cyberattacks such as DDoS or information theft.
3. **Remediation**: When detected, isolate the suspicious device from the network for further investigation. Implement rate limiting on HTTP requests to control excessive traffic. Use web application firewalls (WAF) to block malicious HTTP bots and ensure regular software updates to keep your system secure.


<a id="risk-045"></a>

## ANONYMOUS SUBSCRIBER {#anonymous-subscriber}


<a id="risk-046"></a>

## UNIDIRECTIONAL TRAFFIC {#unidirectional-traffic}

1. **Description**: Unidirectional traffic is network communication that only flows in one direction. This alert may indicate that either server or client are not responding, due to service being down or communications to the flow end host being blocked.
2. **Possible attacks**: Detection of unidirectional traffic signals a problem as it might indicate an open port scan, denial of service attack, or other forms of malicious activity where the attacker does not expect a response from the targeted system.
3. **Remediation**: When NDPI UNIDIRECTIONAL TRAFFIC is detected, investigate the source and destination IP addresses, along with the port number. Close any open ports that are unnecessary or take appropriate measures to secure them. Implement network monitoring tools to identify and block further unidirectional traffic. Regularly update software packages and system configurations to ensure protection against emerging threats.


<a id="risk-047"></a>

## HTTP OBSOLETE SERVER {#http-obsolete-server}

1. **Description**: Detection of obsolete HTTP servers in the monitored flow
2. **Possible attacks**: The use of obsolete HTTP servers can expose vulnerabilities that may allow for various attacks such as remote code execution, injection attacks, and denial#.of#.service.
3. **Remediation**: Upgrade or replace the obsolete HTTP server with a secure and updated version to patch known vulnerabilities. Regularly apply security patches and maintain good hygiene practices like strong authentication mechanisms and access controls. Implement HTTPS where possible to encrypt communication between client and server.


<a id="risk-048"></a>

## PERIODIC FLOW {#periodic-flow}

1. **Description**: A network flow is observed to recur at regular intervals, indicating an application utilizing a patterned behavior.
2. **Possible Attacks**: This detection could signal a problem in the monitored network if it points towards applications using predictable patterns, which may be vulnerable to Denial of Service (DoS) attacks that exploit this periodicity for amplification effects or synchronization attacks.
3. **Remediation**: To secure the network when NDPI PERIODIC FLOW is detected, consider implementing rate limiting strategies on the relevant applications and reviewing their configurations for any potential vulnerabilities. Additionally, ensure that intrusion detection/prevention systems (IDS/IPS) are configured to recognize and respond appropriately to DoS attacks or synchronization attacks targeting periodic flows. Finally, monitor these applications closely for abnormal behavior and tune deep packet inspection rules as necessary.


<a id="risk-049"></a>

## MINOR ISSUES {#minor-issues}

1. **Description**: Detection of minor protocol issues or anomalies in the monitored flow that do not represent a critical threat but deviate from expected protocol behavior.
2. **Possible attacks**: Minor issues can be indicators of misconfigured clients or servers, protocol implementation bugs, or early-stage reconnaissance activity. While individually low-risk, aggregated minor issues may point to a compromised endpoint or an attacker probing for weaknesses.
3. **Remediation**: When this risk is detected, it is recommended to:

> 1. Review the affected flow endpoints for signs of misconfiguration or software bugs.
> 2. Correlate minor issue alerts with other risk signals from the same host to detect patterns.
> 3. Keep client and server software up-to-date to minimize protocol implementation defects.
> 4. Monitor over time — a spike in minor issues from a single host warrants deeper investigation.


<a id="risk-050"></a>

## TCP ISSUES {#tcp-issues}

1. **Description**: Detection of TCP-level anomalies such as out-of-order segments, retransmissions, duplicate ACKs, or unexpected RST/FIN sequences that deviate from normal TCP behavior.
2. **Possible attacks**: TCP issues can be leveraged by attackers to perform TCP session hijacking, denial-of-service attacks through SYN flooding or RST injection, or to evade deep packet inspection by sending fragmented or reordered segments.
3. **Remediation**: Upon detection of TCP issues, it is recommended to:

> 1. Investigate whether the anomalies are caused by network congestion or faulty hardware versus deliberate manipulation.
> 2. Enable and tune TCP state tracking on firewalls and IDS/IPS to detect injection and hijacking attempts.
> 3. Apply rate limiting on TCP connections from sources generating excessive retransmissions or RST storms.
> 4. Review network device firmware and operating system TCP stack configurations for known vulnerabilities.


<a id="risk-051"></a>

## FULLY ENCRYPTED {#fully-encrypted}

1. **Description**: The entire flow payload is encrypted using a non-standard or unrecognized encryption scheme, making it impossible to identify the application protocol via deep packet inspection.
2. **Possible attacks**: Full payload encryption is a common technique used by malware, ransomware command-and-control (C2) channels, and data exfiltration tools to evade network inspection and bypass security controls.
3. **Remediation**: When fully encrypted traffic is detected, it is recommended to:

> 1. Correlate the flow with known malicious IP addresses or domains using threat intelligence feeds.
> 2. Inspect the endpoints involved for signs of compromise, unusual processes, or outbound connection patterns.
> 3. Implement network segmentation to restrict which hosts are permitted to initiate fully encrypted sessions to external destinations.
> 4. Consider deploying SSL/TLS inspection where policy permits, to maintain visibility into encrypted traffic.
> 5. Monitor for unusual data volumes or connection durations associated with fully encrypted flows.


<a id="risk-052"></a>

## TLS ALPN SNI MISMATCH {#tls-alpn-sni-mismatch}

1. **Description**: A mismatch between the Application-Layer Protocol Negotiation (ALPN) extension and the Server Name Indication (SNI) extension in the TLS handshake. The protocol advertised via ALPN does not match what is expected for the declared server name.
2. **Possible attacks**: This mismatch can indicate a man-in-the-middle (MitM) attack where an intercepting proxy mis-advertises protocol capabilities, or it can signal malware using TLS to tunnel non-standard protocols while disguising the connection as legitimate HTTPS traffic.
3. **Remediation**: When a TLS ALPN/SNI mismatch is detected, it is recommended to:

> 1. Investigate the server name and destination to determine if the ALPN mismatch is caused by a misconfigured server or a deliberate evasion attempt.
> 2. Verify that the server at the declared SNI hostname supports the negotiated ALPN protocol.
> 3. Block or quarantine connections where the mismatch cannot be explained by a known application.
> 4. Enforce strict TLS inspection policies that flag or terminate sessions with inconsistent handshake parameters.


<a id="risk-053"></a>

## MALWARE HOST CONTACTED {#malware-host-contacted}

1. **Description**: A client or server in the monitored network has established a connection to a host identified as a known malware distribution point, botnet C2 server, or other malicious infrastructure.
2. **Possible attacks**: Contacting a malware host can indicate an active infection on the endpoint, ongoing botnet communication, malware downloading a second-stage payload, or data exfiltration to attacker-controlled infrastructure.
3. **Remediation**: Upon detection of this risk, it is strongly recommended to:

> 1. Immediately isolate the endpoint that initiated the connection to prevent further spread or data loss.
> 2. Perform a full forensic investigation of the affected host, including memory and disk analysis.
> 3. Block the malicious IP address or domain at the firewall and DNS level.
> 4. Check other hosts on the network for similar connections to identify lateral movement.
> 5. Report the incident to the appropriate security team and update threat intelligence feeds.
> 6. Restore the affected system from a clean backup after confirming the infection vector is remediated.


<a id="risk-054"></a>

## BINARY DATA TRANSFER {#binary-data-transfer}

1. **Description**: Detection of binary data being transferred over a protocol that is expected to carry only text-based or structured content, such as HTTP or DNS.
2. **Possible attacks**: Binary data transfers over unexpected protocols can indicate data exfiltration, malware payload delivery, or the use of covert channels to bypass security controls. Attackers may encode executables or configuration data as binary blobs to avoid signature-based detection.
3. **Remediation**: When binary data transfer is detected, it is recommended to:

> 1. Inspect the content of the transfer to determine whether it contains executables, archives, or other suspicious payloads.
> 2. Block binary transfers on protocols where they are not expected (e.g., restrict binary content in DNS responses).
> 3. Implement data loss prevention (DLP) policies to detect and prevent unauthorized binary file transfers.
> 4. Investigate the source and destination endpoints for signs of compromise or unauthorized software.


<a id="risk-055"></a>

## PROBING ATTEMPT {#probing-attempt}

1. **Description**: Detection of network activity consistent with active reconnaissance or port scanning. The observed traffic pattern suggests an entity is systematically probing hosts or services to discover open ports, running services, or potential vulnerabilities.
2. **Possible attacks**: Probing attempts are typically the first phase of an attack lifecycle. They are used by threat actors to map the network topology, identify vulnerable services, and select targets for exploitation. Common techniques include TCP SYN scans, UDP probes, and ICMP sweeps.
3. **Remediation**: When a probing attempt is detected, it is recommended to:

> 1. Block or rate-limit traffic from the probing source at the firewall or IPS level.
> 2. Investigate whether the probing originates from inside or outside the network — internal probing may indicate a compromised host.
> 3. Ensure that all exposed services are running up-to-date software and are hardened against known vulnerabilities.
> 4. Review firewall rules to minimize the attack surface by closing unnecessary ports and services.
> 5. Enable and monitor IDS/IPS alerts for follow-up exploitation attempts from the same source.


<a id="risk-056"></a>

## OBFUSCATED_TRAFFIC {#obfuscated-traffic}

1. **Description**: Detection of network traffic where the payload or protocol headers have been deliberately obfuscated to hinder analysis and evade deep packet inspection. The obfuscation may involve encoding, encryption layering, or protocol mimicry.
2. **Possible attacks**: Traffic obfuscation is a common technique used by malware, remote access tools (RATs), and advanced persistent threat (APT) actors to blend malicious communications into normal network activity and bypass security monitoring. It is also used by anonymization tools and some legitimate privacy applications.
3. **Remediation**: When obfuscated traffic is detected, it is recommended to:

> 1. Correlate the source and destination of the obfuscated flow with known threat intelligence indicators.
> 2. Analyze the endpoints involved for signs of unauthorized software or unusual process behavior.
> 3. Implement behavioral analytics to detect anomalous communication patterns regardless of content visibility.
> 4. Enforce network egress policies that require identifiable, approved protocols on all outbound connections.
> 5. Consider deploying application-layer gateways that can identify protocol mimicry and obfuscated tunneling.


<a id="risk-057"></a>

## NDPI_SLOW_DOS {#ndpi-slow-dos}

1. **Description**: Detection of a slow denial-of-service (DoS) attack pattern, where an attacker deliberately maintains connections using minimal bandwidth to exhaust server resources such as connection tables, threads, or memory without triggering traditional volumetric DoS thresholds.
2. **Possible attacks**: Slow DoS techniques include Slowloris (holding HTTP connections open by sending incomplete headers), Slow POST attacks (sending request bodies at extremely low rates), and slow read attacks (consuming server buffers by not reading responses). These attacks can render services unavailable while consuming very little attacker bandwidth.
3. **Remediation**: When a slow DoS pattern is detected, it is recommended to:

> 1. Configure connection timeout policies on web servers and load balancers to terminate idle or abnormally slow connections.
> 2. Implement rate limiting on new connection establishment from individual source IPs.
> 3. Deploy a Web Application Firewall (WAF) capable of detecting and mitigating slow HTTP attack patterns.
> 4. Monitor server resource utilization (thread pools, connection tables) alongside network traffic to detect resource exhaustion early.
> 5. Consider using reverse proxies or CDNs with built-in slow DoS protection in front of critical services.


<a id="risk-058"></a>

## NDPI_NON_PQC {#ndpi-non-pqc}

1. **Description**: Detection of cryptographic algorithms that are not resistant to attacks by quantum computers. The flow is using classical public-key cryptography (e.g., RSA, Diffie-Hellman, or elliptic-curve variants) that will become vulnerable once sufficiently powerful quantum computers are available. This alert detects: SSH, TLS, QUIC and IPSEC flows with obsolete encryption/key exchange algorithms
2. **Possible attacks**: While quantum computers capable of breaking current encryption are not yet widely available, adversaries may be conducting "harvest now, decrypt later" attacks — capturing encrypted traffic today with the intention of decrypting it once quantum computing capabilities mature. Sensitive long-lived data is particularly at risk.
3. **Remediation**: When non-PQC traffic is detected, it is recommended to:

> 1. Identify all services and applications using classical public-key cryptography and prioritize migration to Post-Quantum Cryptography (PQC) algorithms standardized by NIST (e.g., ML-KEM, ML-DSA, SLH-DSA).
> 2. Enable hybrid key exchange mechanisms (combining classical and PQC algorithms) as an interim step during migration.
> 3. Update TLS libraries (e.g., OpenSSL, BoringSSL) to versions that support PQC cipher suites.
> 4. Prioritize migration for flows carrying highly sensitive or long-lived data such as authentication credentials, encryption keys, or confidential communications.
> 5. Monitor vendor roadmaps for PQC support in network appliances, VPN gateways, and application servers.
