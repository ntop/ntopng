/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { URI } from './uri.js';
export function parse(text) {
    var data = JSON.parse(text);
    data = revive(data, 0);
    return data;
}
export function revive(obj, depth) {
    if (!obj || depth > 200) {
        return obj;
    }
    if (typeof obj === 'object') {
        switch (obj.$mid) {
            case 1: return URI.revive(obj);
            case 2: return new RegExp(obj.source, obj.flags);
        }
        // walk object (or array)
        for (var key in obj) {
            if (Object.hasOwnProperty.call(obj, key)) {
                obj[key] = revive(obj[key], depth + 1);
            }
        }
    }
    return obj;
}
