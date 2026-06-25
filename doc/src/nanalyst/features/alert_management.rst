.. _nAnalystAlertManagement:

Alert Management
================

nAnalyst can investigate, contextualise, and suppress alerts without requiring the analyst to manually correlate data across multiple views.

Alert investigation
--------------------

When an alert fires, you can ask nAnalyst to explain it:

.. code-block:: text

   "Why did host 10.0.1.20 trigger a port scan alert?"

   "Is the DNS tunnelling alert on 192.168.5.3 a false positive?"

nAnalyst will:

1. Retrieve the alert details and associated flows
2. Pull historical traffic context for the involved hosts
3. Cross-reference with the asset inventory and known good behaviour
4. Return an explanation with supporting evidence

Alert suppression (silencing)
-------------------------------

For alerts that are confirmed false positives or known-good behaviour, nAnalyst can create exclusions directly from the chat:

.. code-block:: text

   "Silence the certificate expiry alert for internal.corp.example.com"

   "Add an exclusion for the domain alert on cdn.vendor.com"

Supported exclusion types:

- **Host alert exclusions** — suppress a specific alert type for a given host
- **Domain alert exclusions** — suppress alerts triggered by a known-good domain
- **Certificate alert exclusions** — suppress TLS certificate warnings for internal or known hosts

All exclusions are recorded in the audit log with the responsible user and the reason provided.

Incident response workflow
--------------------------

A typical AI-assisted incident workflow with nAnalyst:

1. Alert fires in ntopng
2. Analyst asks nAnalyst: *"Investigate this alert"*
3. nAnalyst pulls flows, host history, and geolocation data
4. Evidence log is assembled and shown
5. nAnalyst suggests: confirm malicious → create policy; or confirm benign → silence alert
6. Analyst approves the action; nAnalyst executes it
7. Action is recorded in the audit log
