Flow Behavioural Checks
#######################

Flow checks are performed on live flows.

____________________

**Blacklisted Flow**
~~~~~~~~~~~~~~~~~~~~~~

The system sends you an alert when a blacklisted host or domain is detected.

A Domain Name System Blacklist is a list that allows Internet Service Providers to block potentially malicious traffic - a blacklist contains domains, email addresses and IP addresses.
If one of them is blacklisted, it might have bad reputation and be insecure.

In case of domain -it might be suspicious website
In case of email- it might send spam
In case of host- it might conduct  suspicious activity

The goal of the check is to notify that one of above cases has been verified.

*Category: Cybersecurity*

*Enabled by Default*




**Clear-Text Credentials**
~~~~~~~~~~~~~~~~~~~~~~~~~~

Points out the unsafe application for you credentials.


Instead of using HTTPS some applications transmit passwords over unencrypted connections, making them vulnerable. In order to exploit this vulnerability, an attacker may spy on the victim's network traffic. This occurs when a client communicates with the server over an insecure connection such as public Wi-Fi, or an enterprise or home network that is shared with a compromised computer. To prevent this type of attack it's fundamental to use an encrypted communication transport-level (SSL or TLS) to protect all sensitive data passing between the client and the server.

The warning appears when the credentials have been inserted on the unsafe/encrypted channel.


*Category: Cybersecurity*

*Enabled by Default*


**DNS fragmented messages**
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Notifies that the message was fragmented.

DNS messages are sent via UDP. Even when fragmentation works, it may not be secure; it is theoretically possible to spoof parts of a fragmented DNS message, without easy detection for the receiver

The UDP protocol is effective and efficient with small responses. In the case of large packers, DNS resolvers should switch from using from UDP to TCP.
  
*Category: Cybersecurity*

*Enabled by Default*


**Malformed packets**
~~~~~~~~~~~~~~~~~~~~~

The alert is sent when it’s not possible to dissect the payload of a packet.

Maliciously malformed packets take advantage of vulnerabilities in operating systems and applications by intentionally altering the content of data fields in network protocols. These vulnerabilities may include causing a system crash (a form of denial of service) or forcing the system to execute the arbitrary code.

When malformed packets are seen by ntopng, the system warns with alert.


*Category: Cybersecurity*

*Enabled by Default*


**External Alert** 
~~~~~~~~~~~~~~~~~~


It’s a notification of External alerts from other devices, for example, logs from a firewall.

For a more complete and detailed overview of the activity involved in inspection, the system can ingest alerts from any external source. 

External sources offer a deeper understanding and  more complete view of what’s going on your network or device.

*Category: Cybersecurity*

*Enabled by Default*

 

**Suspicious User Agent**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The alert is sent when a suspicious User Agent is seen.


The User Agent is a string of text that identifies the browser and operating system for the web server. UA is transmitted in the HTTP header when the browser makes a request to the web server. 
User Agents are just "free-text" and might be used with malicious intentions
 the User Agent might be used to attack websites with:
    • SQL Injection via User Agent 
    • XSS with User Agent 
    • Spoofing User Agent to deceive the server 
      
The goal is to notify by making sure all the countermeasures are implemented.



*Category: Cybersecurity*

*Enabled by Default*

**Suspicious HTTP header**
~~~~~~~~~~~~~~~~~~~~~~~~~~


HTTP Host header attacks exploit vulnerable websites that handle the value of the Host header in an unsafe way. If the server implicitly trusts the Host header, and fails to validate it properly, an attacker may be able to use this input to inject harmful payloads that manipulate server-side behavior. Attacks that involve injecting a payload directly into the Host header are often known as "Host header injection" attacks. 

The system notifies of suspicious HTTP header inserted.

*Category: Cybersecurity*

*Enabled by Default*



**Suspicious HTTP URL**
~~~~~~~~~~~~~~~~~~~~~~~


A warning about clicked unsafe URL.


