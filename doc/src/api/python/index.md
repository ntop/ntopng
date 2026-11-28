---
title: "Python API"
description: "ntopng provides a Python 3 API for querying the engine and retrieve traffic information by using the Python language."
outline: [2, 3]
lastUpdated: 2025-02-17T12:19:21+01:00
---
# Python API {#python-api}

ntopng provides a Python 3 API for querying the engine and retrieve traffic information by using the Python language.

The API is based on the ntopng REST API and it allows users to perform operations such as:

- Read host statistics
- Get the active flows list
- Query network interface stats
- Search historical flows

For each ntopng component there is a corresponding Python class (Host, Interface, Historical), and for each REST API call there is a corresponding method.
The ntopng class is used to keep information about the ntopng configuration including IP address and credentials required to connect.

## Prerequisites {#prerequisites}

The API is using Pandas and NumPy for working with time series data, plotly and fpdf for generating reports in PDF format, and a few additional libraries.

```bash
pip3 install -r requirements.txt
```

## Installation {#installation}

For you convenience, ntop periodically builds pip packages. You can install the latest available package as:

```bash
pip3 install ntopng
```

## Examples {#examples}

A few sample applications are distributed with the ntopng source code and are available at <https://github.com/ntop/ntopng/tree/dev/python/examples>

All the examples require:

