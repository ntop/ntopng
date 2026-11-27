---
title: "Behavioural Checks Exclusion"
description: "In ntopng it's possible to exclude Hosts from specific alerts. This feature is only available from Enterprise M Version"
outline: [2, 3]
lastUpdated: 2026-08-27T14:05:53+00:00
---

<a id="behaviouralchecksexclusion"></a>

# Behavioural Checks Exclusion {#behavioural-checks-exclusion}

In ntopng it's possible to exclude Hosts from specific alerts.

::: info
This feature is only available from Enterprise M Version
:::

![Check Exclusions Entry](../../../../img/check_exclusion_page.png "Check Exclusions Entry")

![Behavioral Check Exclusions](../../../../img/behavioral_check_exclusion_overview.png "Behavioral Check Exclusions")

By clicking the `+` close to the Search above the table, it's possible to add a new host or network to exclude for an Host and a Flow Alert.
Excluded Hosts/Networks will not trigger the specified alert.

![Add Check Exclusion](../../../../img/add_check_exclusion.png "Add Check Exclusion")

An other way to exclude an host for a specific alert is by going in the Alert Page ([Alerts](/basic_concepts/alerts.md#basicconceptalerts)), click the Action button and then click 'Disable'.
From the opened pop-up it's possible to disable the alert ('Any host') or exclude an host (Client or Server). To remove from the database the alerts disabled for the host,
toggle the 'Delete Alerts' box or untoggle to not remove them.

![Add Check Exclusion](../../../../img/add_check_exclusion_from_alert_page.png "Add Check Exclusion")

## Exclude Risks Domain/Networks with nDPI {#exclude-risks-domain-networks-with-ndpi}

It's even possible to exclude Hosts, Networks and even Domains from nDPI Risk Alerts ([nDPI Risks]) by using nDPI itself.
To do it, specify a nDPI protocol file (an [example] can be found in nDPI) that contains exceptions as follows:

![nDPI Risk Exclusion](../../../../img/ndpi_risk_exclusion.png "nDPI Risk Exclusion")

Then pass this file, using the '-p' option, to ntopng (`[--ndpi-protocols|-p] <file>.protos`).
More information can be found in this [article]

[article]: https://www.ntop.org/ndpi/howto-define-ndpi-risk-exceptions-for-networks-and-domains/
[example]: https://github.com/ntop/nDPI/blob/dev/example/protos.txt
[ndpi risks]: https://www.ntop.org/guides/nDPI/flow_risks.html
