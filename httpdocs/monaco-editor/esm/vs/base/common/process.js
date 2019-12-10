/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { isWindows, isMacintosh, setImmediate } from './platform.js';
var safeProcess = (typeof process === 'undefined') ? {
    cwd: function () { return '/'; },
    env: Object.create(null),
    get platform() { return isWindows ? 'win32' : isMacintosh ? 'darwin' : 'linux'; },
    nextTick: function (callback) { return setImmediate(callback); }
} : process;
export var cwd = safeProcess.cwd;
export var env = safeProcess.env;
export var platform = safeProcess.platform;
