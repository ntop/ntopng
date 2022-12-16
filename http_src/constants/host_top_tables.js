import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import interfaceTopTables from "./interface_top_tables.js";

let top_application_interface = interfaceTopTables.find((t) => t.view == "top_protocols");
if (top_application_interface != null) {
    top_application_interface = ntopng_utility.clone(top_application_interface);
    top_application_interface.table_value = "host";
}

const top_application = top_application_interface;

const host_top_tables = [top_application];

export default host_top_tables;