A secure website’s URL should begin with HTTPS rather than HTTP. The “s”  stands for secure and is using an SSL (Secure Sockets Layer) connection. Your information will be encrypted before being sent to a server.
Malicius URL -The simple act of clicking on a malicious URL, opening an attachment, or engaging with an ad can lead to serious consequences. By clicking on a malicious URL, you may find yourself the target of a phishing attack, have malware auto-install onto your device.

The Alert is sent in order to raise the awareness on this type of URL and to pay attention on final httpS URLs



*Category: Cybersecurity*

*Enabled by Default*



**Malicious DNS query**
~~~~~~~~~~~~~~~~~~~~~~~~


The system detects that the DNS is not correctly resolved.


Domain Name Server (DNS) hijacking, also named DNS redirection, is a type of DNS attack in which DNS queries are incorrectly resolved in order to redirect users to malicious sites.

Hackers haven’t forgotten or ignored DNS. In fact, it’s becoming an increasingly abused protocol to find command and control (C2) servers, control compromised systems, and exfiltrate your data. Threat actors are increasingly exploiting DNS.

Malicious DNS, include:
    • Domain-generation-algorithm (DGA) queries 
    • C2 data tunneled through DNS 
    • Data exfiltration via tunneled DNS 
    
The Alert is sent in order to notify that the system might have been compromised and changed the DNS server

*Category: Cybersecurity*

*Enabled by Default*



**IDN Domain Name**
~~~~~~~~~~~~~~~~~~~


The domain has been converted in Ponycode to latin version.

The acronym IDN stands for 'Internationalized Domain Name'. For non-latin script or alphabet,

there is a system called Punycode. When you wish to register an IDN domain, you must convert the domain name to Punycode, Then when the user enters a URL containing an IDN domain into their web browser, it will convert the IDN domain into Punycode and resolve that domain.

The alert notifies that the website domain name was written in non latin script.


*Category: Cybersecurity*

*Enabled by Default*


**ICMP Data Exfiltration**
~~~~~~~~~~~~~~~~~~~~~~~~~~



Checks data Exfiltration by using ping.
 
The Internet Control Message Protocol is known by normal users via ping or traceroute, installed on every Operating System today. If ping is executed it will send an icmp packet with the flags - ICMP Echo Request, if the remote host wants to acknowledge this, it will respond with an “ICMP Echo Reply”. The protocol itself is used for testing of remote systems. 

Attackers can exploit this design choice to obfuscate malicious network behavior. Instead of explicitly communicating with a machine in the protocol of choice, each packet will be injected into an Echo or Echo Reply packet. 

The system sends an alert when detects a ICMP data exfiltration.

*Category: Cybersecurity*

*Enabled by Default*


**Known Application on Non-Standard Port**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



Checks if all the apps are on the right port.


In order to avoid attacks aimed at standard ports, some organizations have turned to using ‘non-standard’ ports for their services. A non-standard port is a port that is used for a purpose not a default assignment. Using port 8080 instead of port 80 for web traffic is one example.
This is the strategy of ‘security through obscurity’. While it may keep cybercriminals confused for a while, it’s not a long-term security solution. Also, it can make connecting to your web server more difficult for users because their browser is pre-configured to use port 80.

Sends a notification in case the system detects an application is on unusual port.


*Category: Cybersecurity*

*Enabled by Default*



**Deprecated SSH protocol**
~~~~~~~~~~~~~~~~~~~~~~~~~~~


Warns about an outdated Secure Shell protocol.

The SSH protocol (Secure Shell) is a method for secure remote login from one computer to another. SSH version is outdated is not necessarily a security problem. However the recommendation is to install the latest version.
In terms of security if the target is using deprecated SSH cryptographic settings to communicate risks a man-in-the-middle attacker may be able to exploit this vulnerability to decrypt the session key and even the messages.

Notifies that SSH protocol is obsolete.

*Category: Cybersecurity*

*Enabled by Default*


**Outdated TLS versions**
~~~~~~~~~~~~~~~~~~~~~~~~~

Warns about an old version of TLS.

Sensitive data always requires robust protection. TLS protocols provide confidentiality, integrity, and often authenticity protections to information while in transit over a network. This can be achieved by providing a secured channel between a server and a client to communicate for a session. Over time, new TLS versions are developed, and some of the previous versions become outdated for vulnerabilities or technical reasons; and, therefore, should no longer be used to protect data.

