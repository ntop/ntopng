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
import { illegalArgument } from '../../../base/common/errors.js';
import { UILabelProvider, AriaLabelProvider } from '../../../base/common/keybindingLabels.js';
import { ResolvedKeybinding, ResolvedKeybindingPart } from '../../../base/common/keyCodes.js';
var BaseResolvedKeybinding = /** @class */ (function (_super) {
    __extends(BaseResolvedKeybinding, _super);
    function BaseResolvedKeybinding(os, parts) {
        var _this = _super.call(this) || this;
        if (parts.length === 0) {
            throw illegalArgument("parts");
        }
        _this._os = os;
        _this._parts = parts;
        return _this;
    }
    BaseResolvedKeybinding.prototype.getLabel = function () {
        var _this = this;
        return UILabelProvider.toLabel(this._os, this._parts, function (keybinding) { return _this._getLabel(keybinding); });
    };
    BaseResolvedKeybinding.prototype.getAriaLabel = function () {
        var _this = this;
        return AriaLabelProvider.toLabel(this._os, this._parts, function (keybinding) { return _this._getAriaLabel(keybinding); });
    };
    BaseResolvedKeybinding.prototype.isChord = function () {
        return (this._parts.length > 1);
    };
    BaseResolvedKeybinding.prototype.getParts = function () {
        var _this = this;
        return this._parts.map(function (keybinding) { return _this._getPart(keybinding); });
    };
    BaseResolvedKeybinding.prototype._getPart = function (keybinding) {
        return new ResolvedKeybindingPart(keybinding.ctrlKey, keybinding.shiftKey, keybinding.altKey, keybinding.metaKey, this._getLabel(keybinding), this._getAriaLabel(keybinding));
    };
    BaseResolvedKeybinding.prototype.getDispatchParts = function () {
        var _this = this;
        return this._parts.map(function (keybinding) { return _this._getDispatchPart(keybinding); });
    };
    return BaseResolvedKeybinding;
}(ResolvedKeybinding));
export { BaseResolvedKeybinding };
