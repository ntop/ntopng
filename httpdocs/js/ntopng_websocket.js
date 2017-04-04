// 2017 - ntop.org

/*
 * Helper class to enstablish websocket connections.
 * When a websocket connection fails, a standard ajax request is used instead.
 *
 * The API is oriented to ease periodic updates.
 */

NtopngWebSocket = (function() {
  /* Scope limited global variables */

  var _severities = {
    info: "Info",
    error: "Error",
  }

  var _topics = {
    message: "Message",
    invalid_state: "Invalid State",
    connection: "Connection",
    invalid_parameter: "Invalid Parameter",
  }

  /* This is a switch to toggle debug messages */
  var _debug_enabled = false;

  var _default_options = {
    /* Milliseconds for automatic reconnection */
    reconnection_timeout: 2000,
    /* If true, a message is sent to the server upon connection */
    message_on_connect: true,
  };

  function _log(severity, topic, message) {
    var logfn;
    if (severity === _severities.error)
      logfn = console.error;
    else if (_debug_enabled)
      logfn = console.log;
    else
      logfn = $.noop;
    
    logfn("NtopngWebSocket[" + severity + "] " + topic + ": " + message);
  }

  function _schedule_singleton(singleton, callback, interval) {
    if (singleton !== null)
      clearInterval(singleton);

    if (interval > 0)
      return setInterval(callback, interval);
    else
      return null;
  }

  /* Endpoint Managers: abstracts endpoint operations */
  function initGenericEndpointManager(callbacks) {
    var callbacks = callbacks || {};

    return {
      connect: callbacks.connect || function(callback) {if(callback) callback(true)},
      is_connected: callbacks.is_connected || function() {return true},
      disconnect: callbacks.disconnect || $.noop,
      send: callbacks.send || $.noop,
    }
  }

  function WebsocketEndpointManager(address) {
    var _websocket = null;
    var _connected = false;
    var _has_error = false;
    address = "ws:" + address;

    return initGenericEndpointManager({
      connect: function(connected_callback, disconnected_callback, message_callback) {
        /* Use a WebSocket */
        _log(_severities.info, _topics.connection, "connecting");
        _websocket = new WebSocket(address);
        _has_error = false;

        _websocket.onopen = function(event) {
          _log(_severities.info, _topics.connection, "connected");
          _connected = true;
          connected_callback();
        }

        _websocket.onerror = function(event) {
          _log(_severities.error, _topics.connection, "an error occurred: " + event);
          _has_error = true;
        }

        _websocket.onclose = function(event) {
          if (_websocket) {
            _log(_severities.info, _topics.connection, "disconnected");
            _connected = false;
          }

          _websocket = null;
          disconnected_callback(_has_error);
        }

        _websocket.onmessage = function(event) {
          if(typeof message_callback === "function")
            message_callback(jQuery.parseJSON(event.data));
        }
      },
      disconnect: function() {
        if (_websocket) {
          _websocket.close();
          _websocket = null;
        }
      },
      is_connected: function() {
         return (_connected === true);
      },
      send: function(message) {
        if (_websocket && _websocket.readyState == 1) {
          try {
            _websocket.send(message);
          } catch (e) {
            _log(_severities.info, _topics.connection, "exception: " + e);
            /* will execute the onclose callback soon, unsetting _has_error will
             * make the next manager execute immediately. */
            _has_error = false
          }
        }
      },
    });
  }

  function AjaxEndpointManager(address) {
    var _message_callback = null;
    var _request = null;
    address = address.substring(address.indexOf("/"));

    return initGenericEndpointManager({
      connect: function(connected_callback, disconnected_callback, message_callback) {
        _message_callback = message_callback;
        connected_callback();
      },
      disconnect: function() {
        if (_request) {
          _request.abort();
          _request = null;
        }
      },
      send: function(message) {
        _log(_severities.info, _topics.connection, "sending AJAX request...");

        _request = $.ajax({
          type: "GET",
          url: address,
          success: function(result) {
            if(typeof _message_callback === "function")
              _message_callback(result);

            _request = null;
          },
        });
      }
    });
  }

  function initEndpointManagers(address) {
    return [
      new WebsocketEndpointManager(address),
      new AjaxEndpointManager(address),
    ]
  }

  /* NtopngWebSocket Constructor */
  return function(host_prefix) {
    var _this;

    /* Internals */
    var _managers = null;
    var _managers_idx = -1;
    var _no_manager = initGenericEndpointManager();
    var _endpoint_manager = _no_manager;

    var _manually_closed = false;
    var _reconnecting_callback = null;
    var _poll_callback = null;
    var _poll_interval = -1;
    var _poll_function = $.noop;
    var _host_prefix;
    var _options;

    function _pick_next_manager() {
      _endpoint_manager.disconnect();

      if (_managers) {
        _managers_idx++;

        if (_managers_idx < _managers.length)
          return _managers[_managers_idx];
      }

      return _no_manager;
    }

    function _disconnect() {
      _endpoint_manager.disconnect();
    }

    function _remove_reconnection_callback() {
      if (_reconnecting_callback !== null) {
        clearInterval(_reconnecting_callback);
        _reconnecting_callback = null;
      }
    }

    function _remove_poll_callback() {
      if (_poll_callback !== null) {
        clearInterval(_poll_callback);
        _poll_callback = null;
      }
    }

    function _send_message() {
      if (! _endpoint_manager.is_connected())
        return;

      var message = _poll_function();
      if (typeof message === "undefined")
        message = "";

      _log(_severities.info, _topics.message, " >>> " + message);

      _endpoint_manager.send(message);

      _poll_callback = _schedule_singleton(_poll_callback, _send_message, _poll_interval);
    }

    function _reconnect() {
      if(_managers === null) {
        _log(_severities.error, _topics.invalid_state, "connect() was not called");
        return;
      }

      if(_endpoint_manager.is_connected())
        _disconnect();

      _remove_reconnection_callback();
      _remove_poll_callback();
      _endpoint_manager.connect(function() {  /* Connection callback*/
        if (_options.message_on_connect)
          _send_message();
        else
          _poll_callback = _schedule_singleton(_poll_callback, _send_message, _poll_interval);
      }, function(with_error) {   /* Disconnection callback */
        _remove_poll_callback();

        /* always try with another manager on disconnection */
        _endpoint_manager = _pick_next_manager();

        if (! _manually_closed) {
          /* connection lost */
          if (with_error)
            _reconnecting_callback = _schedule_singleton(_reconnecting_callback, _reconnect, _options.reconnection_timeout);
          else
            _reconnect();
        }
      }, function(message) {   /* Message callback */
        // _log(_severities.info, _topics.message, " <<< " + JSON.stringify(message));
        _this.onmessage(message);
      });
    }

    /* Constructor code */

    if (typeof host_prefix !== "string") {
      _log(_severities.error, _topics.invalid_parameter, "host_prefix");
      return null;
    }

    _host_prefix = host_prefix;

    /* Exposed API */
    _this = {
      /*
       * connect
       *
       * Setup WebSocket connection. It should be called exactly once.
       * 
       *  @param endpoint: the script name to connect to
       *  @param params: an object containing additional _GET parameters (optional)
       *  @param options: a set of options. Set _default_options for more details (optional)
       *  @return true on success, false otherwise
       */
      connect: function(endpoint, params, options) {
        if (_managers !== null) {
          _log(_severities.error, _topics.invalid_state, "already bound to " + endpoint);
          return false;
        }

        var _endpoint = host_prefix + "/lua/" + endpoint;
        var _full_address = _endpoint + ((params !== null) ? ("?" + $.param(params)) : (""));

        _options = $.extend({}, _default_options, options);
        _managers = initEndpointManagers(_full_address);
        _endpoint_manager = _pick_next_manager();

        /* Start connection */
        _reconnect();
        return true;
      },

      /*
       * poll
       *
       * Set a poll interval for the update function.
       *
       *  @param interval number of milliseconds to trigger the update
       *  @return true on success, false otherwise
       */
      poll: function(interval) {
        if (typeof interval !== "number") {
          _log(_severities.error, _topics.invalid_parameter, "interval");
          return false;
        }

        _poll_interval = interval;

        if (_this.is_connected())
          _poll_callback = _schedule_singleton(_poll_callback, _poll, _poll_interval);
        else
          _remove_poll_callback();

        return true;
      },

      /*
       * message
       * Websocket only.
       *
       * Set a callback to be called to retrieve the message to pass to the server.
       * The message is sent right after connection and during poll updates (if set).
       *
       *  @param callback either
       *    - a callback which should return a message string
       *    - a string
       *  @return true on success, false otherwise
       */
      /*message: function(callback) {
        if (typeof callback === "string") {
          _poll_function = function() { return callback };
          return true;
        } else if (typeof callback === "function") {
          _poll_function = callback;
          return true;
        } else {
          _log(_severities.error, _topics.invalid_parameter, "callback");
          return false;
        }
      },*/

      /*
       * is_connected
       *
       * Check if the websocket is currently connected.
       * 
       *  @return true if connected, false otherwise
       */
      is_connected: function() {
        return _endpoint_manager.is_connected();
      },

      /*
       * Closes a connection.
       */
      disconnect: function() {
        _manually_closed = true;
        _disconnect();
      },

      /*
       * Forces reconnection.
       */
      reconnect: function() {
        _manually_closed = false;

        if(_websocket === null)
          _reconnect();
      },

      /* Websocket bound functions */
      onmessage: $.noop,
    };

    return _this;
  };
})();