Alerts when a new version of TLS is needed.


*Category: Cybersecurity*

*Enabled by Default*


**Domain Generation Algorithm (DGA)**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Warns about a suspicious domain that could be used with the scope to make survive the malware.

A domain generation algorithm DGA is a program that generates a list of domain names. DGA provide malware with new domains in order to evade security measures.
Continously changing domain names helps hackers to prevent their servers from being blacklisted. The idea is to have an algorithm that produces random domain names that the malware can use and quickly switch between them. Security software tools block and take down the malicious domains that malware uses but switching domains quickly enables cybercriminals to continue pursuing the attack without being detected.

The goal is notify that the system has detected a malware.

*Category: Cybersecurity*

*Enabled by Default*




**Remote Code Execution**
~~~~~~~~~~~~~~~~~~~~~~~~~


The system sees RCE that consist in Allowing an attacker to remotely execute malicious code on a computer.

Remote code execution RCE is a type of software security vulnerabilitity. RCE vulnerabilities will allow a malicious actor to execute a code on a remote machine over LAN, WAN, or internet. An attacker can gain a full control over the compromised machine.


*Category: Cybersecurity*

*Enabled by Default*

**Missing TLS SNI**
~~~~~~~~~~~~~~~~~~~~


Inspects if SNI is missed.

Often a web server is responsible for multiple hostnames – or domain names. Each hostname has its own SSL certificate if the websites use HTTPS.
The problem is, all these hostnames on one server are at the same IP address. This isn't a problem over HTTP, because as soon as a TCP connection is opened the client will indicate which website they're trying to reach in an HTTP request.
But in HTTPS, a TLS handshake takes place first, before the HTTP conversation can begin (HTTPS still uses HTTP – it just encrypts the HTTP messages). Without SNI (Server Indication Name) then, there is no way for the client to indicate to the server which hostname they're talking to. As a result, the server may produce the SSL certificate for the wrong hostname. If the name on the SSL certificate does not match the name the client is trying to reach, the client browser returns an error and usually terminates the connection.

Alert is sent to notify that TLS SNI is missing.

*Category: Cybersecurity*

*Enabled by Default*


**Unidirectional network**
~~~~~~~~~~~~~~~~~~~~~~~~~~


Checks for “one way” data flow.
      
      
There are many situations in which a computer does not require a bidirectional flow
A connection on which a device may only transmit data or only receive data, but not both. That is, a source can transmit data to one or many destinations, but the destination(s) cannot transmit data back to the source because it is unable to receive.

The system sends a notification when detects in and out going data flows.


*Category: Cybersecurity*

*Enabled by Default*



**TCP connection refused**
~~~~~~~~~~~~~~~~~~~~~~~~~~

Check a TCP connection.

In general, connection refused - errors are generated during a system connection call when an application attempts to connect using TCP to a server port which is not open.

Sends an alert in case the port is closed or other errors.

*Category: Cybersecurity*

*Enabled by Default*


**Non-printable characters**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for non printable characters.

Researchers urge developers to secure code by disallowing non-ASCII characters. 
They suggested developers to protect their code from attacks by proscribing the use of non-ASCII characters, which are rare and harmful in code since development teams typically favor English language-based
For traslating it’s suggested to substitute non-ASCII characters with ASCII characters (e.g. ä → ae, ß → ss)

Sends an alert in case of suspect non printable characters


*Category: Cybersecurity*

*Enabled by Default*


**The Remote desktop session has ended**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks the stability of the remote desktop session

The connection to the remote computer was lost, possibly due to network connectivity problems. If the problem continues, contact your network administrator or technical support.

    • An error occurred while establishing the connection. 
    • There is a network problem
    • The administrator has ended the session.
      
Sends an alert in case the remote desktop session is ended.

*Category: Cybersecurity*

*Enabled by Default*


**Possible SQL Injection**
~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for possible sql injections

