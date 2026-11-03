.. _Containers:

Pods and Containers
-------------------

When the flows of an interface carry container information (for example flows exported by nProbe
with the eBPF or Kubernetes extensions), ntopng shows the Kubernetes pods and the containers (Docker or
Kubernetes) they belong to. The page has two tabs, *Pods* and *Containers*, and refreshes every 10 seconds.
You reach it from the pod and container names shown in the flows.

Each row shows:

- The pod name, or the container name (its Kubernetes or Docker name, otherwise its id)
- For pods, the number of containers of the pod
- The flows in which the pod or container is the client and the server
- The average round trip time (RTT, how long a packet takes to go and come back) and its variance, as client and as server

The actions button of a row opens:

- *Live Flows*: the active flows of the pod or container
- *Containers* (pods only): the containers of that pod; the page title then shows the pod name
- *Timeseries*: the charts of the pod or container over time
