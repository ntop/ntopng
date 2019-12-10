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
import { equals, flatten, isNonEmptyArray, mergeSort } from '../../../base/common/arrays.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { illegalArgument, isPromiseCanceledError, onUnexpectedExternalError } from '../../../base/common/errors.js';
import { URI } from '../../../base/common/uri.js';
import { registerLanguageCommand } from '../../browser/editorExtensions.js';
import { Range } from '../../common/core/range.js';
import { Selection } from '../../common/core/selection.js';
import { CodeActionProviderRegistry } from '../../common/modes.js';
import { IModelService } from '../../common/services/modelService.js';
import { CodeActionKind, filtersAction, mayIncludeActionsOfKind } from './codeActionTrigger.js';
import { TextModelCancellationTokenSource } from '../../browser/core/editorState.js';
import { Disposable, DisposableStore } from '../../../base/common/lifecycle.js';
var ManagedCodeActionSet = /** @class */ (function (_super) {
    __extends(ManagedCodeActionSet, _super);
    function ManagedCodeActionSet(actions, disposables) {
        var _this = _super.call(this) || this;
        _this._register(disposables);
        _this.actions = mergeSort(actions.slice(), ManagedCodeActionSet.codeActionsComparator);
        return _this;
    }
    ManagedCodeActionSet.codeActionsComparator = function (a, b) {
        if (isNonEmptyArray(a.diagnostics)) {
            if (isNonEmptyArray(b.diagnostics)) {
                return a.diagnostics[0].message.localeCompare(b.diagnostics[0].message);
            }
            else {
                return -1;
            }
        }
        else if (isNonEmptyArray(b.diagnostics)) {
            return 1;
        }
        else {
            return 0; // both have no diagnostics
        }
    };
    Object.defineProperty(ManagedCodeActionSet.prototype, "hasAutoFix", {
        get: function () {
            return this.actions.some(function (fix) { return !!fix.kind && CodeActionKind.QuickFix.contains(new CodeActionKind(fix.kind)) && !!fix.isPreferred; });
        },
        enumerable: true,
        configurable: true
    });
    return ManagedCodeActionSet;
}(Disposable));
export function getCodeActions(model, rangeOrSelection, trigger, token) {
    var filter = trigger.filter || {};
    var codeActionContext = {
        only: filter.kind ? filter.kind.value : undefined,
        trigger: trigger.type === 'manual' ? 2 /* Manual */ : 1 /* Automatic */
    };
    var cts = new TextModelCancellationTokenSource(model, token);
    var providers = getCodeActionProviders(model, filter);
    var disposables = new DisposableStore();
    var promises = providers.map(function (provider) {
        return Promise.resolve(provider.provideCodeActions(model, rangeOrSelection, codeActionContext, cts.token)).then(function (providedCodeActions) {
            if (cts.token.isCancellationRequested || !providedCodeActions) {
                return [];
            }
            disposables.add(providedCodeActions);
            return providedCodeActions.actions.filter(function (action) { return action && filtersAction(filter, action); });
        }, function (err) {
            if (isPromiseCanceledError(err)) {
                throw err;
            }
            onUnexpectedExternalError(err);
            return [];
        });
    });
    var listener = CodeActionProviderRegistry.onDidChange(function () {
        var newProviders = CodeActionProviderRegistry.all(model);
        if (!equals(newProviders, providers)) {
            cts.cancel();
        }
    });
    return Promise.all(promises)
        .then(flatten)
        .then(function (actions) { return new ManagedCodeActionSet(actions, disposables); })
        .finally(function () {
        listener.dispose();
        cts.dispose();
    });
}
function getCodeActionProviders(model, filter) {
    return CodeActionProviderRegistry.all(model)
        // Don't include providers that we know will not return code actions of interest
        .filter(function (provider) {
        if (!provider.providedCodeActionKinds) {
            // We don't know what type of actions this provider will return.
            return true;
        }
        return provider.providedCodeActionKinds.some(function (kind) { return mayIncludeActionsOfKind(filter, new CodeActionKind(kind)); });
    });
}
registerLanguageCommand('_executeCodeActionProvider', function (accessor, args) {
    return __awaiter(this, void 0, void 0, function () {
        var resource, rangeOrSelection, kind, model, validatedRangeOrSelection, codeActionSet;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    resource = args.resource, rangeOrSelection = args.rangeOrSelection, kind = args.kind;
                    if (!(resource instanceof URI)) {
                        throw illegalArgument();
                    }
                    model = accessor.get(IModelService).getModel(resource);
                    if (!model) {
                        throw illegalArgument();
                    }
                    validatedRangeOrSelection = Selection.isISelection(rangeOrSelection)
                        ? Selection.liftSelection(rangeOrSelection)
                        : Range.isIRange(rangeOrSelection)
                            ? model.validateRange(rangeOrSelection)
                            : undefined;
                    if (!validatedRangeOrSelection) {
                        throw illegalArgument();
                    }
                    return [4 /*yield*/, getCodeActions(model, validatedRangeOrSelection, { type: 'manual', filter: { includeSourceActions: true, kind: kind && kind.value ? new CodeActionKind(kind.value) : undefined } }, CancellationToken.None)];
                case 1:
                    codeActionSet = _a.sent();
                    setTimeout(function () { return codeActionSet.dispose(); }, 100);
                    return [2 /*return*/, codeActionSet.actions];
            }
        });
    });
});