SQL injection, also known as SQLI, is a common attack vector that uses malicious SQL code for backend database to manipulate and access sensitive information that was not intended to be public. This information may include sensitive company data, user lists or private customer details.

Sends an alert when SQL might have occurred.

*Category: Cybersecurity*

*Enabled by Default*


**Possible XSS**
~~~~~~~~~~~~~~~~


The check verifies a possible XSS attack.

Cross-site Scripting (XSS) is a client-side code attack. The attacker aims to execute malicious scripts in a web browser of the victim by including malicious code in a legitimate web page or web application. The actual attack occurs when the victim visits the web page or web application that executes the malicious code. The web page or web application becomes a way to deliver the malicious script to the user’s browser. Commonly used for Cross-site Scripting attacks are forums, message boards, and web pages that allow comments.

The system sends an alert in case it has detected a possible XSS attack on the website.

*Category: Cybersecurity*

*Enabled by Default*



**Unsafe protocol**
~~~~~~~~~~~~~~~~~~~

The check identifies an insecure/unencrypted protocols.

Credential information submitted through telnet is not encrypted and is vulnerable to identity theft for this reason is not recommended.Users should instead use ssh https://it.wikipedia.org/wiki/Secure_Shell
Also,unecrypted ftp should not be used. Users wishing to transfer files between computers should instead use utilities sftp.

The alert is sent when important data is transmitted without any encryption .


*Category: Cybersecurity*

*Enabled by Default*



**HTTP Suspicious Content**
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Check controls for unclear content in HTTP (HyperText Transfer Protocol )

Suspicious headers with special characters without a readable content. A Clickjacking https://it.wikipedia.org/wiki/Clickjacking attack can be performed from the attacker by giving the browser some instructions directly via HTTP header.

The alert is sent when the system identifies an attempt to hide behind Mime type a malicious code.


*Category: Cybersecurity*

*Enabled by Default*


**TLS flow will not be used to transport HTTP content**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Check identifies that HTTP content isn't transmitted in TLS protocol.

The main limitation of HTTP is that it is completely insecure. All traffic carried over HTTP is readable to the intruders. As the web carries more and more sensitive information due to ecommerce, online health records, social media, etc. this places more and more users’ sensitive data are at risk.
HTTPS uses the Transport Layer Security (TLS) protocol – to add security to HTTP. With SSL/TLS, HTTPS encrypts all traffic flowing between the client and the server.

Alert is sent when HTTP traffic is not encrypted.


*Category: Cybersecurity*

*Enabled by Default*


**TLS Certificate Issues**
~~~~~~~~~~~~~~~~~~~~~~~~~~

Check if TLS Certiicate works properly.

The name mismatch error indicates that the domain name in the SSL certificate (SSL certificate enables an encrypted connection) doesn't match the address that is in the address bar of the browser. 
if the domain name is associated with an old IP address that has not been changed and a different certificate is referring to the same IP address, then you may see a Common Name Mismatch Error. The problem can be solved by changing DNS record.

Alert is sent when a mismatch error in TLS Certificate is seen.


*Category: Cybersecurity*

*Enabled by Default*


**SMB insecure**
~~~~~~~~~~~~~~~~

Checks for SMB
 
Notably, SMB https://it.wikipedia.org/wiki/Server_Message_Block was used as an attack channel for both the WannaCry and NotPetya huge ransomware attacks in 2017. SMBv1 is so insecure that most security experts now recommend that administrators disable it entirely via a group policy update or find other solutions to protect the infrastructure against other Server Message Block (SMB) exploits.

Alert is sent when Server message block is detected.

*Category: Cybersecurity*

*Enabled by Default*


**Blacklisted Country**
~~~~~~~~~~~~~~~~~~~~~~


Check verififes a Blacklisted Country.

The check verifies whether blacklisted country has been contacted, or viceversa, somebody from a blacklisted country had tried to contact the host.

Often the country is blacklisted due to many cyberattacks that are launched from that geographical area.There are countries with most ransomware https://it.wikipedia.org/wiki/Ransomware attacks.

The alert appears when a blacklisted country is detected.

*Category: Cybersecurity*

*Enabled by Default*



