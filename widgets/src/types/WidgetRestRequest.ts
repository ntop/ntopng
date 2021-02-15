/**
 * (C) 2021 - ntop.org
*/

import { Datasource } from "./Datasource";

export interface WidgetRestRequest {

    transformation: 'none' | 'aggregate';
    
    /**
     * The datasources requested by the user
     */
    datasources: Array<Datasource>;
}
