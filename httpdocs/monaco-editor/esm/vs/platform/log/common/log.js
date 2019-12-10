/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { createDecorator as createServiceDecorator } from '../../instantiation/common/instantiation.js';
export var ILogService = createServiceDecorator('logService');
var NullLogService = /** @class */ (function () {
    function NullLogService() {
    }
    NullLogService.prototype.trace = function (message) {
        var args = [];
        for (var _i = 1; _i < arguments.length; _i++) {
            args[_i - 1] = arguments[_i];
        }
    };
    NullLogService.prototype.error = function (message) {
        var args = [];
        for (var _i = 1; _i < arguments.length; _i++) {
            args[_i - 1] = arguments[_i];
        }
    };
    NullLogService.prototype.dispose = function () { };
    return NullLogService;
}());
export { NullLogService };