- ntopng URL (-n option, *localhost:3000* by default)
- ntopng credentials
  : - ntopng user (-u option, *admin* by default) and ntopng password (-p option, *admin* by default)
    - or ntopng Token (<https://www.ntop.org/guides/ntopng/user_interface/shared/settings/preferences.html#token-based-authentication>)

Some of the examples also require an ntopng interface ID (-i option) and additional parameters (e.g. host).

Example:

```bash
python3 alerts.py -n http://localhost:3000 -i admin -p password -i 0
```

This sample application is printing alert statistics, please see below a code snippet for achieving the same:

```python
# Connect to ntopng using the Ntopng class
my_ntopng = Ntopng(username, password, auth_token, ntopng_url)

# Get an Historical instance for a specific interface by ID
my_historical = my_ntopng.get_historical_interface(iface_id)

# Read alert statistics
data = my_historical.get_alerts_stats(epoch_begin, epoch_end)

# Print the raw statistics
print(data)
```

## API {#api}

<a id="module-ntopng"></a>
<a id="module-interface"></a>
<a id="module-host"></a>
<a id="module-historical"></a>
ntopng provides a Python 3 API for querying the engine and retrieve traffic information by using the Python language.

The API is based on the ntopng REST API and it allows users to perform operations such as:

* Read host statistics
* Get the active flows list
* Query network interface stats
* Search historical flows

For each ntopng component there is a corresponding Python class (Host, Interface, Historical), and for each REST API call there is a corresponding method.
The ntopng class is used to keep information about the ntopng configuration including IP address and credentials required to connect.

## Prerequisites

The API is using Pandas and NumPy for working with time series data, plotly and fpdf for generating reports in PDF format, and a few additional libraries.

```python
pip3 install -r requirements.txt
```

## Installation

For you convenience, ntop periodically builds pip packages. You can install the latest available package as:

```python
pip3 install ntopng
```

## Examples

A few sample applications are distributed with the ntopng source code and are available at <https://github.com/ntop/ntopng/tree/dev/python/examples>

All the examples require:

* ntopng URL (-n option, *localhost:3000* by default)
* ntopng credentials
  :   + ntopng user (-u option, *admin* by default) and ntopng password (-p option, *admin* by default)
      + or ntopng Token (<https://www.ntop.org/guides/ntopng/user_interface/shared/settings/preferences.html#token-based-authentication>)

Some of the examples also require an ntopng interface ID (-i option) and additional parameters (e.g. host).

Example:

```python
python3 alerts.py -n http://localhost:3000 -i admin -p password -i 0
```

This sample application is printing alert statistics, please see below a code snippet for achieving the same:

```python
# Connect to ntopng using the Ntopng class
my_ntopng = Ntopng(username, password, auth_token, ntopng_url)

# Get an Historical instance for a specific interface by ID
my_historical = my_ntopng.get_historical_interface(iface_id)

# Read alert statistics
data = my_historical.get_alerts_stats(epoch_begin, epoch_end)

# Print the raw statistics
print(data)
```

## API

### Ntopng

The Ntopng class stores information for accessing the ntopng instance (IP and credentials)
and provides global traffic information and constants (interfaces, alert types, etc).

class ntopng.Ntopng(*username=None*, *password=None*, *auth\_token=None*, *url='http://localhost:3000'*)
:   Ntopng provides information about global data (e.g. list of interfaces) and consts (e.g. alert types)

    Parameters:
    :   **ntopng\_obj** – The ntopng handle

    get\_alert\_severities()
    :   Return all severities

        Returns:
        :   The list of severities

        Return type:
        :   array

    get\_alert\_types()
    :   Return all alert types

        Returns:
        :   The list of alert types

        Return type:
        :   array

    get\_historical\_interface(*ifid*)
    :   Return an Historical handle for an interface

        Parameters:
        :   **ifid** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The interface ID

        Returns:
        :   The historical handle

        Return type:
        :   ntopng.Historical

    get\_host\_interfaces\_list(*host*)
    :   Return all ntopng interfaces for a given host

        Parameters:
        :   **host** (*string*) – The host

        Returns:
        :   List of interfaces

        Return type:
        :   array

    get\_interface(*ifid*)
    :   Return an Interface instance

        Parameters:
        :   **ifid** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The interface ID

        Returns:
        :   The interface instance

        Return type:
        :   ntopng.Interface

    get\_interfaces\_list()
    :   Return all available interfaces

        Returns:
        :   The list of interfaces

        Return type:
        :   array

### Interface

The Interface class can be used to access information about interface statistics through the
REST API (<https://www.ntop.org/guides/ntopng/api/rest/api_v2.html>).

class interface.Interface(*ntopng\_obj*, *ifid*)
:   Interface provides information about a Network interface

    Parameters:
    :   * **ntopng\_obj** – The ntopng handle
        * **ifid** – The interface ID

    get\_active\_flows\_paginated(*currentPage*, *perPage*)
    :   Retrieve the (paginated) list of active flows for the specified interface

        Parameters:
        :   * **currentPage** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The current page
            * **perPage** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The number of results per page

        Returns:
        :   All active flows

        Return type:
        :   array

    get\_active\_hosts(*ifid\_num*)
    :   Return all active hosts on the selected interface

        Returns:
        :   Active hosts on the selected interface

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_active\_l4\_proto\_flow\_counters()
    :   Return statistics about active flows per Layer 4 protocol on an interface

        Returns:
        :   Layer 4 protocol flows statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_active\_l7\_proto\_flow\_counters()
    :   Return statistics about active flows per Layer 7 protocol on an interface

        Returns:
        :   Layer 7 protocol flows statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_address()
    :   Return the interface IP address(es)

        Returns:
        :   The interface address(es)

        Return type:
        :   array

    get\_alert\_severities\_enum()
    :   Return the enum for all the alert severities

        Returns:
        :   Alert severity enum

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_alert\_types\_enum()
    :   Return the enum for all the alert types

        Returns:
        :   Alert types enum

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_alerts\_counter\_per\_severity(*ifid\_num*)
    :   Return the number of alerts for each severity value

        Returns:
        :   Number of alerts for each severity value

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_alerts\_counter\_per\_type(*ifid\_num*)
    :   Return the number of alerts for each alert type

        Returns:
        :   Number of alerts for each alert type

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_all\_active\_hosts()
    :   Retrieve the list of active hosts for the specified interface

        Returns:
        :   All active hosts

        Return type:
        :   array

    get\_all\_alerts(*ifid*, *epoch\_begin*, *epoch\_end*, *ip=None*)
    :   Return all the flow alerts of the specified interface between epoch\_begin and epoch\_end.
        The REST returns at most 1000 alerts per request: they are read page by page

        Returns:
        :   Flow alerts for the specified IP (if present): {“records”: […], “stats”: {…&#125;&#125;

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_broadcast\_domains()
    :   Return information about broadcast domains on an interface

        Returns:
        :   Information about broadcast domains

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_data()
    :   Return information about a Network interface

        Returns:
        :   Information about the interface

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_dscp\_stats()
    :   Return statistics about DSCP

        Returns:
        :   DSCP statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_historical()
    :   Return an Historical handle for the interface

        Returns:
        :   The historical handle

        Return type:
        :   ntopng.Historical

    get\_host(*ip*, *vlan=None*)
    :   Return an Host instance

        Parameters:
        :   * **ifid** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The interface ID
            * **ip** (*string*) – The host IP address
            * **vlan** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The host VLAN ID (if any)

        Returns:
        :   The host instance

        Return type:
        :   ntopng.Host

    get\_host\_data(*ifid\_num*, *host\_ip*)
    :   Return all host data for the selected interface and IP

        Returns:
        :   Host data for the specified interface and IP address

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_l4\_protocols\_enum()
    :   Return the enum for L4 protocols

        Returns:
        :   Enum for L4 protocols

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_l7\_application\_category\_enum()
    :   Return the enum for L7 application category enum

        Returns:
        :   Enum for L7 application category enum

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_l7\_application\_proto\_enum()
    :   Return the enum for L7 application enum

        Returns:
        :   Enum for L7 application enum

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_l7\_stats(*max\_num\_results*)
    :   Return statistics about Layer 7 protocols seen on an interface

        Parameters:
        :   **max\_num\_results** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The maximum number of results to limit the output

        Returns:
        :   Layer 7 protocol statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_top\_local\_talkers()
    :   Return Top Local hosts generating more traffic

        Returns:
        :   The top local hosts

        Return type:
        :   array

    get\_top\_remote\_talkers()
    :   Return Top Remote hosts generating more traffic

        Returns:
        :   The top remote hosts

        Return type:
        :   array

### Host

The Host class can be used to access information about an host through the
REST API (<https://www.ntop.org/guides/ntopng/api/rest/api_v2.html>).

class host.Host(*ntopng\_obj*, *ifid*, *ip*, *vlan=None*)
:   Host provides information about hosts

    Parameters:
    :   **ntopng\_obj** – The ntopng handle

    get\_active\_flows\_paginated(*currentPage*, *perPage*)
    :   Retrieve the (paginated) list of active flows for the specified interface and host

        Parameters:
        :   * **currentPage** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The current page
            * **perPage** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – The number of results per page

        Returns:
        :   All active flows

        Return type:
        :   array

    get\_dscp\_stats(*direction\_rcvd*)
    :   Return statistics about DSCP per traffic direction for an host

        Parameters:
        :   **direction\_rcvd** (*boolean*) – The traffic direction (True for received traffic, False for sent)

        Returns:
        :   DSCP statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_host\_data()
    :   Return all available information about a single host

        Returns:
        :   Information about the host

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_l7\_stats()
    :   Return statistics about Layer 7 protocols for the host

        Returns:
        :   Layer 7 protocol statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

### Historical

The Historical class can be used to retrieve historical traffic data through the
REST API (<https://www.ntop.org/guides/ntopng/api/rest/api_v2.html>).

class historical.Historical(*ntopng\_obj*, *ifid=None*)
:   Historiacl provides access to historical information including flows and alerts

    Parameters:
    :   **ntopng\_obj** – The ntopng handle

    get\_active\_monitoring\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_alert\_severity\_counters(*epoch\_begin*, *epoch\_end*)
    :   Return statistics about the number of alerts per alert severity

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_alert\_type\_counters(*epoch\_begin*, *epoch\_end*)
    :   Return statistics about the number of alerts per alert type

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Statistics

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_alerts(*alert\_family*, *epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Run queries on the alert database

        Parameters:
        :   * **alert\_family** (*string*) – The alert family (flow, host, interface, etc)
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_alerts\_stats(*epoch\_begin*, *epoch\_end*, *host=None*)
    :   Return flow alerts stats

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **host** (*string*) – Host IP address (optional)

        Returns:
        :   Flow alert stats

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_flow\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return flow alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_flow\_alerts\_stats(*epoch\_begin*, *epoch\_end*)
    :   Return flow alerts stats

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Flow alert stats

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_flows(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Run queries on the historical flows database (ClickHouse)

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_host\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return host alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_host\_timeseries(*host\_ip*, *ts\_schema*, *epoch\_begin*, *epoch\_end*)
    :   Return timeseries data in a pandas DataFrame for a specified interface and host

        Parameters:
        :   * **host\_ip** – The host IP
            * **ts\_schema** (*string*) – The timeseries schema
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Timeseries data

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)") (pandas DataFrame)

    get\_host\_timeseries\_stats(*host\_ip*, *ts\_schema*, *epoch\_begin*, *epoch\_end*)
    :   Return timeseries statistics

        Parameters:
        :   * **host\_ip** – The host IP
            * **ts\_schema** (*string*) – The timeseries schema
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Timeseries data

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)") (pandas DataFrame)

    get\_host\_top\_protocols(*host*, *epoch\_begin*, *epoch\_end*)
    :   Return Top protocols for an host

        Parameters:
        :   * **host** (*string*) – Host IP address
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Top protocols

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_interface\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return interface alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_interface\_timeseries(*ts\_schema*, *epoch\_begin*, *epoch\_end*)
    :   Return timeseries data in a pandas DataFrame for a specified interface

        Parameters:
        :   * **ts\_schema** (*string*) – The timeseries schema
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Timeseries data

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)") (pandas DataFrame)

    get\_interface\_timeseries\_stats(*ts\_schema*, *epoch\_begin*, *epoch\_end*)
    :   Return timeseries statistics

        Parameters:
        :   * **ts\_schema** (*string*) – The timeseries schema
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Timeseries data

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)") (pandas DataFrame)

    get\_mac\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return MAC alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_network\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return Network alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_snmp\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return SNMP alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_system\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return System alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_timeseries(*ts\_schema*, *ts\_query*, *epoch\_begin*, *epoch\_end*)
    :   Return timeseries in a pandas DataFrame for a specified schema and query
        See <https://pandas.pydata.org/docs/user_guide/10min.html>

        Parameters:
        :   * **ts\_schema** (*string*) – The timeseries schema (e.g. ‘host:traffic’)
            * **ts\_query** (*string*) – The timeseries query (e.g. ‘ifid:0,host:10.0.0.1’)
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Timeseries data

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)") (pandas DataFrame)

    get\_timeseries\_metadata()
    :   Return timeseries metadata (list all available timeseries)

        Returns:
        :   Timeseries metadata

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_timeseries\_stats(*ts\_schema*, *ts\_query*, *epoch\_begin*, *epoch\_end*)
    :   Return stats from timeseries

        Parameters:
        :   * **ts\_schema** (*string*) – The timeseries schema (e.g. ‘host:traffic’)
            * **ts\_query** (*string*) – The timeseries query (e.g. ‘ifid:0,host:10.0.0.1’)
            * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)

        Returns:
        :   Timeseries data

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)") (pandas DataFrame)

    get\_top\_conversations(*epoch\_begin*, *epoch\_end*, *host=None*)
    :   Return Top Conversations

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **host** (*string*) – Host IP address (optional)

        Returns:
        :   Top conversations

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_topk\_flows(*epoch\_begin*, *epoch\_end*, *max\_hits*, *where\_clause*)
    :   Retrieve Top-K from the historical flows database

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **where\_clause** (*string*) – Where clause (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")

    get\_user\_alerts(*epoch\_begin*, *epoch\_end*, *select\_clause*, *where\_clause*, *maxhits*, *group\_by*, *order\_by*)
    :   Return User alerts matching the specified criteria

        Parameters:
        :   * **epoch\_begin** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Start of the time interval (epoch)
            * **epoch\_end** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – End of the time interval (epoch)
            * **select\_clause** (*string*) – Select clause (SQL syntax)
            * **where\_clause** (*string*) – Where clause (SQL syntax)
            * **maxhits** ([*int*](https://docs.python.org/3/builtins/functions.html#int "(in Python v3.15)")) – Max number of results (limit)
            * **group\_by** (*string*) – Group by condition (SQL syntax)
            * **order\_by** (*string*) – Order by condition (SQL syntax)

        Returns:
        :   Query result

        Return type:
        :   [object](https://docs.python.org/3/builtins/functions.html#object "(in Python v3.15)")