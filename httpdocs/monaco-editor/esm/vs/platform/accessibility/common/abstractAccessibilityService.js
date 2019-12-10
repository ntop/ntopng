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
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { Disposable } from '../../../base/common/lifecycle.js';
import { CONTEXT_ACCESSIBILITY_MODE_ENABLED } from './accessibility.js';
import { Emitter } from '../../../base/common/event.js';
import { IContextKeyService } from '../../contextkey/common/contextkey.js';
import { IConfigurationService } from '../../configuration/common/configuration.js';
var AbstractAccessibilityService = /** @class */ (function (_super) {
    __extends(AbstractAccessibilityService, _super);
    function AbstractAccessibilityService(_contextKeyService, _configurationService) {
        var _this = _super.call(this) || this;
        _this._contextKeyService = _contextKeyService;
        _this._configurationService = _configurationService;
        _this._onDidChangeAccessibilitySupport = new Emitter();
        _this.onDidChangeAccessibilitySupport = _this._onDidChangeAccessibilitySupport.event;
        _this._accessibilityModeEnabledContext = CONTEXT_ACCESSIBILITY_MODE_ENABLED.bindTo(_this._contextKeyService);
        _this._register(_this._configurationService.onDidChangeConfiguration(function (e) {
            if (e.affectsConfiguration('editor.accessibilitySupport')) {
                _this._updateContextKey();
            }
        }));
        _this._updateContextKey();
        _this.onDidChangeAccessibilitySupport(function () { return _this._updateContextKey(); });
        return _this;
    }
    AbstractAccessibilityService.prototype._updateContextKey = function () {
        var detected = this.getAccessibilitySupport() === 2 /* Enabled */;
        var config = this._configurationService.getValue('editor.accessibilitySupport');
        this._accessibilityModeEnabledContext.set(config === 'on' || (config === 'auto' && detected));
    };
    AbstractAccessibilityService = __decorate([
        __param(0, IContextKeyService),
        __param(1, IConfigurationService)
    ], AbstractAccessibilityService);
    return AbstractAccessibilityService;
}(Disposable));
export { AbstractAccessibilityService };
