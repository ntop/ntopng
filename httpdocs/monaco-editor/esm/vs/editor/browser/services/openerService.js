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
import * as dom from '../../../base/browser/dom.js';
import { Disposable } from '../../../base/common/lifecycle.js';
import { LinkedList } from '../../../base/common/linkedList.js';
import { parse } from '../../../base/common/marshalling.js';
import { Schemas } from '../../../base/common/network.js';
import * as resources from '../../../base/common/resources.js';
import { equalsIgnoreCase } from '../../../base/common/strings.js';
import { ICodeEditorService } from './codeEditorService.js';
import { CommandsRegistry, ICommandService } from '../../../platform/commands/common/commands.js';
var OpenerService = /** @class */ (function (_super) {
    __extends(OpenerService, _super);
    function OpenerService(_editorService, _commandService) {
        var _this = _super.call(this) || this;
        _this._editorService = _editorService;
        _this._commandService = _commandService;
        _this._openers = new LinkedList();
        _this._validators = new LinkedList();
        return _this;
    }
    OpenerService.prototype.open = function (resource, options) {
        return __awaiter(this, void 0, void 0, function () {
            var _i, _a, validator, _b, _c, opener_1, handled;
            return __generator(this, function (_d) {
                switch (_d.label) {
                    case 0:
                        // no scheme ?!?
                        if (!resource.scheme) {
                            return [2 /*return*/, Promise.resolve(false)];
                        }
                        _i = 0, _a = this._validators.toArray();
                        _d.label = 1;
                    case 1:
                        if (!(_i < _a.length)) return [3 /*break*/, 4];
                        validator = _a[_i];
                        return [4 /*yield*/, validator.shouldOpen(resource)];
                    case 2:
                        if (!(_d.sent())) {
                            return [2 /*return*/, false];
                        }
                        _d.label = 3;
                    case 3:
                        _i++;
                        return [3 /*break*/, 1];
                    case 4:
                        _b = 0, _c = this._openers.toArray();
                        _d.label = 5;
                    case 5:
                        if (!(_b < _c.length)) return [3 /*break*/, 8];
                        opener_1 = _c[_b];
                        return [4 /*yield*/, opener_1.open(resource, options)];
                    case 6:
                        handled = _d.sent();
                        if (handled) {
                            return [2 /*return*/, true];
                        }
                        _d.label = 7;
                    case 7:
                        _b++;
                        return [3 /*break*/, 5];
                    case 8: 
                    // use default openers
                    return [2 /*return*/, this._doOpen(resource, options)];
                }
            });
        });
    };
    OpenerService.prototype._doOpen = function (resource, options) {
        var _a;
        var scheme = resource.scheme, path = resource.path, query = resource.query, fragment = resource.fragment;
        if (equalsIgnoreCase(scheme, Schemas.mailto) || (options && options.openExternal)) {
            // open default mail application
            return this._doOpenExternal(resource);
        }
        if (equalsIgnoreCase(scheme, Schemas.http) || equalsIgnoreCase(scheme, Schemas.https)) {
            // open link in default browser
            return this._doOpenExternal(resource);
        }
        else if (equalsIgnoreCase(scheme, Schemas.command)) {
            // run command or bail out if command isn't known
            if (!CommandsRegistry.getCommand(path)) {
                return Promise.reject("command '" + path + "' NOT known");
            }
            // execute as command
            var args = [];
            try {
                args = parse(query);
                if (!Array.isArray(args)) {
                    args = [args];
                }
            }
            catch (e) {
                //
            }
            return (_a = this._commandService).executeCommand.apply(_a, [path].concat(args)).then(function () { return true; });
        }
        else {
            var selection = undefined;
            var match = /^L?(\d+)(?:,(\d+))?/.exec(fragment);
            if (match) {
                // support file:///some/file.js#73,84
                // support file:///some/file.js#L73
                selection = {
                    startLineNumber: parseInt(match[1]),
                    startColumn: match[2] ? parseInt(match[2]) : 1
                };
                // remove fragment
                resource = resource.with({ fragment: '' });
            }
            if (resource.scheme === Schemas.file) {
                resource = resources.normalizePath(resource); // workaround for non-normalized paths (https://github.com/Microsoft/vscode/issues/12954)
            }
            return this._editorService.openCodeEditor({ resource: resource, options: { selection: selection, } }, this._editorService.getFocusedCodeEditor(), options && options.openToSide).then(function () { return true; });
        }
    };
    OpenerService.prototype._doOpenExternal = function (resource) {
        dom.windowOpenNoOpener(encodeURI(resource.toString(true)));
        return Promise.resolve(true);
    };
    OpenerService.prototype.dispose = function () {
        this._validators.clear();
    };
    OpenerService = __decorate([
        __param(0, ICodeEditorService),
        __param(1, ICommandService)
    ], OpenerService);
    return OpenerService;
}(Disposable));
export { OpenerService };
