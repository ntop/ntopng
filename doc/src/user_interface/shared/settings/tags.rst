.. _Tags:

Tags
----

Tags are colored labels that can be attached to hosts and are used to group,
identify or annotate assets on the monitored network. A host can carry one or 
more tags. They are shown as colored badges next to the host through the UI,
and can be used to filter which alerts get delivered to a given notification 
recipient.

Internally, tags are implemented as a 64-bit bitmap associated with each
host, thus the number of available tags is:

- 32 (**Bits 0-31**) reserved for **built-in tags**, which ntopng assigns
  automatically based on what it observes on the network.
- 32 (**Bits 32-63**) for **user-defined tags**, which administrators
  create, name and assign manually.

Both kinds of tags are managed from the same *Tags* page, reachable from the
Settings section of the System interface, which lists every tag together
with its name, color and description.

Built-in Tags
^^^^^^^^^^^^^

Built-in tags are read-only: their name and description cannot be changed
(the corresponding fields are disabled in the edit dialog), although their
color can still be customized to fit personal preference. They cannot be
deleted, and there is no "reset" action for them as there is nothing
user-provided to revert.

ntopng currently defines the following built-in tags:

.. list-table::
  :header-rows: 1
  :widths: 25 75

  * - Tag
    - Assigned when...
  * - DNS Server
    - the host is configured as a DNS server, or has been observed acting as one
  * - NTP Server
    - the host is configured as an NTP server, or has been observed acting as one
  * - DHCP Server
    - the host is configured as a DHCP server, or has been observed acting as one
  * - SMTP Server
    - the host is configured as an SMTP server, or has been observed acting as one
  * - Network Gateway
    - the host is configured as a network gateway
  * - IMAP Server
    - the host has been observed acting as an IMAP server
  * - POP Server
    - the host has been observed acting as a POP server
  * - HTTP Server
    - the host has been observed acting as an HTTP server
  * - SSH Server
    - the host has been observed acting as an SSH server
  * - RDP Server
    - the host has been observed acting as an RDP server
  * - Modbus Server
    - the host has been observed acting as a Modbus (ICS/SCADA) server
  * - S7comm Server
    - the host has been observed acting as a Siemens S7comm (ICS/SCADA) server
  * - Profinet Server
    - the host has been observed acting as a Profinet (ICS/SCADA) server
  * - Non PQC Compliant
    - a TLS flow to/from the host has been detected using cryptography that
      is not resistant to quantum computer attacks (Post-Quantum Cryptography)

The first five tags (DNS/NTP/DHCP/SMTP Server and Network Gateway) are
assigned either because the host has been explicitly configured as such
(under `Network Configuration`_) or because ntopng has observed it providing
that service on the network. The remaining server tags (IMAP, POP, HTTP,
SSH, RDP, Modbus, S7comm, Profinet) are assigned purely based on traffic
observation. The *Non PQC Compliant* tag is instead set the first time a
flow risk is raised on a TLS connection indicating non-Post-Quantum-safe
cryptography, and it is applied to whichever of the client/server hosts is
responsible for it.

Built-in tags are computed on the fly and are **not** persisted to disk:
they always reflect the current state of the host.

.. _Network Configuration: ../policies/network_configuration.html

User-Defined Tags
^^^^^^^^^^^^^^^^^

User-defined tags consists of customizable tag slots that administrators can
freely name, color and describe from the *Tags* page. By default they are
named ``Customizable_Tag_32`` .. ``Customizable_Tag_63``, with no color
and an empty description, until edited.

From the *Tags* page, clicking the edit (gear) icon on a tag opens a dialog
where the following can be changed:

- **Name**: alphanumeric, no spaces, at least 2 characters long.
- **Color**: the badge color used to render the tag everywhere in the UI.
- **Description**: a free-text field to explain the purpose of the tag.
- **Applications**: one or more network applications that automatically
  tag matching flows and hosts with this tag (Enterprise L or above). See
  `Application-Based Tagging`_ below.

A user-defined tag can be reverted to its factory defaults (default name,
black color, empty description) using the **Reset** action, which also
removes it from any host it was assigned to.

