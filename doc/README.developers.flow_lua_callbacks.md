# Introduction


ntopng periodically visit all flows to perform operations such as counter and throughput updates, as well as the triggering of alerts. The periodicity of such visits varies:

- For packet interfaces, the default periodicity equals 5 seconds and can be configured from the preferences.
- For ZMQ interfaces, periodicity is determined using the maximum between the active (`-t`) and the idle (`-d`) timeouts received from nProbe.

# Custom Scripts Function Calls

During these periodic visits, ntopng can call certain functions found inside custom lua scripts, passing them the flows for further processing. Such functions are called at certain pre-defined events or stages of the flow lifecycle:

- Function `protocolDetected`: called after the Layer-7 application protocol has been detected
- Function `statusChanged`: called when the status of the flow has changed since the previous visit
- Function `periodicUpdate`:called every few minutes on long-lived flows
- Function `idle`: called when the flow has gone idle

Specifically, ntopng periodically iterates all the custom lua scripts and calls the function on all the scripts in which it is defined.

NOTE: for pcap dump interfaces, only the `protocolDetected` is called.

## protocolDetected

For packet interfaces, ntopng detects the Layer-7 application protocol of a flow within its first 12 packets. In case of ZMQ interfaces, the protocol of a flow is marked as detected right after the flow has been received. The first time the periodic visit steps on the flow after its protocol has been detected, it will call `protocolDetected`.

## statusChanged

Every flow has a bitmap of statuses associated. A new flow starts with a clear bitmap. This bitmap is then modified during the lifecycle of the flow to set new statuses (e.g., when retransmissions are detected, or when the flow is marked as blacklisted). Every time a periodic visit on the flow detect the statuses bitmap has changed since the previous visit, it will call `statusChanged`. Statuses can change both for packet as well as for ZMQ interfaces.

## periodicUpdate

Periodic visits call function `periodicUpdate` on long-lived flows every few minutes. This function is called at intervals equal to 5 times the maximum flow idleness. The maximum flow idleness:

- Defaults to 1 minute for packet interfaces and it can be changed from the preferences
- Is determined using the active (`-t`) timeout for ZMQ interfaces

## idle

When a flow becomes idle, after an amount of time which depends on the maximum flow idleness as discussed in `periodicUpdate`, the periodic visit will step on it the last time and will call `idle`, both for packet as well as for ZMQ interfaces.

## Custom Scripts

ntopng reads custom scripts under `scripts/callbacks/interface/alerts/flow/`. Placing a `.lua` file there will cause ntopng to load it.

The skeleton of a custom can be the following:

```
local check_module = {
   key = "a_custom_module_name",

   gui = {
      i18n_title = "My Custom Script",
      i18n_description = "This script performs certain custom operations",
      input_builder = alerts_api.flow_checkbox_input_builder,
   }
}


-- #################################################################

function check_module.setup()
  return true
end

-- #################################################################

function check_module.protocolDetected(info)
  -- info contains the output of Flow::lua()
end

-- #################################################################

return check_module
```

The `key` is a unique identifier for the script. The `gui` part contains a `title` and a `description` which are shown in the ntopng interface custom scripts page, and an `input_builder` which currently supports only a checkbox to enable or disable the script from the gui. Localized i18n strings can be used both for the `title` and the `description`.

Function `setup()` must always be present and it must return true if the module has to be enabled or false if the module has to be disabled.

Then, the script can define zero or more of the functions highlighted above, namely: `protocolDetected`, `statusChanged`, `periodicUpdate` and `idle`. Defining a function will cause ntopng to call it, passing a table generated out of the `Flow::lua()` call as the first argument.
