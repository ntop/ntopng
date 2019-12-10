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
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
import { createCancelablePromise, Delayer } from '../../../base/common/async.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { Emitter } from '../../../base/common/event.js';
import { Disposable, MutableDisposable } from '../../../base/common/lifecycle.js';
import { CharacterSet } from '../../common/core/characterClassifier.js';
import * as modes from '../../common/modes.js';
import { provideSignatureHelp } from './provideSignatureHelp.js';
var ParameterHintState;
(function (ParameterHintState) {
    ParameterHintState.Default = new /** @class */ (function () {
        function class_1() {
            this.type = 0 /* Default */;
        }
        return class_1;
    }());
    var Pending = /** @class */ (function () {
        function Pending(request) {
            this.request = request;
            this.type = 2 /* Pending */;
        }
        return Pending;
    }());
    ParameterHintState.Pending = Pending;
    var Active = /** @class */ (function () {
        function Active(hints) {
            this.hints = hints;
            this.type = 1 /* Active */;
        }
        return Active;
    }());
    ParameterHintState.Active = Active;
})(ParameterHintState || (ParameterHintState = {}));
var ParameterHintsModel = /** @class */ (function (_super) {
    __extends(ParameterHintsModel, _super);
    function ParameterHintsModel(editor, delay) {
        if (delay === void 0) { delay = ParameterHintsModel.DEFAULT_DELAY; }
        var _this = _super.call(this) || this;
        _this._onChangedHints = _this._register(new Emitter());
        _this.onChangedHints = _this._onChangedHints.event;
        _this.triggerOnType = false;
        _this._state = ParameterHintState.Default;
        _this._lastSignatureHelpResult = _this._register(new MutableDisposable());
        _this.triggerChars = new CharacterSet();
        _this.retriggerChars = new CharacterSet();
        _this.triggerId = 0;
        _this.editor = editor;
        _this.throttledDelayer = new Delayer(delay);
        _this._register(_this.editor.onDidChangeConfiguration(function () { return _this.onEditorConfigurationChange(); }));
        _this._register(_this.editor.onDidChangeModel(function (e) { return _this.onModelChanged(); }));
        _this._register(_this.editor.onDidChangeModelLanguage(function (_) { return _this.onModelChanged(); }));
        _this._register(_this.editor.onDidChangeCursorSelection(function (e) { return _this.onCursorChange(e); }));
        _this._register(_this.editor.onDidChangeModelContent(function (e) { return _this.onModelContentChange(); }));
        _this._register(modes.SignatureHelpProviderRegistry.onDidChange(_this.onModelChanged, _this));
        _this._register(_this.editor.onDidType(function (text) { return _this.onDidType(text); }));
        _this.onEditorConfigurationChange();
        _this.onModelChanged();
        return _this;
    }
    Object.defineProperty(ParameterHintsModel.prototype, "state", {
        get: function () { return this._state; },
        set: function (value) {
            if (this._state.type === 2 /* Pending */) {
                this._state.request.cancel();
            }
            this._state = value;
        },
        enumerable: true,
        configurable: true
    });
    ParameterHintsModel.prototype.cancel = function (silent) {
        if (silent === void 0) { silent = false; }
        this.state = ParameterHintState.Default;
        this.throttledDelayer.cancel();
        if (!silent) {
            this._onChangedHints.fire(undefined);
        }
    };
    ParameterHintsModel.prototype.trigger = function (context, delay) {
        var _this = this;
        var model = this.editor.getModel();
        if (!model || !modes.SignatureHelpProviderRegistry.has(model)) {
            return;
        }
        var triggerId = ++this.triggerId;
        this.throttledDelayer.trigger(function () { return _this.doTrigger({
            triggerKind: context.triggerKind,
            triggerCharacter: context.triggerCharacter,
            isRetrigger: _this.state.type === 1 /* Active */ || _this.state.type === 2 /* Pending */,
            activeSignatureHelp: _this.state.type === 1 /* Active */ ? _this.state.hints : undefined
        }, triggerId); }, delay).then(undefined, onUnexpectedError);
    };
    ParameterHintsModel.prototype.next = function () {
        if (this.state.type !== 1 /* Active */) {
            return;
        }
        var length = this.state.hints.signatures.length;
        var activeSignature = this.state.hints.activeSignature;
        var last = (activeSignature % length) === (length - 1);
        var cycle = this.editor.getConfiguration().contribInfo.parameterHints.cycle;
        // If there is only one signature, or we're on last signature of list
        if ((length < 2 || last) && !cycle) {
            this.cancel();
            return;
        }
        this.updateActiveSignature(last && cycle ? 0 : activeSignature + 1);
    };
    ParameterHintsModel.prototype.previous = function () {
        if (this.state.type !== 1 /* Active */) {
            return;
        }
        var length = this.state.hints.signatures.length;
        var activeSignature = this.state.hints.activeSignature;
        var first = activeSignature === 0;
        var cycle = this.editor.getConfiguration().contribInfo.parameterHints.cycle;
        // If there is only one signature, or we're on first signature of list
        if ((length < 2 || first) && !cycle) {
            this.cancel();
            return;
        }
        this.updateActiveSignature(first && cycle ? length - 1 : activeSignature - 1);
    };
    ParameterHintsModel.prototype.updateActiveSignature = function (activeSignature) {
        if (this.state.type !== 1 /* Active */) {
            return;
        }
        this.state = new ParameterHintState.Active(__assign({}, this.state.hints, { activeSignature: activeSignature }));
        this._onChangedHints.fire(this.state.hints);
    };
    ParameterHintsModel.prototype.doTrigger = function (triggerContext, triggerId) {
        var _this = this;
        this.cancel(true);
        if (!this.editor.hasModel()) {
            return Promise.resolve(false);
        }
        var model = this.editor.getModel();
        var position = this.editor.getPosition();
        this.state = new ParameterHintState.Pending(createCancelablePromise(function (token) {
            return provideSignatureHelp(model, position, triggerContext, token);
        }));
        return this.state.request.then(function (result) {
            // Check that we are still resolving the correct signature help
            if (triggerId !== _this.triggerId) {
                if (result) {
                    result.dispose();
                }
                return false;
            }
            if (!result || !result.value.signatures || result.value.signatures.length === 0) {
                if (result) {
                    result.dispose();
                }
                _this._lastSignatureHelpResult.clear();
                _this.cancel();
                return false;
            }
            else {
                _this.state = new ParameterHintState.Active(result.value);
                _this._lastSignatureHelpResult.value = result;
                _this._onChangedHints.fire(_this.state.hints);
                return true;
            }
        }).catch(function (error) {
            if (triggerId === _this.triggerId) {
                _this.state = ParameterHintState.Default;
            }
            onUnexpectedError(error);
            return false;
        });
    };
    Object.defineProperty(ParameterHintsModel.prototype, "isTriggered", {
        get: function () {
            return this.state.type === 1 /* Active */
                || this.state.type === 2 /* Pending */
                || this.throttledDelayer.isTriggered();
        },
        enumerable: true,
        configurable: true
    });
    ParameterHintsModel.prototype.onModelChanged = function () {
        this.cancel();
        // Update trigger characters
        this.triggerChars = new CharacterSet();
        this.retriggerChars = new CharacterSet();
        var model = this.editor.getModel();
        if (!model) {
            return;
        }
        for (var _i = 0, _a = modes.SignatureHelpProviderRegistry.ordered(model); _i < _a.length; _i++) {
            var support = _a[_i];
            for (var _b = 0, _c = support.signatureHelpTriggerCharacters || []; _b < _c.length; _b++) {
                var ch = _c[_b];
                this.triggerChars.add(ch.charCodeAt(0));
                // All trigger characters are also considered retrigger characters
                this.retriggerChars.add(ch.charCodeAt(0));
            }
            for (var _d = 0, _e = support.signatureHelpRetriggerCharacters || []; _d < _e.length; _d++) {
                var ch = _e[_d];
                this.retriggerChars.add(ch.charCodeAt(0));
            }
        }
    };
    ParameterHintsModel.prototype.onDidType = function (text) {
        if (!this.triggerOnType) {
            return;
        }
        var lastCharIndex = text.length - 1;
        var triggerCharCode = text.charCodeAt(lastCharIndex);
        if (this.triggerChars.has(triggerCharCode) || this.isTriggered && this.retriggerChars.has(triggerCharCode)) {
            this.trigger({
                triggerKind: modes.SignatureHelpTriggerKind.TriggerCharacter,
                triggerCharacter: text.charAt(lastCharIndex),
            });
        }
    };
    ParameterHintsModel.prototype.onCursorChange = function (e) {
        if (e.source === 'mouse') {
            this.cancel();
        }
        else if (this.isTriggered) {
            this.trigger({ triggerKind: modes.SignatureHelpTriggerKind.ContentChange });
        }
    };
    ParameterHintsModel.prototype.onModelContentChange = function () {
        if (this.isTriggered) {
            this.trigger({ triggerKind: modes.SignatureHelpTriggerKind.ContentChange });
        }
    };
    ParameterHintsModel.prototype.onEditorConfigurationChange = function () {
        this.triggerOnType = this.editor.getConfiguration().contribInfo.parameterHints.enabled;
        if (!this.triggerOnType) {
            this.cancel();
        }
    };
    ParameterHintsModel.prototype.dispose = function () {
        this.cancel(true);
        _super.prototype.dispose.call(this);
    };
    ParameterHintsModel.DEFAULT_DELAY = 120; // ms
    return ParameterHintsModel;
}(Disposable));
export { ParameterHintsModel };
