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
import { KeyCodeUtils } from '../../../base/common/keyCodes.js';
import { BaseResolvedKeybinding } from './baseResolvedKeybinding.js';
/**
 * Do not instantiate. Use KeybindingService to get a ResolvedKeybinding seeded with information about the current kb layout.
 */
var USLayoutResolvedKeybinding = /** @class */ (function (_super) {
    __extends(USLayoutResolvedKeybinding, _super);
    function USLayoutResolvedKeybinding(actual, os) {
        return _super.call(this, os, actual.parts) || this;
    }
    USLayoutResolvedKeybinding.prototype._keyCodeToUILabel = function (keyCode) {
        if (this._os === 2 /* Macintosh */) {
            switch (keyCode) {
                case 15 /* LeftArrow */:
                    return '←';
                case 16 /* UpArrow */:
                    return '↑';
                case 17 /* RightArrow */:
                    return '→';
                case 18 /* DownArrow */:
                    return '↓';
            }
        }
        return KeyCodeUtils.toString(keyCode);
    };
    USLayoutResolvedKeybinding.prototype._getLabel = function (keybinding) {
        if (keybinding.isDuplicateModifierCase()) {
            return '';
        }
        return this._keyCodeToUILabel(keybinding.keyCode);
    };
    USLayoutResolvedKeybinding.prototype._getAriaLabel = function (keybinding) {
        if (keybinding.isDuplicateModifierCase()) {
            return '';
        }
        return KeyCodeUtils.toString(keybinding.keyCode);
    };
    USLayoutResolvedKeybinding.prototype._getDispatchPart = function (keybinding) {
        return USLayoutResolvedKeybinding.getDispatchStr(keybinding);
    };
    USLayoutResolvedKeybinding.getDispatchStr = function (keybinding) {
        if (keybinding.isModifierKey()) {
            return null;
        }
        var result = '';
        if (keybinding.ctrlKey) {
            result += 'ctrl+';
        }
        if (keybinding.shiftKey) {
            result += 'shift+';
        }
        if (keybinding.altKey) {
            result += 'alt+';
        }
        if (keybinding.metaKey) {
            result += 'meta+';
        }
        result += KeyCodeUtils.toString(keybinding.keyCode);
        return result;
    };
    return USLayoutResolvedKeybinding;
}(BaseResolvedKeybinding));
export { USLayoutResolvedKeybinding };
