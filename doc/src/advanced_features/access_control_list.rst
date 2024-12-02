Access Control List
===================

ntopng is able to define an Access Control List, used to trigger an alert in case one of the defined rules is not respected.

.. note::

  This feature is available with at least Enterprise L License.

.. note::

  This feature is available only if the ACL Violation alert is enabled.

Configuration
#############

To enable this feature, first enable the ACL Violation alert.
There are two alerts for this feature:
 - ACL Violation (ARP), for ARP traffic.
 - ACL Violation (ICMP/TCP/UDP), for ICMP/TCP/UDP traffic.

.. note::

  Even if a rule is set but the alert is not enabled, no alert is going to be emitted by ntopng.

.. figure:: ../img/acl_violation_alert.png
  :align: center
  :alt: ACL Violation alert

  ACL Violation alert

After enabling the alert, a new entry, called Access Control List, in the Settings section is going to be available, click there to jump to the Access Control List page.

.. figure:: ../img/acl_page.png
  :align: center
  :alt: Access Control List

  Access Control List

Adding Rules
############

By clicking on the `+` button it is possible to Add a new Rule. By clicking on the action column instead of an already existing rule it is possible to Edit / Delete the rule.

.. figure:: ../img/add_acl_rule_modal.png
  :align: center
  :alt: Add Rule

  Add Rule

From here it is possible to configure a rule.
Click on the `Advanced Settings` to jump to a text-like field, where it is possible to directly write the rule. Each rule must be put on a newline, so one rule per line; each field must be
separated by a `;`
 - PROTOCOL;CLIENT;SERVER;PORT|APPLICATION

All parameters are mandatory except in some cases:
 - ARP protocol: in case of ARP protocol only the Protocol and Client MAC are to be added (ARP has FF:FF:FF:FF:FF:FF as Server);
 - TCP/UDP protocol: in case of these two protocols, PORT|APPLICATION are mandatory and only one of the two can be specified (application in text-like format, e.g. HTTP);
 - Other protocols: for all other protocols only the Protocol, Client IP and Server IP are required

.. note::

  PORT|APPLICATION are only available for the TCP/UDP protocols

It is not recommended to use the Advanced Settings if not for special cases, because in the other case all the controls are handled by ntopng.
It is moreover possible to add multiple rules in a single add, by clicking the `+` below the last rule; it is possible to remove a rule instead by clicking the trash icon.

Editing Rules
#############

It is possible to edit an existing rule by clicking on the Action button and selecting `Edit`. The modal is the same as the Add, following the same rules; the only difference is that it's not possible to access the Advanced Settings feature.

.. figure:: ../img/edit_acl_rule.png
  :align: center
  :alt: Edit Rule

  Edit Rule

Delete Rules
############

It is instead possible to delete rules, like for the Edit, by clicking on the Action button and selecting `Delete`. Other than that it's possible to delete all the rules by clicking on the red button `Delete All Rules` below the table.

Alert
#####

After configuring everything, ntopng is going to start checking for flows not respecting the set rules and trigger the alerts;

.. figure:: ../img/acl_violation_alert_flow.png
  :align: center
  :alt: Flow Alert (ICMP/TCP/UDP)

  Flow Alert (ICMP/TCP/UDP)

.. figure:: ../img/acl_violation_alert_mac.png
  :align: center
  :alt: MAC Alert (ARP)

  MAC Alert (ARP)