Unlike built-in tags, user-defined tags are not computed automatically:
they must be explicitly assigned to a host from that host's configuration
page (*Host Details -> Config*), where a *User Defined Tags* multi-select
lists all the available user-defined tags. The selection is stored
persistently, keyed by the host MAC address (for hosts with a known/local
MAC) or by IP address and VLAN otherwise, so the assignment survives
ntopng restarts and, for MAC-keyed hosts, host IP address changes (e.g. via
DHCP).

Application-Based Tagging
^^^^^^^^^^^^^^^^^^^^^^^^^

.. note::
  Enterprise L license or above is required

In addition to manual assignment, a user-defined tag can be bound to one
or more network applications (i.e. nDPI protocols) directly from the tag
edit dialog. Once one or more applications are associated with a tag,
ntopng starts tagging automatically: every time a flow is classified as
one of the linked applications, the flow itself is immediately tagged, and
the same tag is persistently assigned to the flow's local client host,
exactly as if it had been set by hand from that host's configuration page.

From that moment on the tag behaves just like any other user-defined tag
and is visible wherever tags normally appear: on the matching flows in the
Live Flows and Historical Flows pages, on the client host in the Hosts and
Host Details pages and, being now an ordinary host tag, on the
corresponding entry in the assets database - so the Assets page can be
filtered by that tag to list every asset that has been observed using the
linked application(s).

This effectively turns a tag into a standing rule ("tag every host that
talks a given application") that is kept up to date automatically, rather
than a one-off manual annotation, making it a convenient way to build an
inventory of hosts by behavior rather than by identity.

**Example**: a network administrator wants to spot which PCs on the LAN
are still accessing mail servers in plaintext instead of over the
encrypted protocols the same mail server also supports - typically a sign
of a misconfigured or outdated mail client. They edit tag 33, rename it to
``UnsafeMail``, and associate it with the ``IMAP``, ``POP3`` and ``SMTP``
applications, leaving their encrypted counterparts (``IMAPS``, ``POPS``,
``SMTPS``) untagged. From that point on, every flow using one of the
plaintext mail protocols is automatically tagged ``UnsafeMail``, and so is
the host that generated it. The administrator can then open the Assets
page, filter by the ``UnsafeMail`` tag, and get an always up-to-date list
of the misconfigured PCs to fix, without having to hunt for them manually
in the flow tables.

Tags on Flows
^^^^^^^^^^^^^

Flow tags are computed as the union of the **user-defined** tags currently
assigned to its client and server hosts. Built-in (host-only) tags, such
as *DNS Server* or *Non PQC Compliant*, are not propagated to flows: they
only describe the host itself, and would otherwise appear on every single
flow involving that host, which would not be very informative (e.g. DNS
server).

In addition, a flow classified as an application bound to a tag (see
`Application-Based Tagging`_) is tagged directly as soon as it is
detected, regardless of the client/server union described above.

Where Tags Are Shown
^^^^^^^^^^^^^^^^^^^^

Tags (both built-in and user-defined) are displayed as colored badges in
several places across the UI:

- On the **Host Details** page, in the host summary table.
- In the **Flow Alerts** and **Host Alerts** tables, in a dedicated *Tags*
  column. Since alerts are historical records, the tags shown are the ones
  that were active on the host/flow at the time the alert was generated,
  not the current ones.
- On the **Assets** page, as part of each asset's details: user-defined
  tags assigned to a host, manually or through
  `Application-Based Tagging`_, are propagated to its corresponding entry
  in the assets database.

Tags can also be used to filter traffic and assets across the UI (e.g. in
the Flows and Historical Flows, the Alerts Explorer, and the Assets page).

Using Tags for Notifications
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Tags can be used as an additional delivery criterion when configuring a
notification :ref:`Recipient <AvailableEndpoints>`, alongside Severity,
Alert Category, Check Entity and Host Pool. When one or more tags are
selected for a recipient, only Flow and Host alerts whose related host (the
client and/or server host, for flow alerts) carries at least one of the
selected tags are delivered to that recipient; all other alerts are
filtered out for it. If no tag is selected (the default), no tag-based
filtering is applied and alerts are delivered regardless of their tags.

This makes it possible, for example, to tag a set of business-critical
hosts and configure a dedicated, high-priority recipient (e.g. a Slack
channel or a PagerDuty integration) that only receives alerts related to
those tagged hosts, while routing the rest of the alerts elsewhere.
