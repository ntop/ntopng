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
import { onUnexpectedError } from '../../../base/common/errors.js';
import { Disposable, MutableDisposable } from '../../../base/common/lifecycle.js';
import { MessageController } from '../message/messageController.js';
import { IContextMenuService } from '../../../platform/contextview/browser/contextView.js';
import { IKeybindingService } from '../../../platform/keybinding/common/keybinding.js';
import { CodeActionWidget } from './codeActionWidget.js';
import { LightBulbWidget } from './lightBulbWidget.js';
var CodeActionUi = /** @class */ (function (_super) {
    __extends(CodeActionUi, _super);
    function CodeActionUi(_editor, quickFixActionId, delegate, contextMenuService, keybindingService) {
        var _this = _super.call(this) || this;
        _this._editor = _editor;
        _this.delegate = delegate;
        _this._activeCodeActions = _this._register(new MutableDisposable());
        _this._codeActionWidget = _this._register(new CodeActionWidget(_this._editor, contextMenuService, {
            onSelectCodeAction: function (action) { return __awaiter(_this, void 0, void 0, function () {
                return __generator(this, function (_a) {
                    this.delegate.applyCodeAction(action, /* retrigger */ true);
                    return [2 /*return*/];
                });
            }); }
        }));
        _this._lightBulbWidget = _this._register(new LightBulbWidget(_this._editor, quickFixActionId, keybindingService));
        _this._register(_this._lightBulbWidget.onClick(_this._handleLightBulbSelect, _this));
        return _this;
    }
    CodeActionUi.prototype.update = function (newState) {
        return __awaiter(this, void 0, void 0, function () {
            var actions, e_1;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        if (newState.type !== 1 /* Triggered */) {
                            this._lightBulbWidget.hide();
                            return [2 /*return*/];
                        }
                        _a.label = 1;
                    case 1:
                        _a.trys.push([1, 3, , 4]);
                        return [4 /*yield*/, newState.actions];
                    case 2:
                        actions = _a.sent();
                        return [3 /*break*/, 4];
                    case 3:
                        e_1 = _a.sent();
                        onUnexpectedError(e_1);
                        return [2 /*return*/];
                    case 4:
                        this._lightBulbWidget.update(actions, newState.position);
                        if (!actions.actions.length && newState.trigger.context) {
                            MessageController.get(this._editor).showMessage(newState.trigger.context.notAvailableMessage, newState.trigger.context.position);
                            this._activeCodeActions.value = actions;
                            return [2 /*return*/];
                        }
                        if (!(newState.trigger.type === 'manual')) return [3 /*break*/, 10];
                        if (!(newState.trigger.filter && newState.trigger.filter.kind)) return [3 /*break*/, 9];
                        if (!(actions.actions.length > 0)) return [3 /*break*/, 9];
                        if (!(newState.trigger.autoApply === 1 /* First */ || (newState.trigger.autoApply === 0 /* IfSingle */ && actions.actions.length === 1))) return [3 /*break*/, 9];
                        _a.label = 5;
                    case 5:
                        _a.trys.push([5, , 7, 8]);
                        return [4 /*yield*/, this.delegate.applyCodeAction(actions.actions[0], false)];
                    case 6:
                        _a.sent();
                        return [3 /*break*/, 8];
                    case 7:
                        actions.dispose();
                        return [7 /*endfinally*/];
                    case 8: return [2 /*return*/];
                    case 9:
                        this._activeCodeActions.value = actions;
                        this._codeActionWidget.show(actions, newState.position);
                        return [3 /*break*/, 11];
                    case 10:
                        // auto magically triggered
                        if (this._codeActionWidget.isVisible) {
                            // TODO: Figure out if we should update the showing menu?
                            actions.dispose();
                        }
                        else {
                            this._activeCodeActions.value = actions;
                        }
                        _a.label = 11;
                    case 11: return [2 /*return*/];
                }
            });
        });
    };
    CodeActionUi.prototype.showCodeActionList = function (actions, at) {
        return __awaiter(this, void 0, void 0, function () {
            return __generator(this, function (_a) {
                this._codeActionWidget.show(actions, at);
                return [2 /*return*/];
            });
        });
    };
    CodeActionUi.prototype._handleLightBulbSelect = function (e) {
        this._codeActionWidget.show(e.actions, e);
    };
    CodeActionUi = __decorate([
        __param(3, IContextMenuService),
        __param(4, IKeybindingService)
    ], CodeActionUi);
    return CodeActionUi;
}(Disposable));
export { CodeActionUi };
