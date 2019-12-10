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
import { createCancelablePromise, TimeoutTimer } from '../../../base/common/async.js';
import { Emitter } from '../../../base/common/event.js';
import { Disposable, MutableDisposable } from '../../../base/common/lifecycle.js';
import { Range } from '../../common/core/range.js';
import { CodeActionProviderRegistry } from '../../common/modes.js';
import { RawContextKey } from '../../../platform/contextkey/common/contextkey.js';
import { getCodeActions } from './codeAction.js';
export var SUPPORTED_CODE_ACTIONS = new RawContextKey('supportedCodeAction', '');
var CodeActionOracle = /** @class */ (function (_super) {
    __extends(CodeActionOracle, _super);
    function CodeActionOracle(_editor, _markerService, _signalChange, _delay) {
        if (_delay === void 0) { _delay = 250; }
        var _this = _super.call(this) || this;
        _this._editor = _editor;
        _this._markerService = _markerService;
        _this._signalChange = _signalChange;
        _this._delay = _delay;
        _this._autoTriggerTimer = _this._register(new TimeoutTimer());
        _this._register(_this._markerService.onMarkerChanged(function (e) { return _this._onMarkerChanges(e); }));
        _this._register(_this._editor.onDidChangeCursorPosition(function () { return _this._onCursorChange(); }));
        return _this;
    }
    CodeActionOracle.prototype.trigger = function (trigger) {
        var selection = this._getRangeOfSelectionUnlessWhitespaceEnclosed(trigger);
        return this._createEventAndSignalChange(trigger, selection);
    };
    CodeActionOracle.prototype._onMarkerChanges = function (resources) {
        var _this = this;
        var model = this._editor.getModel();
        if (!model) {
            return;
        }
        if (resources.some(function (resource) { return resource.toString() === model.uri.toString(); })) {
            this._autoTriggerTimer.cancelAndSet(function () {
                _this.trigger({ type: 'auto' });
            }, this._delay);
        }
    };
    CodeActionOracle.prototype._onCursorChange = function () {
        var _this = this;
        this._autoTriggerTimer.cancelAndSet(function () {
            _this.trigger({ type: 'auto' });
        }, this._delay);
    };
    CodeActionOracle.prototype._getRangeOfMarker = function (selection) {
        var model = this._editor.getModel();
        if (!model) {
            return undefined;
        }
        for (var _i = 0, _a = this._markerService.read({ resource: model.uri }); _i < _a.length; _i++) {
            var marker = _a[_i];
            if (Range.intersectRanges(marker, selection)) {
                return Range.lift(marker);
            }
        }
        return undefined;
    };
    CodeActionOracle.prototype._getRangeOfSelectionUnlessWhitespaceEnclosed = function (trigger) {
        if (!this._editor.hasModel()) {
            return undefined;
        }
        var model = this._editor.getModel();
        var selection = this._editor.getSelection();
        if (selection.isEmpty() && trigger.type === 'auto') {
            var _a = selection.getPosition(), lineNumber = _a.lineNumber, column = _a.column;
            var line = model.getLineContent(lineNumber);
            if (line.length === 0) {
                // empty line
                return undefined;
            }
            else if (column === 1) {
                // look only right
                if (/\s/.test(line[0])) {
                    return undefined;
                }
            }
            else if (column === model.getLineMaxColumn(lineNumber)) {
                // look only left
                if (/\s/.test(line[line.length - 1])) {
                    return undefined;
                }
            }
            else {
                // look left and right
                if (/\s/.test(line[column - 2]) && /\s/.test(line[column - 1])) {
                    return undefined;
                }
            }
        }
        return selection;
    };
    CodeActionOracle.prototype._createEventAndSignalChange = function (trigger, selection) {
        var model = this._editor.getModel();
        if (!selection || !model) {
            // cancel
            this._signalChange(undefined);
            return undefined;
        }
        var markerRange = this._getRangeOfMarker(selection);
        var position = markerRange ? markerRange.getStartPosition() : selection.getStartPosition();
        var e = {
            trigger: trigger,
            selection: selection,
            position: position
        };
        this._signalChange(e);
        return e;
    };
    return CodeActionOracle;
}(Disposable));
export var CodeActionsState;
(function (CodeActionsState) {
    CodeActionsState.Empty = new /** @class */ (function () {
        function class_1() {
            this.type = 0 /* Empty */;
        }
        return class_1;
    }());
    var Triggered = /** @class */ (function () {
        function Triggered(trigger, rangeOrSelection, position, actions) {
            this.trigger = trigger;
            this.rangeOrSelection = rangeOrSelection;
            this.position = position;
            this.actions = actions;
            this.type = 1 /* Triggered */;
        }
        return Triggered;
    }());
    CodeActionsState.Triggered = Triggered;
})(CodeActionsState || (CodeActionsState = {}));
var CodeActionModel = /** @class */ (function (_super) {
    __extends(CodeActionModel, _super);
    function CodeActionModel(_editor, _markerService, contextKeyService, _progressService) {
        var _this = _super.call(this) || this;
        _this._editor = _editor;
        _this._markerService = _markerService;
        _this._progressService = _progressService;
        _this._codeActionOracle = _this._register(new MutableDisposable());
        _this._state = CodeActionsState.Empty;
        _this._onDidChangeState = _this._register(new Emitter());
        _this.onDidChangeState = _this._onDidChangeState.event;
        _this._supportedCodeActions = SUPPORTED_CODE_ACTIONS.bindTo(contextKeyService);
        _this._register(_this._editor.onDidChangeModel(function () { return _this._update(); }));
        _this._register(_this._editor.onDidChangeModelLanguage(function () { return _this._update(); }));
        _this._register(CodeActionProviderRegistry.onDidChange(function () { return _this._update(); }));
        _this._update();
        return _this;
    }
    CodeActionModel.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
        this.setState(CodeActionsState.Empty, true);
    };
    CodeActionModel.prototype._update = function () {
        var _this = this;
        this._codeActionOracle.value = undefined;
        this.setState(CodeActionsState.Empty);
        var model = this._editor.getModel();
        if (model
            && CodeActionProviderRegistry.has(model)
            && !this._editor.getConfiguration().readOnly) {
            var supportedActions = [];
            for (var _i = 0, _a = CodeActionProviderRegistry.all(model); _i < _a.length; _i++) {
                var provider = _a[_i];
                if (Array.isArray(provider.providedCodeActionKinds)) {
                    supportedActions.push.apply(supportedActions, provider.providedCodeActionKinds);
                }
            }
            this._supportedCodeActions.set(supportedActions.join(' '));
            this._codeActionOracle.value = new CodeActionOracle(this._editor, this._markerService, function (trigger) {
                if (!trigger) {
                    _this.setState(CodeActionsState.Empty);
                    return;
                }
                var actions = createCancelablePromise(function (token) { return getCodeActions(model, trigger.selection, trigger.trigger, token); });
                if (_this._progressService && trigger.trigger.type === 'manual') {
                    _this._progressService.showWhile(actions, 250);
                }
                _this.setState(new CodeActionsState.Triggered(trigger.trigger, trigger.selection, trigger.position, actions));
            }, undefined);
            this._codeActionOracle.value.trigger({ type: 'auto' });
        }
        else {
            this._supportedCodeActions.reset();
        }
    };
    CodeActionModel.prototype.trigger = function (trigger) {
        if (this._codeActionOracle.value) {
            this._codeActionOracle.value.trigger(trigger);
        }
    };
    CodeActionModel.prototype.setState = function (newState, skipNotify) {
        if (newState === this._state) {
            return;
        }
        // Cancel old request
        if (this._state.type === 1 /* Triggered */) {
            this._state.actions.cancel();
        }
        this._state = newState;
        if (!skipNotify) {
            this._onDidChangeState.fire(newState);
        }
    };
    return CodeActionModel;
}(Disposable));
export { CodeActionModel };
