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
import { IContextKeyService, ContextKeyExpr, RawContextKey } from '../contextkey/common/contextkey.js';
import { FindInput } from '../../base/browser/ui/findinput/findInput.js';
import { KeybindingsRegistry } from '../keybinding/common/keybindingsRegistry.js';
import { ReplaceInput } from '../../base/browser/ui/findinput/replaceInput.js';
export var HistoryNavigationWidgetContext = 'historyNavigationWidget';
export var HistoryNavigationEnablementContext = 'historyNavigationEnabled';
function bindContextScopedWidget(contextKeyService, widget, contextKey) {
    new RawContextKey(contextKey, widget).bindTo(contextKeyService);
}
function createWidgetScopedContextKeyService(contextKeyService, widget) {
    return contextKeyService.createScoped(widget.target);
}
function getContextScopedWidget(contextKeyService, contextKey) {
    return contextKeyService.getContext(document.activeElement).getValue(contextKey);
}
export function createAndBindHistoryNavigationWidgetScopedContextKeyService(contextKeyService, widget) {
    var scopedContextKeyService = createWidgetScopedContextKeyService(contextKeyService, widget);
    bindContextScopedWidget(scopedContextKeyService, widget, HistoryNavigationWidgetContext);
    var historyNavigationEnablement = new RawContextKey(HistoryNavigationEnablementContext, true).bindTo(scopedContextKeyService);
    return { scopedContextKeyService: scopedContextKeyService, historyNavigationEnablement: historyNavigationEnablement };
}
var ContextScopedFindInput = /** @class */ (function (_super) {
    __extends(ContextScopedFindInput, _super);
    function ContextScopedFindInput(container, contextViewProvider, options, contextKeyService, showFindOptions) {
        if (showFindOptions === void 0) { showFindOptions = false; }
        var _this = _super.call(this, container, contextViewProvider, showFindOptions, options) || this;
        _this._register(createAndBindHistoryNavigationWidgetScopedContextKeyService(contextKeyService, { target: _this.inputBox.element, historyNavigator: _this.inputBox }).scopedContextKeyService);
        return _this;
    }
    ContextScopedFindInput = __decorate([
        __param(3, IContextKeyService)
    ], ContextScopedFindInput);
    return ContextScopedFindInput;
}(FindInput));
export { ContextScopedFindInput };
var ContextScopedReplaceInput = /** @class */ (function (_super) {
    __extends(ContextScopedReplaceInput, _super);
    function ContextScopedReplaceInput(container, contextViewProvider, options, contextKeyService, showReplaceOptions) {
        if (showReplaceOptions === void 0) { showReplaceOptions = false; }
        var _this = _super.call(this, container, contextViewProvider, showReplaceOptions, options) || this;
        _this._register(createAndBindHistoryNavigationWidgetScopedContextKeyService(contextKeyService, { target: _this.inputBox.element, historyNavigator: _this.inputBox }).scopedContextKeyService);
        return _this;
    }
    ContextScopedReplaceInput = __decorate([
        __param(3, IContextKeyService)
    ], ContextScopedReplaceInput);
    return ContextScopedReplaceInput;
}(ReplaceInput));
export { ContextScopedReplaceInput };
KeybindingsRegistry.registerCommandAndKeybindingRule({
    id: 'history.showPrevious',
    weight: 200 /* WorkbenchContrib */,
    when: ContextKeyExpr.and(ContextKeyExpr.has(HistoryNavigationWidgetContext), ContextKeyExpr.equals(HistoryNavigationEnablementContext, true)),
    primary: 16 /* UpArrow */,
    secondary: [512 /* Alt */ | 16 /* UpArrow */],
    handler: function (accessor, arg2) {
        var widget = getContextScopedWidget(accessor.get(IContextKeyService), HistoryNavigationWidgetContext);
        if (widget) {
            var historyInputBox = widget.historyNavigator;
            historyInputBox.showPreviousValue();
        }
    }
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
    id: 'history.showNext',
    weight: 200 /* WorkbenchContrib */,
    when: ContextKeyExpr.and(ContextKeyExpr.has(HistoryNavigationWidgetContext), ContextKeyExpr.equals(HistoryNavigationEnablementContext, true)),
    primary: 18 /* DownArrow */,
    secondary: [512 /* Alt */ | 18 /* DownArrow */],
    handler: function (accessor, arg2) {
        var widget = getContextScopedWidget(accessor.get(IContextKeyService), HistoryNavigationWidgetContext);
        if (widget) {
            var historyInputBox = widget.historyNavigator;
            historyInputBox.showNextValue();
        }
    }
});
