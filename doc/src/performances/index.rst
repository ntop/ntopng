Performances
############

Flow Collection
===============

When ntopng collects flows from nProbe, it is expected to process, without drops, up to

- 36 Kfps per interface with two interfaces (with or without an interface view)
- 22,2 Kfps per interface with four interfaces (with or without an interface view)

Tests have been executed on an Intel(R) Xeon(R) CPU E3-1230 v5 @ 3.40GHz with 16GB RAM.

The same figures are expected to be obtained also when nIndex :ref:`Flows Dump` is enabled.

