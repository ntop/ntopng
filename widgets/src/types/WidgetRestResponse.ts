/**
 * (C) 2021 - ntop.org
*/

import { Datasource } from "./Datasource";
import { RestCode } from "./RestCode";

interface NtopngRestV1Response {
    /* The payload contained inside the REST response */
    rsp: object;
    /* A short description about the status of the REST request */
    rc_str_hr: string;
    /* A human-readable name for the response code */
    rc_str: string;
    /* Return Code of the REST response */
    rc: RestCode;
}

interface DatasourceMetadata {
    url?: string;
}

/**
 * The payload contained inside the REST response
 */
export interface WidgetResponsePayload {

    data: {
        values?: Array<number>;
        keys?: Array<string>;
        label?: string;
        labels?: Array<string>;
        y?: Array<number>;
        x?: Array<number>;
        colors?: Array<string>;
    };

    metadata?: DatasourceMetadata;
    datasource: Datasource;
}

export interface WidgetRestResponse extends NtopngRestV1Response {
    rsp: Array<WidgetResponsePayload>;
}