**Large DNS Packet (512+ bytes)**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Check for correct size of DNS packets.

DNS packets over UDP should be limited to 512 bytes. This size guarantees the datagram won't be fragmented because losing just one fragment leads to losing the entire datagram. When DNS packets overcome this threshold indicate a potential security risk or a misconfiguration.

The alert is sent in case the size overcomes 512 bytes.

*Category: Cybersecurity*

*Enabled by Default*



**HTTP Numeric IP Host**
~~~~~~~~~~~~~~~~~~~~~~~~

The Check is able to see a numeric IP Host.

DNS keeps the record of all domain names and the associated IP addresses. When you type in a URL in your browser, the DNS resolves the domain name into an IP address. In other words, DNS is a service that maps domain names to corresponding IP addresses.

Notifies in case of numeric IP Host.


*Category: Cybersecurity*

*Enabled by Default*


**WEb Mining**
~~~~~~~~~~~~~

Check generated traffic from/to hosts known to perform cryptocurrencies mining.

Cryptocurrency mining is a computationally intensive task which requires powerful resources like specialized hardware and processors,as significant electricity costs and investments in hardware. 
To avoid the costs of all these tools - expensive hardware, cybercriminals infect systems in order to consume the victims’ CPU or GPU power and existing resources for crypto mining. Putting in place different attack vectors, such as spam campaigns and Exploit Kits, they are able to turn the infected machines into army of cryptocurrency miners.

The Alert is received when traffic from/to hosts known to perform cryptocurrencies mining is discovered.

Category: Cybersecurity*

*Enabled by Default*



**Unexpected DNS Server**
~~~~~~~~~~~~~~~~~~~~~~~~~

Check for not allowed DNS servers.

DNS blocking is a filter method used to prevent Internet users visiting malicious websites. It works by comparing IP addresses against those assigned to websites known to be harmful or potentially threatning – those websites where malware and ransomware can be caught – dns blocking is implemented in order to prevent devices connecting with them when a match is found.

The Alert is sent when not allowed DNS server is detected.


Category: Cybersecurity*

*Enabled by Default*



**Unexpected NTP Server**
~~~~~~~~~~~~~~~~~~~~~~~~~

Check for not allowed NTP server.

NTP is one of the internet's oldest protocols and is not secure by default, leaving it susceptible to distributed denial-of-service (DDoS) and man-in-the-middle (MitM) attacks.


The Alert is sent when not allowed NTP server is seen.

Category: Cybersecurity*

*Enabled by Default*



**Remote to Local Insecure Protocol**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Check for remote to local insecure protocol.

Remote Desktop Protocol (RDP) is a Microsoft proprietary protocol that enables remote connections to other computers, typically over TCP port 3389.
RDP itself is not a secure protocol so firewalls should restrict access to remote desktop listening ports.Using RDP Gateway is highly recommended for restricting RDP access to desktops and servers.

The alert is sent to notify the insecure protocol.


Category: Cybersecurity*

*Enabled by Default*



**Elephant flow**
~~~~~~~~~~~~~~~~

Checks a flow.

Elephant flows are data sessions that take up significant amounts of network capacity relative to other types of data sessions. For example, a three-minute YouTube stream accounts for 20,000 times more bandwidth than three minutes consuming Twitter. Visible effect of Elephant Flows can be seen in high cpu usage.

Notifies when elephant flow is detected.
 
*Category: Cybersecurity*

*Enabled by Default*


**Possible exploit**
~~~~~~~~~~~~~~~~~~~~

Checks for an exploit.

An exploit is a code that takes advantage of a software vulnerability or security flaw. Exploits allow an intruder to remotely access a network and gain elevated privileges, or move deeper into the network.
In some cases, an exploit can be used as part of a multi-component attack. Instead of using a malicious file, the exploit may instead drop another malware, which can include backdoor Trojans and spyware that can steal user information from the infected systems. 

The system sends an alert when a possible exploit is detected.

*Category: Cybersecurity*

*Enabled by Default*



**Binary Application Transfer**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Cheks for Binary Application Transfer.

