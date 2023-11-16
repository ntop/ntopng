.. _BasicConceptsStats:

Statistics
##########

ntopng computes statistics during its execution. Statistics are then shown in the UI and also written as historical timeseries. They include, but are not limited to

  - bytes sent and received
  - throughput

Statistics are computed for hosts, interfaces, autonomous systems, and other network elements.

Rates
=====

Some statistics are expressed as rates. Consequently, they are meaningful only with reference to a time interval. An example is the throughput, expressed in bits per second (bit/s), bytes per second (B/s), or other bit multiples but always expressed with reference to the unit of time /s.

To calculate rates, including the throughput, ntopng keeps track of values across consecutive time snapshots, then it computes the difference between consecutive values, and finally divides the difference by the lenght of the time interval. 

Time Snapshots
--------------

To track values across consecutive snapshots, ntopng visits network elements periodically. Visits are approximately every 5 seconds for packet interfaces, whereas are slower for ZMQ interfaces. The reason is that, when processing packets, it is possible to reach a higher accuracy as the traffic is seen as it passes `on the wire`.

.. note::
   When working with ZMQ interfaces, ntopng receive flows and it vists elements with a variable frequency that is the maximum between nProbe :code:`-t <lifetime timeout>` and :code:`-d <idle timeout>`. 

Therefore, it is possible to adjusts those timeouts to change how fast ntopng computes snapshots. nProbe timeouts are discussed in details at https://www.ntop.org/guides/nprobe/case_study/flow_collection.html.

Example
-------

For example, if the total host traffic at time :code:`t=10` is :code:`500 B`, and the total host traffic at time :code:`t=20` is :code:`1000 B`, ntopng will compute the host throughput as `(1000 - 500)`  divided by `(20 - 10)`, i.e.,  `500 / 10 = 50 B/s`. 

