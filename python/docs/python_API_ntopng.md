# Ntopng Class

The `Ntopng` class provides information about global data (e.g., list of interfaces) and consts (e.g., alert types).

## Constructor

### `__init__(self, username=None, password=None, auth_token=None, url="http://localhost:3000")`

Constructs a new `Ntopng` object.

- `username`: The ntopng username (leave empty if token authentication is used) (string).
- `password`: The ntopng password (leave empty if token authentication is used) (string).
- `auth_token`: The authentication token (leave empty if username/password authentication is used) (integer).
- `url`: The default ntopng URL (e.g., http://localhost:3000) (string).

## Methods

### `get_url(self)`

Returns the ntopng URL.

- Returns: The ntopng URL (string).

### `issue_request(self, url, params)`

Issues a GET request.

- `url`: The URL for the GET request (string).
- `params`: Parameters to include in the request (dictionary).
- Returns: The response from the request (HTTP response object).

### `issue_post_request(self, url, params)`

Issues a POST request.

- `url`: The URL for the POST request (string).
- `params`: Parameters to include in the request (dictionary).
- Returns: The response from the request (HTTP response object).

### `enable_debug(self)`

Enables debugging mode.

### `request(self, url, params)`

Issues a GET request and returns the response.

- `url`: The URL for the GET request (string).
- `params`: Parameters to include in the request (dictionary).
- Returns: The response from the request (dictionary).

### `post_request(self, url, params)`

Issues a POST request and returns the response.

- `url`: The URL for the POST request (string).
- `params`: Parameters to include in the request (dictionary).
- Returns: The response from the request (dictionary).

### `get_alert_types(self)`

Returns all alert types.

- Returns: The list of alert types (array).

### `get_alert_severities(self)`

Returns all severities.

- Returns: The list of severities (array).

### `get_interface(self, ifid)`

Returns an `Interface` instance.

- `ifid`: The interface ID (integer).
- Returns: The interface instance (`ntopng.Interface`).

### `get_historical_interface(self, ifid)`

Returns a `Historical` handle for an interface.

- `ifid`: The interface ID (integer).
- Returns: The historical handle (`ntopng.Historical`).

### `get_interfaces_list(self)`

Returns all available interfaces.

- Returns: The list of interfaces (array).

### `get_host_interfaces_list(self, host)`

Returns all ntopng interfaces for a given host.

- `host`: The host (string).
- Returns: List of interfaces (array).