Binary is a name for an executable file format and is intended for end-users.There are several variants of .exe, .msi and .zip files. The binary application can be downloaded/uploaded. These applications include Windows binaries, Linux executables, Unix scripts and Android apps.
A binary can be potentially harmful, and therefore can generate malicious behavior.

The alert is sent to notify an executable file.

*Category: Cybersecurity*

*Enabled by Default*


**Error code**
~~~~~~~~~~~~~~

Checks for error code.


HTTP response status codes indicate whether a specific HTTP request has been successfully completed or failed. Responses are grouped in five classes: 


informational responses
successful responses
re-directs
client errors
server errors


Alert is sent when an error code is seen.


Category: *Network*

*Enabled by Default*


**Lateral Movement Detection**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for unusual traffic behaviour



**No Data Exchanged**
~~~~~~~~~~~~~~~~~~~~~

Checks for no data exchange.

When the sending TCP wants to establish connections, it sends a segment called a SYN to the peer TCP protocol running on the receiving host. The receiving TCP returns a segment called an ACK to acknowledge the successful receipt of the segment. The sending TCP sends another ACK segment, then proceeds to send the data.

The alert is sent when flow ends with no data exchanged.


**TCP Retransmission Issues**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for TCP retransmissions and packet lost issues.

The most common cause of Network Packet Loss are:

    • Layer two errors
    • or network congestion


TCP retransmission means resending packets over the network that have been lost or previously damaged.

The alert is sent when tcp retrasmission or packet loss are seen.

Category: *Network*

*Enabled by Default


**Zero TCP Window**
~~~~~~~~~~~~~~~~~~~

Checks for zero TCP window.

When the receiver has a full buffer, the window size is reduced to zero. In this state, the window is shown to be 'Frozen' and the sender cannot send any more bytes until it receives a datagram from the receiver with a window size greater than zero.

The alert is sent when zero TCP window is detected.

Category: *Network*

*Enabled by Default*


**Numeric IP Address**
~~~~~~~~~~~~~~~~~~~~~~~~
 
Checks for numeric IP address

When contacting the website using an IP address instead of it’s domain name (1.2.3.4 instead of www.bbc.com)

(hppt/dsn troubles)


The alert is sent when numeric IP is detected.


*Category:Cybersecurity*

*Enabled by Default*

**Detects anomalies in active flows numbers**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for anomalies in active Flows.

This is a machine learning check. Based on a specific algorithm that forecasts behavioural flow anomalies. The algorithm is able to predict the average of active flows in certain period of time, lower or upper boundaries are not established but calculated by the algorithm.

Alert is sent when the anomaly in active flow is detected.



*Category:Cybersecurity*

*Enabled by Default*



**Suspicious Entropy**
~~~~~~~~~~~~~~~~~~~~~~

Checks for suspicious entropy.

In case of files analysis whether they contain embedded files or scripts, and the entropy scores.

The file entropy score, which measure the randomness of data and is used to find encrypted malware, and the entropy distribution also clearly shows that a portion/size of the file is not what it should be. Further analysis proves that this file contains a new form of malware that passed undetected by existing security measures and was responsible for the infected systems.

Alert is sent when suspicious entropy is seen.

*Category:Cybersecurity*

*Enabled by Default*


**Long Lived**
~~~~~~~~~~~~~~~
 
Checks for long lived flows.
 
The TCP source will keep sending as much data as it can for the transmission link and once congestion is occuring TCP congestion mechanism will come into play,TCP always initiate the congestion avoidance mechanism and slow-start if buffers get over-filled or output capacity of a router in the chain is smaller that the sum of its inputs.
 
An alert is sent when a flow lasts more than the configured duration.

*Category:Cybersecurity*

*Enabled by Default*


**Not Purged**
~~~~~~~~~~~~~~

Checks for bugs in the flow pure logic.
 
Purging is the process of freeing up space in the database or deleting obsolete data that is not required by the system. The purge process can be based on the age of the data or the type of data.
Data purging is a mechanism that permanently deletes inactive or obsolete records from the database. 

Sends the alert in case of bugs in the flow pure logic.


*Category:Cybersecurity*

*Enabled by Default*





