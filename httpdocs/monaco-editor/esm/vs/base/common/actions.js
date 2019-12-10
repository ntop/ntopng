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
import { Disposable } from './lifecycle.js';
import { Emitter } from './event.js';
var Action = /** @class */ (function (_super) {
    __extends(Action, _super);
    function Action(id, label, cssClass, enabled, actionCallback) {
        if (label === void 0) { label = ''; }
        if (cssClass === void 0) { cssClass = ''; }
        if (enabled === void 0) { enabled = true; }
        var _this = _super.call(this) || this;
        _this._onDidChange = _this._register(new Emitter());
        _this.onDidChange = _this._onDidChange.event;
        _this._enabled = true;
        _this._checked = false;
        _this._radio = false;
        _this._id = id;
        _this._label = label;
        _this._cssClass = cssClass;
        _this._enabled = enabled;
        _this._actionCallback = actionCallback;
        return _this;
    }
    Object.defineProperty(Action.prototype, "id", {
        get: function () {
            return this._id;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Action.prototype, "label", {
        get: function () {
            return this._label;
        },
        set: function (value) {
            this._setLabel(value);
        },
        enumerable: true,
        configurable: true
    });
    Action.prototype._setLabel = function (value) {
        if (this._label !== value) {
            this._label = value;
            this._onDidChange.fire({ label: value });
        }
    };
    Object.defineProperty(Action.prototype, "tooltip", {
        get: function () {
            return this._tooltip || '';
        },
        set: function (value) {
            this._setTooltip(value);
        },
        enumerable: true,
        configurable: true
    });
    Action.prototype._setTooltip = function (value) {
        if (this._tooltip !== value) {
            this._tooltip = value;
            this._onDidChange.fire({ tooltip: value });
        }
    };
    Object.defineProperty(Action.prototype, "class", {
        get: function () {
            return this._cssClass;
        },
        set: function (value) {
            this._setClass(value);
        },
        enumerable: true,
        configurable: true
    });
    Action.prototype._setClass = function (value) {
        if (this._cssClass !== value) {
            this._cssClass = value;
            this._onDidChange.fire({ class: value });
        }
    };
    Object.defineProperty(Action.prototype, "enabled", {
        get: function () {
            return this._enabled;
        },
        set: function (value) {
            this._setEnabled(value);
        },
        enumerable: true,
        configurable: true
    });
    Action.prototype._setEnabled = function (value) {
        if (this._enabled !== value) {
            this._enabled = value;
            this._onDidChange.fire({ enabled: value });
        }
    };
    Object.defineProperty(Action.prototype, "checked", {
        get: function () {
            return this._checked;
        },
        set: function (value) {
            this._setChecked(value);
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Action.prototype, "radio", {
        get: function () {
            return this._radio;
        },
        set: function (value) {
            this._setRadio(value);
        },
        enumerable: true,
        configurable: true
    });
    Action.prototype._setChecked = function (value) {
        if (this._checked !== value) {
            this._checked = value;
            this._onDidChange.fire({ checked: value });
        }
    };
    Action.prototype._setRadio = function (value) {
        if (this._radio !== value) {
            this._radio = value;
            this._onDidChange.fire({ radio: value });
        }
    };
    Action.prototype.run = function (event, _data) {
        if (this._actionCallback) {
            return this._actionCallback(event);
        }
        return Promise.resolve(true);
    };
    return Action;
}(Disposable));
export { Action };
var ActionRunner = /** @class */ (function (_super) {
    __extends(ActionRunner, _super);
    function ActionRunner() {
        var _this = _super !== null && _super.apply(this, arguments) || this;
        _this._onDidBeforeRun = _this._register(new Emitter());
        _this.onDidBeforeRun = _this._onDidBeforeRun.event;
        _this._onDidRun = _this._register(new Emitter());
        _this.onDidRun = _this._onDidRun.event;
        return _this;
    }
    ActionRunner.prototype.run = function (action, context) {
        return __awaiter(this, void 0, void 0, function () {
            var result, error_1;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        if (!action.enabled) {
                            return [2 /*return*/, Promise.resolve(null)];
                        }
                        this._onDidBeforeRun.fire({ action: action });
                        _a.label = 1;
                    case 1:
                        _a.trys.push([1, 3, , 4]);
                        return [4 /*yield*/, this.runAction(action, context)];
                    case 2:
                        result = _a.sent();
                        this._onDidRun.fire({ action: action, result: result });
                        return [3 /*break*/, 4];
                    case 3:
                        error_1 = _a.sent();
                        this._onDidRun.fire({ action: action, error: error_1 });
                        return [3 /*break*/, 4];
                    case 4: return [2 /*return*/];
                }
            });
        });
    };
    ActionRunner.prototype.runAction = function (action, context) {
        var res = context ? action.run(context) : action.run();
        return Promise.resolve(res);
    };
    return ActionRunner;
}(Disposable));
export { ActionRunner };
