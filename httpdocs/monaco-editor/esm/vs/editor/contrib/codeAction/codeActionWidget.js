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
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (_) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
import { getDomNodePagePosition } from '../../../base/browser/dom.js';
import { Action } from '../../../base/common/actions.js';
import { canceled } from '../../../base/common/errors.js';
import { Position } from '../../common/core/position.js';
import { Disposable, MutableDisposable } from '../../../base/common/lifecycle.js';
var CodeActionWidget = /** @class */ (function (_super) {
    __extends(CodeActionWidget, _super);
    function CodeActionWidget(_editor, _contextMenuService, _delegate) {
        var _this = _super.call(this) || this;
        _this._editor = _editor;
        _this._contextMenuService = _contextMenuService;
        _this._delegate = _delegate;
        _this._showingActions = _this._register(new MutableDisposable());
        _this._visible = false;
        return _this;
    }
    CodeActionWidget.prototype.show = function (codeActions, at) {
        return __awaiter(this, void 0, void 0, function () {
            var actions;
            var _this = this;
            return __generator(this, function (_a) {
                if (!codeActions.actions.length) {
                    this._visible = false;
                    return [2 /*return*/];
                }
                if (!this._editor.getDomNode()) {
                    // cancel when editor went off-dom
                    this._visible = false;
                    return [2 /*return*/, Promise.reject(canceled())];
                }
                this._visible = true;
                actions = codeActions.actions.map(function (action) { return _this.codeActionToAction(action); });
                this._showingActions.value = codeActions;
                this._contextMenuService.showContextMenu({
                    getAnchor: function () {
                        if (Position.isIPosition(at)) {
                            at = _this._toCoords(at);
                        }
                        return at || { x: 0, y: 0 };
                    },
                    getActions: function () { return actions; },
                    onHide: function () {
                        _this._visible = false;
                        _this._editor.focus();
                    },
                    autoSelectFirstItem: true
                });
                return [2 /*return*/];
            });
        });
    };
    CodeActionWidget.prototype.codeActionToAction = function (action) {
        var _this = this;
        var id = action.command ? action.command.id : action.title;
        var title = action.title;
        return new Action(id, title, undefined, true, function () { return _this._delegate.onSelectCodeAction(action); });
    };
    Object.defineProperty(CodeActionWidget.prototype, "isVisible", {
        get: function () {
            return this._visible;
        },
        enumerable: true,
        configurable: true
    });
    CodeActionWidget.prototype._toCoords = function (position) {
        if (!this._editor.hasModel()) {
            return { x: 0, y: 0 };
        }
        this._editor.revealPosition(position, 1 /* Immediate */);
        this._editor.render();
        // Translate to absolute editor position
        var cursorCoords = this._editor.getScrolledVisiblePosition(position);
        var editorCoords = getDomNodePagePosition(this._editor.getDomNode());
        var x = editorCoords.left + cursorCoords.left;
        var y = editorCoords.top + cursorCoords.top + cursorCoords.height;
        return { x: x, y: y };
    };
    return CodeActionWidget;
}(Disposable));
export { CodeActionWidget };
