The `ntpng_url_manager` function provides utilities for managing and manipulating URL parameters in a web application. This is often used to store temporary user settings or state information 
that's passed through links. 

## Parameters & Functions

This section describes each of the functions provided by the `ntpng_url_manager` object, along with their expected input types and behavior. First import the class when needed.

```javascript
import { ntopng_url_manager } from "http_src/services/context/ntopng_globals_services.js";

// Invoke method_X()
ntopng_url_manager.method_X()
```

### `get_url_params`

- **Input**: None
- **Output**: The query string from the current URL.
- **Description**: Returns the current query parameters as a string.

### `get_url_search_params(url)`

- **Parameters**: `url` (optional) - A URL to analyze for search parameters. If not provided, uses the current page's URL.
- **Output**: An object representing the parsed query parameters.
- **Description**: Parses and returns an `URLSearchParams` object containing the query parameters.

### `get_url_entries(url)`

- **Parameters**: `url` (optional) - A URL to analyze for search parameters. If not provided, uses the current page's URL.
- **Output**: An iterable over key-value pairs from the query string.
- **Description**: Returns an iterator of `[key, value]` pairs for each entry in the query string.

### `get_url_entry(param_name, url)`

- **Parameters**:
  - `param_name`: A string representing the name of the parameter to find.
  - `url` (optional) - A URL to analyze for search parameters. If not provided, uses the current page's URL.
- **Output**: The value associated with the given key, or null if it doesn't exist.
- **Description**: Searches through query parameters for a specific key and returns its corresponding value.

### `get_url_object(url)`

- **Parameters**: `url` (optional) - A URL to analyze for search parameters. If not provided, uses the current page's URL.
- **Output**: An object containing all query parameters as key-value pairs.
- **Description**: Returns an object representing all the query parameters from a given URL.

### `open_new_window(url)`

- **Parameters**:
  - `url` (optional) - A URL to open in a new window. If not provided, uses the current page's location.
- **Output**: None
- **Description**: Opens a new browser window pointing to the specified URL.

### `reload_url()`

- **Parameters**: None
- **Output**: None
- **Description**: Reloads the current page without changing history.

### `go_to_url(url)`

- **Parameters**:
  - `url`: A URL to navigate to.
- **Output**: None
- **Description**: Navigates to a given URL, replacing the current entry in the browser's history stack.

### `replace_url(url_params)`

- **Parameters**:
  - `url_params`: An object containing query parameters as key-value pairs.
- **Output**: None
- **Description**: Replaces the current page's URL with one that includes new or updated query parameters, without changing history.

### `replace_url_and_reload(url_params)`

- **Parameters**:
  - `url_params`: An object containing query parameters as key-value pairs.
- **Output**: None
- **Description**: Replaces the current URL and then reloads the page.

### `serialize_param(key, value)`

- **Parameters**:
  - `key`: A string representing the parameter name to serialize.
  - `value`: The associated value for the given key (default is an empty string).
- **Output**: A serialized query parameter in format `key=value`.
- **Description**: Converts a key-value pair into a query string component.

### `set_custom_key_serializer(key, f_get_url_param)`

- **Parameters**:
  - `key`: The name of the parameter to customize serialization for.
  - `f_get_url_param`: A function that customizes how this specific parameter is extracted from the URL's query parameters.
- **Output**: None
- **Description**: Registers a new serialization method for a particular query parameter.

### `obj_to_url_params(obj)`

- **Parameters**:
  - `obj`: An object containing key-value pairs representing query parameters to convert into URL format.
- **Output**: A string representing the serialized query parameters from an object.
- **Description**: Converts an object of query parameters into a string that represents URL query parameters.

### Methods for Query Parameter Management

#### `delete_params(params_key)`

- **Parameters**:
  - `params_key`: An array of keys to delete from the current query parameters.
- **Output**: None
- **Description**: Deletes specified query parameters from the current page's URL and replaces it with a new version.

#### `delete_key_from_url(key)`

- **Parameters**:
  - `key`: A string representing the key to delete from the URL query parameters.
- **Output**: None
- **Description**: Deletes a single query parameter by its name and updates the URL accordingly.

#### `set_key_to_url(key, value)`

- **Parameters**:
  - `key`: A string representing the key whose value is being set in the query parameters.
  - `value`: The new value for the given key.
- **Output**: None
- **Description**: Sets a specific query parameter to a new value and updates the URL.

#### `add_obj_to_url(url_params_obj, url)`

- **Parameters**:
  - `url_params_obj`: An object containing additional or updated query parameters as key-value pairs.
  - `url` (optional): A URL to which these parameters will be added. If not provided, uses the current page's location.
- **Output**: None
- **Description**: Adds or updates query parameters in a given URL and optionally opens it.

These methods provide comprehensive control over navigation and query parameter management on web pages, supporting both user interactions and dynamic content loading.