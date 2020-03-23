Introduction
============

One of the greatest strengths of ntopng is its extensibility. By means
of plugins, functionalities of ntopng can be extended in a fast and easy
way, with just basic coding skills.

A plugin is a collection of scripts with
a predefined structure that enables ntopng to perform things such as
executing certain actions at the right point in time or when a certain
event occurs.

Plugins can watch and analyze network traffic, flows, hosts and
other network elements. In addition, plugins can monitor the health and status
of ntopng itself, as well as keep an eye on the system on top of which
ntopng is running.

Examples of plugins are:

- A `flood
  detection <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/flow_flood>`_
  plugin to trigger alerts when hosts or networks are generating too
  many traffic flows
- A `blacklisted flows
  <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted>`_
  plugin to detect flows involving malware or suspicious clients or servers
- A `monitor for the disk space
  <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/disk_monitor>`_
  which continuously observes free disk space and triggers alerts when the
  space available is below a certain threshold

ntopng community plugins are opensource and available on the `ntopng
GitHub plugins page
<https://github.com/ntop/ntopng/tree/dev/scripts/plugins>`_.

Plugins are written in Lua, so contributors don't have to know anything about
the internal ntopng engine to
create their own scripts and contribute them to the community.
