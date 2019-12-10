/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __extends = (this && this.__extends) || (function () {
    var extendStatics = function (d, b) {
        extendStatics = Object.setPrototypeOf ||
            ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
            function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
        return extendStatics(d, b);
    };
    return function (d, b) {
        extendStatics(d, b);
        function __() { this.constructor = d; }
        d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
    };
})();
import { createDecorator } from '../../instantiation/common/instantiation.js';
import { Event, Emitter } from '../../../base/common/event.js';
import { Disposable } from '../../../base/common/lifecycle.js';
import { isUndefinedOrNull } from '../../../base/common/types.js';
export var IStorageService = createDecorator('storageService');
export var WillSaveStateReason;
(function (WillSaveStateReason) {
    WillSaveStateReason[WillSaveStateReason["NONE"] = 0] = "NONE";
    WillSaveStateReason[WillSaveStateReason["SHUTDOWN"] = 1] = "SHUTDOWN";
})(WillSaveStateReason || (WillSaveStateReason = {}));
var InMemoryStorageService = /** @class */ (function (_super) {
    __extends(InMemoryStorageService, _super);
    function InMemoryStorageService() {
        var _this = _super !== null && _super.apply(this, arguments) || this;
        _this._serviceBrand = null;
        _this._onDidChangeStorage = _this._register(new Emitter());
        _this.onDidChangeStorage = _this._onDidChangeStorage.event;
        _this.onWillSaveState = Event.None;
        _this.globalCache = new Map();
        _this.workspaceCache = new Map();
        return _this;
    }
    InMemoryStorageService.prototype.getCache = function (scope) {
        return scope === 0 /* GLOBAL */ ? this.globalCache : this.workspaceCache;
    };
    InMemoryStorageService.prototype.get = function (key, scope, fallbackValue) {
        var value = this.getCache(scope).get(key);
        if (isUndefinedOrNull(value)) {
            return fallbackValue;
        }
        return value;
    };
    InMemoryStorageService.prototype.getBoolean = function (key, scope, fallbackValue) {
        var value = this.getCache(scope).get(key);
        if (isUndefinedOrNull(value)) {
            return fallbackValue;
        }
        return value === 'true';
    };
    InMemoryStorageService.prototype.store = function (key, value, scope) {
        // We remove the key for undefined/null values
        if (isUndefinedOrNull(value)) {
            return this.remove(key, scope);
        }
        // Otherwise, convert to String and store
        var valueStr = String(value);
        // Return early if value already set
        var currentValue = this.getCache(scope).get(key);
        if (currentValue === valueStr) {
            return Promise.resolve();
        }
        // Update in cache
        this.getCache(scope).set(key, valueStr);
        // Events
        this._onDidChangeStorage.fire({ scope: scope, key: key });
        return Promise.resolve();
    };
    InMemoryStorageService.prototype.remove = function (key, scope) {
        var wasDeleted = this.getCache(scope).delete(key);
        if (!wasDeleted) {
            return Promise.resolve(); // Return early if value already deleted
        }
        // Events
        this._onDidChangeStorage.fire({ scope: scope, key: key });
        return Promise.resolve();
    };
    return InMemoryStorageService;
}(Disposable));
export { InMemoryStorageService };
