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
import { IContextKeyService } from '../../contextkey/common/contextkey.js';
import { IConfigurationService } from '../../configuration/common/configuration.js';
import { AbstractAccessibilityService } from './abstractAccessibilityService.js';
var BrowserAccessibilityService = /** @class */ (function (_super) {
    __extends(BrowserAccessibilityService, _super);
    function BrowserAccessibilityService(contextKeyService, configurationService) {
        var _this = _super.call(this, contextKeyService, configurationService) || this;
        _this.contextKeyService = contextKeyService;
        _this.configurationService = configurationService;
        _this._accessibilitySupport = 0 /* Unknown */;
        return _this;
    }
    BrowserAccessibilityService.prototype.getAccessibilitySupport = function () {
        return this._accessibilitySupport;
    };
    BrowserAccessibilityService = __decorate([
        __param(0, IContextKeyService),
        __param(1, IConfigurationService)
    ], BrowserAccessibilityService);
    return BrowserAccessibilityService;
}(AbstractAccessibilityService));
export { BrowserAccessibilityService };
