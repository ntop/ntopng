Remediations for nDPI Risks
###########################

.. _Risk 005:
   
KNOWN PROTOCOL ON NON STANDARD PORT
===================================

#. **Description**:  Known protocol detected on a non-standard port.
#. **Possible attacks**: The detection of this risk in deep packet inspection indicates unconventional network activity, which can be used for evading firewall rules, data exfiltration, or launching DDoS attacks through unexpected ports.
#. **Remediation**: When detected, review firewall configurations to ensure that known protocols are only allowed on standard ports and implement intrusion detection/prevention systems (IDS/IPS) to monitor for anomalous network traffic on non-standard ports. Additionally, consider using a whitelist approach to limit the list of accepted applications and their corresponding ports.

.. _Risk 006:
   
TLS SELFSIGNED CERTIFICATE
==========================

#. **Description**:  A self-signed TLS certificate is one that has been created and signed by the same entity responsible for the domain being secured. This can be a potential security risk as these certificates are not verified by any trusted Certificate Authority (CA).
#. **Possible attacks**: The detection of this risk in deep packet inspection signals a problem in the monitored network, as self-signed TLS certificates can allow for man-in-the-middle (MitM) attacks. Attackers can intercept and modify communications, since the certificate is not verified by a trusted third party.
#. **Remediation**: When detected, the remediation for this risk involves validating the necessity of using self-signed certificates. If they are indeed required (e.g., for internal testing purposes), implement a proper Certificate Authority (CA) and enforce its use to avoid MitM attacks. For production environments, always use trusted CA-signed certificates to ensure secure TLS communications.

.. _Risk 007:   
  
TLS OBSOLETE VERSION
====================

#. **Description**:  Detection of an outdated Transport Layer Security (TLS) version in use, potentially exposing the monitored network to vulnerabilities.
#. **Possible attacks**: The use of obsolete TLS versions can be exploited by attackers using known vulnerabilities that have been patched in newer versions, leading to data breaches or man-in-the-middle attacks.
#. **Remediation**: To secure the monitored network when this risk is detected, it's recommended to update the TLS version to a more recent and secure one as soon as possible. This can typically be done by applying relevant security patches for the affected software or hardware components. Additionally, implementing stricter TLS protocol policies such as disabling older versions entirely can help protect against attacks leveraging obsolete TLS versions.

.. _Risk 008:
   
TLS WEAK CIPHER
===============

#. **Description**:  Use of weak encryption ciphers in Transport Layer Security (TLS) connections.
#. **Possible attacks**: The use of weak ciphers can make the data transmitted vulnerable to eavesdropping, man-in-the-middle attacks, or decryption by unauthorized entities.
#. **Remediation**: Update TLS libraries and configurations to disable weak encryption algorithms (such as RC4) and enforce the use of stronger, more secure ciphers (e.g., AES 128 GCM, ECDHE RSA with P-256). Regularly monitor for and apply updates to keep up with changes in security best practices and vulnerabilities discovered in encryption algorithms.

.. _Risk 009:

TLS CERTIFICATE EXPIRED
=======================

#. **Description**:  A TLS certificate has expired, potentially allowing for unauthenticated connections.
#. **Possible attacks**: Detection of this risk indicates that a man-in-the-middle attack or data interception could occur due to the use of an outdated or invalid certificate. Unsecured communication could lead to sensitive data being exposed.
#. **Remediation**: Update the expired TLS certificate as soon as possible, ensuring it is issued by a trusted Certificate Authority (CA). If the certificate cannot be updated immediately, consider disabling the service that uses this expired certificate or implementing alternative secure communication methods temporarily. Additionally, monitor network traffic for any suspicious activity and investigate any potential breaches.

.. _Risk 097:
   
TLS CERTIFICATE MISMATCH
========================

#. **Description**:  A TLS certificate mismatch occurs when the server presents a different SSL/TLS certificate than expected during the TLS handshake process.
#. **Possible attacks**: The detection of this risk in deep packet inspection signals a problem in the monitored network, as it may indicate a man-in-the-middle (MitM) attack or an unintended use of self-signed certificates. In either case, data being transmitted could be intercepted and potentially modified.
#. **Remediation**: When this risk is detected, administrators should investigate the source of the TLS certificate mismatch. If it's a MitM attack, affected connections should be terminated immediately. If the issue is due to an unintended use of self-signed certificates, consider implementing proper digital certificate management and revoke the current self-signed certificate. Additionally, ensure that all clients trust the newly installed certificate or update them with the new one.

