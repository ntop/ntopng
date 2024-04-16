import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import interfaceTopTables from "./interface_top_tables.js";

let top_application_interface = interfaceTopTables.find((t) => t.view == "top_protocols");
if (top_application_interface != null) {
    top_application_interface = ntopng_utility.clone(top_application_interface);
    top_application_interface.table_value = "host";
}
let top_category_interface = interfaceTopTables.find((t) => t.view == "top_categories");
if (top_category_interface != null) {
    top_category_interface = ntopng_utility.clone(top_category_interface);
    top_category_interface.table_value = "host";
}

const top_application = top_application_interface;
const top_category = top_category_interface;

const host_top_tables = [top_application, top_category];

export default host_top_tables;
