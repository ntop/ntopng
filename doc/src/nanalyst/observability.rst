.. _nAnalystObservability:

Observability
=============

nAnalyst provides two dedicated observability surfaces: usage statistics for cost and token tracking, and an action audit log for accountability. Together they give administrators full visibility into how the AI assistant is being used and what it has done.

.. toctree::
   :maxdepth: 1

   features/usage_stats
   features/audit_log

Summary
-------

+---------------------+--------------------------------------------+---------------------------------------+
| Surface             | What it shows                              | Primary audience                      |
+=====================+============================================+=======================================+
| Usage Statistics    | Tokens, costs, models, users, sessions     | Administrators, budget owners         |
+---------------------+--------------------------------------------+---------------------------------------+
| Action Audit Log    | Tool calls, actors, initiators, payloads   | Security team, compliance, SOC        |
+---------------------+--------------------------------------------+---------------------------------------+

The two surfaces complement each other: usage stats answer *how much* nAnalyst is being used and at what cost, while the audit log answers *what* nAnalyst did and *who* directed it.
