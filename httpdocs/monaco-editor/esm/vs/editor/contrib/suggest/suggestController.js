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
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { alert } from '../../../base/browser/ui/aria/aria.js';
import { isNonEmptyArray } from '../../../base/common/arrays.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { dispose, DisposableStore, toDisposable, MutableDisposable } from '../../../base/common/lifecycle.js';
import { EditorAction, EditorCommand, registerEditorAction, registerEditorCommand, registerEditorContribution } from '../../browser/editorExtensions.js';
import { EditOperation } from '../../common/core/editOperation.js';
import { Range } from '../../common/core/range.js';
import { EditorContextKeys } from '../../common/editorContextKeys.js';
import { SnippetController2 } from '../snippet/snippetController2.js';
import { SnippetParser } from '../snippet/snippetParser.js';
import { ISuggestMemoryService } from './suggestMemory.js';
import * as nls from '../../../nls.js';
import { ICommandService } from '../../../platform/commands/common/commands.js';
import { ContextKeyExpr, IContextKeyService } from '../../../platform/contextkey/common/contextkey.js';
import { IInstantiationService } from '../../../platform/instantiation/common/instantiation.js';
import { Context as SuggestContext } from './suggest.js';
import { SuggestAlternatives } from './suggestAlternatives.js';
import { SuggestModel } from './suggestModel.js';
import { SuggestWidget } from './suggestWidget.js';
import { WordContextKey } from './wordContextKey.js';
import { Event } from '../../../base/common/event.js';
import { IEditorWorkerService } from '../../common/services/editorWorkerService.js';
import { IdleValue } from '../../../base/common/async.js';
import { isObject } from '../../../base/common/types.js';
import { CommitCharacterController } from './suggestCommitCharacters.js';
var _sticky = false; // for development purposes only
var LineSuffix = /** @class */ (function () {
    function LineSuffix(_model, _position) {
        this._model = _model;
        this._position = _position;
        // spy on what's happening right of the cursor. two cases:
        // 1. end of line -> check that it's still end of line
        // 2. mid of line -> add a marker and compute the delta
        var maxColumn = _model.getLineMaxColumn(_position.lineNumber);
        if (maxColumn !== _position.column) {
            var offset = _model.getOffsetAt(_position);
            var end = _model.getPositionAt(offset + 1);
            this._marker = _model.deltaDecorations([], [{
                    range: Range.fromPositions(_position, end),
                    options: { stickiness: 1 /* NeverGrowsWhenTypingAtEdges */ }
                }]);
        }
    }
    LineSuffix.prototype.dispose = function () {
        if (this._marker && !this._model.isDisposed()) {
            this._model.deltaDecorations(this._marker, []);
        }
    };
    LineSuffix.prototype.delta = function (position) {
        if (this._model.isDisposed() || this._position.lineNumber !== position.lineNumber) {
            // bail out early if things seems fishy
            return 0;
        }
        // read the marker (in case suggest was triggered at line end) or compare
        // the cursor to the line end.
        if (this._marker) {
            var range = this._model.getDecorationRange(this._marker[0]);
            var end = this._model.getOffsetAt(range.getStartPosition());
            return end - this._model.getOffsetAt(position);
        }
        else {
            return this._model.getLineMaxColumn(position.lineNumber) - position.column;
        }
    };
    return LineSuffix;
}());
var SuggestController = /** @class */ (function () {
    function SuggestController(_editor, editorWorker, _memoryService, _commandService, _contextKeyService, _instantiationService) {
        var _this = this;
        this._editor = _editor;
        this._memoryService = _memoryService;
        this._commandService = _commandService;
        this._contextKeyService = _contextKeyService;
        this._instantiationService = _instantiationService;
        this._lineSuffix = new MutableDisposable();
        this._toDispose = new DisposableStore();
        this._model = new SuggestModel(this._editor, editorWorker);
        this._widget = new IdleValue(function () {
            var widget = _this._instantiationService.createInstance(SuggestWidget, _this._editor);
            _this._toDispose.add(widget);
            _this._toDispose.add(widget.onDidSelect(function (item) { return _this._insertSuggestion(item, false, true); }, _this));
            // Wire up logic to accept a suggestion on certain characters
            var commitCharacterController = new CommitCharacterController(_this._editor, widget, function (item) { return _this._insertSuggestion(item, false, true); });
            _this._toDispose.add(commitCharacterController);
            _this._toDispose.add(_this._model.onDidSuggest(function (e) {
                if (e.completionModel.items.length === 0) {
                    commitCharacterController.reset();
                }
            }));
            // Wire up makes text edit context key
            var makesTextEdit = SuggestContext.MakesTextEdit.bindTo(_this._contextKeyService);
            _this._toDispose.add(widget.onDidFocus(function (_a) {
                var item = _a.item;
                var position = _this._editor.getPosition();
                var startColumn = item.completion.range.startColumn;
                var endColumn = position.column;
                var value = true;
                if (_this._editor.getConfiguration().contribInfo.acceptSuggestionOnEnter === 'smart'
                    && _this._model.state === 2 /* Auto */
                    && !item.completion.command
                    && !item.completion.additionalTextEdits
                    && !(item.completion.insertTextRules & 4 /* InsertAsSnippet */)
                    && endColumn - startColumn === item.completion.insertText.length) {
                    var oldText = _this._editor.getModel().getValueInRange({
                        startLineNumber: position.lineNumber,
                        startColumn: startColumn,
                        endLineNumber: position.lineNumber,
                        endColumn: endColumn
                    });
                    value = oldText !== item.completion.insertText;
                }
                makesTextEdit.set(value);
            }));
            _this._toDispose.add(toDisposable(function () { return makesTextEdit.reset(); }));
            return widget;
        });
        this._alternatives = new IdleValue(function () {
            return _this._toDispose.add(new SuggestAlternatives(_this._editor, _this._contextKeyService));
        });
        this._toDispose.add(_instantiationService.createInstance(WordContextKey, _editor));
        this._toDispose.add(this._model.onDidTrigger(function (e) {
            _this._widget.getValue().showTriggered(e.auto, e.shy ? 250 : 50);
            _this._lineSuffix.value = new LineSuffix(_this._editor.getModel(), e.position);
        }));
        this._toDispose.add(this._model.onDidSuggest(function (e) {
            if (!e.shy) {
                var index = _this._memoryService.select(_this._editor.getModel(), _this._editor.getPosition(), e.completionModel.items);
                _this._widget.getValue().showSuggestions(e.completionModel, index, e.isFrozen, e.auto);
            }
        }));
        this._toDispose.add(this._model.onDidCancel(function (e) {
            if (!e.retrigger) {
                _this._widget.getValue().hideWidget();
            }
        }));
        this._toDispose.add(this._editor.onDidBlurEditorWidget(function () {
            if (!_sticky) {
                _this._model.cancel();
                _this._model.clear();
            }
        }));
        // Manage the acceptSuggestionsOnEnter context key
        var acceptSuggestionsOnEnter = SuggestContext.AcceptSuggestionsOnEnter.bindTo(_contextKeyService);
        var updateFromConfig = function () {
            var acceptSuggestionOnEnter = _this._editor.getConfiguration().contribInfo.acceptSuggestionOnEnter;
            acceptSuggestionsOnEnter.set(acceptSuggestionOnEnter === 'on' || acceptSuggestionOnEnter === 'smart');
        };
        this._toDispose.add(this._editor.onDidChangeConfiguration(function () { return updateFromConfig(); }));
        updateFromConfig();
    }
    SuggestController.get = function (editor) {
        return editor.getContribution(SuggestController.ID);
    };
    SuggestController.prototype.getId = function () {
        return SuggestController.ID;
    };
    SuggestController.prototype.dispose = function () {
        this._alternatives.dispose();
        this._toDispose.dispose();
        this._widget.dispose();
        this._model.dispose();
        this._lineSuffix.dispose();
    };
    SuggestController.prototype._insertSuggestion = function (event, keepAlternativeSuggestions, undoStops) {
        var _a;
        var _this = this;
        if (!event || !event.item) {
            this._alternatives.getValue().reset();
            this._model.cancel();
            this._model.clear();
            return;
        }
        if (!this._editor.hasModel()) {
            return;
        }
        var model = this._editor.getModel();
        var modelVersionNow = model.getAlternativeVersionId();
        var _b = event.item, suggestion = _b.completion, position = _b.position;
        var editorColumn = this._editor.getPosition().column;
        var columnDelta = editorColumn - position.column;
        // pushing undo stops *before* additional text edits and
        // *after* the main edit
        if (undoStops) {
            this._editor.pushUndoStop();
        }
        if (Array.isArray(suggestion.additionalTextEdits)) {
            this._editor.executeEdits('suggestController.additionalTextEdits', suggestion.additionalTextEdits.map(function (edit) { return EditOperation.replace(Range.lift(edit.range), edit.text); }));
        }
        // keep item in memory
        this._memoryService.memorize(model, this._editor.getPosition(), event.item);
        var insertText = suggestion.insertText;
        if (!(suggestion.insertTextRules & 4 /* InsertAsSnippet */)) {
            insertText = SnippetParser.escape(insertText);
        }
        var overwriteBefore = position.column - suggestion.range.startColumn;
        var overwriteAfter = suggestion.range.endColumn - position.column;
        var suffixDelta = this._lineSuffix.value ? this._lineSuffix.value.delta(this._editor.getPosition()) : 0;
        SnippetController2.get(this._editor).insert(insertText, {
            overwriteBefore: overwriteBefore + columnDelta,
            overwriteAfter: overwriteAfter + suffixDelta,
            undoStopBefore: false,
            undoStopAfter: false,
            adjustWhitespace: !(suggestion.insertTextRules & 1 /* KeepWhitespace */)
        });
        if (undoStops) {
            this._editor.pushUndoStop();
        }
        if (!suggestion.command) {
            // done
            this._model.cancel();
            this._model.clear();
        }
        else if (suggestion.command.id === TriggerSuggestAction.id) {
            // retigger
            this._model.trigger({ auto: true, shy: false }, true);
        }
        else {
            // exec command, done
            (_a = this._commandService).executeCommand.apply(_a, [suggestion.command.id].concat((suggestion.command.arguments ? suggestion.command.arguments.slice() : []))).catch(onUnexpectedError)
                .finally(function () { return _this._model.clear(); }); // <- clear only now, keep commands alive
            this._model.cancel();
        }
        if (keepAlternativeSuggestions) {
            this._alternatives.getValue().set(event, function (next) {
                // this is not so pretty. when inserting the 'next'
                // suggestion we undo until we are at the state at
                // which we were before inserting the previous suggestion...
                while (model.canUndo()) {
                    if (modelVersionNow !== model.getAlternativeVersionId()) {
                        model.undo();
                    }
                    _this._insertSuggestion(next, false, false);
                    break;
                }
            });
        }
        this._alertCompletionItem(event.item);
    };
    SuggestController.prototype._alertCompletionItem = function (_a) {
        var suggestion = _a.completion;
        if (isNonEmptyArray(suggestion.additionalTextEdits)) {
            var msg = nls.localize('arai.alert.snippet', "Accepting '{0}' made {1} additional edits", suggestion.label, suggestion.additionalTextEdits.length);
            alert(msg);
        }
    };
    SuggestController.prototype.triggerSuggest = function (onlyFrom) {
        if (this._editor.hasModel()) {
            this._model.trigger({ auto: false, shy: false }, false, onlyFrom);
            this._editor.revealLine(this._editor.getPosition().lineNumber, 0 /* Smooth */);
            this._editor.focus();
        }
    };
    SuggestController.prototype.triggerSuggestAndAcceptBest = function (arg) {
        var _this = this;
        if (!this._editor.hasModel()) {
            return;
        }
        var positionNow = this._editor.getPosition();
        var fallback = function () {
            if (positionNow.equals(_this._editor.getPosition())) {
                _this._commandService.executeCommand(arg.fallback);
            }
        };
        var makesTextEdit = function (item) {
            if (item.completion.insertTextRules & 4 /* InsertAsSnippet */ || item.completion.additionalTextEdits) {
                // snippet, other editor -> makes edit
                return true;
            }
            var position = _this._editor.getPosition();
            var startColumn = item.completion.range.startColumn;
            var endColumn = position.column;
            if (endColumn - startColumn !== item.completion.insertText.length) {
                // unequal lengths -> makes edit
                return true;
            }
            var textNow = _this._editor.getModel().getValueInRange({
                startLineNumber: position.lineNumber,
                startColumn: startColumn,
                endLineNumber: position.lineNumber,
                endColumn: endColumn
            });
            // unequal text -> makes edit
            return textNow !== item.completion.insertText;
        };
        Event.once(this._model.onDidTrigger)(function (_) {
            // wait for trigger because only then the cancel-event is trustworthy
            var listener = [];
            Event.any(_this._model.onDidTrigger, _this._model.onDidCancel)(function () {
                // retrigger or cancel -> try to type default text
                dispose(listener);
                fallback();
            }, undefined, listener);
            _this._model.onDidSuggest(function (_a) {
                var completionModel = _a.completionModel;
                dispose(listener);
                if (completionModel.items.length === 0) {
                    fallback();
                    return;
                }
                var index = _this._memoryService.select(_this._editor.getModel(), _this._editor.getPosition(), completionModel.items);
                var item = completionModel.items[index];
                if (!makesTextEdit(item)) {
                    fallback();
                    return;
                }
                _this._editor.pushUndoStop();
                _this._insertSuggestion({ index: index, item: item, model: completionModel }, true, false);
            }, undefined, listener);
        });
        this._model.trigger({ auto: false, shy: true });
        this._editor.revealLine(positionNow.lineNumber, 0 /* Smooth */);
        this._editor.focus();
    };
    SuggestController.prototype.acceptSelectedSuggestion = function (keepAlternativeSuggestions) {
        var item = this._widget.getValue().getFocusedItem();
        this._insertSuggestion(item, !!keepAlternativeSuggestions, true);
    };
    SuggestController.prototype.acceptNextSuggestion = function () {
        this._alternatives.getValue().next();
    };
    SuggestController.prototype.acceptPrevSuggestion = function () {
        this._alternatives.getValue().prev();
    };
    SuggestController.prototype.cancelSuggestWidget = function () {
        this._model.cancel();
        this._model.clear();
        this._widget.getValue().hideWidget();
    };
    SuggestController.prototype.selectNextSuggestion = function () {
        this._widget.getValue().selectNext();
    };
    SuggestController.prototype.selectNextPageSuggestion = function () {
        this._widget.getValue().selectNextPage();
    };
    SuggestController.prototype.selectLastSuggestion = function () {
        this._widget.getValue().selectLast();
    };
    SuggestController.prototype.selectPrevSuggestion = function () {
        this._widget.getValue().selectPrevious();
    };
    SuggestController.prototype.selectPrevPageSuggestion = function () {
        this._widget.getValue().selectPreviousPage();
    };
    SuggestController.prototype.selectFirstSuggestion = function () {
        this._widget.getValue().selectFirst();
    };
    SuggestController.prototype.toggleSuggestionDetails = function () {
        this._widget.getValue().toggleDetails();
    };
    SuggestController.prototype.toggleExplainMode = function () {
        this._widget.getValue().toggleExplainMode();
    };
    SuggestController.prototype.toggleSuggestionFocus = function () {
        this._widget.getValue().toggleDetailsFocus();
    };
    SuggestController.ID = 'editor.contrib.suggestController';
    SuggestController = __decorate([
        __param(1, IEditorWorkerService),
        __param(2, ISuggestMemoryService),
        __param(3, ICommandService),
        __param(4, IContextKeyService),
        __param(5, IInstantiationService)
    ], SuggestController);
    return SuggestController;
}());
export { SuggestController };
var TriggerSuggestAction = /** @class */ (function (_super) {
    __extends(TriggerSuggestAction, _super);
    function TriggerSuggestAction() {
        return _super.call(this, {
            id: TriggerSuggestAction.id,
            label: nls.localize('suggest.trigger.label', "Trigger Suggest"),
            alias: 'Trigger Suggest',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCompletionItemProvider),
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: 2048 /* CtrlCmd */ | 10 /* Space */,
                mac: { primary: 256 /* WinCtrl */ | 10 /* Space */ },
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    TriggerSuggestAction.prototype.run = function (accessor, editor) {
        var controller = SuggestController.get(editor);
        if (!controller) {
            return;
        }
        controller.triggerSuggest();
    };
    TriggerSuggestAction.id = 'editor.action.triggerSuggest';
    return TriggerSuggestAction;
}(EditorAction));
export { TriggerSuggestAction };
registerEditorContribution(SuggestController);
registerEditorAction(TriggerSuggestAction);
var weight = 100 /* EditorContrib */ + 90;
var SuggestCommand = EditorCommand.bindToContribution(SuggestController.get);
registerEditorCommand(new SuggestCommand({
    id: 'acceptSelectedSuggestion',
    precondition: SuggestContext.Visible,
    handler: function (x) { return x.acceptSelectedSuggestion(true); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 2 /* Tab */
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'acceptSelectedSuggestionOnEnter',
    precondition: SuggestContext.Visible,
    handler: function (x) { return x.acceptSelectedSuggestion(false); },
    kbOpts: {
        weight: weight,
        kbExpr: ContextKeyExpr.and(EditorContextKeys.textInputFocus, SuggestContext.AcceptSuggestionsOnEnter, SuggestContext.MakesTextEdit),
        primary: 3 /* Enter */
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'hideSuggestWidget',
    precondition: SuggestContext.Visible,
    handler: function (x) { return x.cancelSuggestWidget(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 9 /* Escape */,
        secondary: [1024 /* Shift */ | 9 /* Escape */]
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'selectNextSuggestion',
    precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.MultipleSuggestions),
    handler: function (c) { return c.selectNextSuggestion(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 18 /* DownArrow */,
        secondary: [2048 /* CtrlCmd */ | 18 /* DownArrow */],
        mac: { primary: 18 /* DownArrow */, secondary: [2048 /* CtrlCmd */ | 18 /* DownArrow */, 256 /* WinCtrl */ | 44 /* KEY_N */] }
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'selectNextPageSuggestion',
    precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.MultipleSuggestions),
    handler: function (c) { return c.selectNextPageSuggestion(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 12 /* PageDown */,
        secondary: [2048 /* CtrlCmd */ | 12 /* PageDown */]
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'selectLastSuggestion',
    precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.MultipleSuggestions),
    handler: function (c) { return c.selectLastSuggestion(); }
}));
registerEditorCommand(new SuggestCommand({
    id: 'selectPrevSuggestion',
    precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.MultipleSuggestions),
    handler: function (c) { return c.selectPrevSuggestion(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 16 /* UpArrow */,
        secondary: [2048 /* CtrlCmd */ | 16 /* UpArrow */],
        mac: { primary: 16 /* UpArrow */, secondary: [2048 /* CtrlCmd */ | 16 /* UpArrow */, 256 /* WinCtrl */ | 46 /* KEY_P */] }
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'selectPrevPageSuggestion',
    precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.MultipleSuggestions),
    handler: function (c) { return c.selectPrevPageSuggestion(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 11 /* PageUp */,
        secondary: [2048 /* CtrlCmd */ | 11 /* PageUp */]
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'selectFirstSuggestion',
    precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.MultipleSuggestions),
    handler: function (c) { return c.selectFirstSuggestion(); }
}));
registerEditorCommand(new SuggestCommand({
    id: 'toggleSuggestionDetails',
    precondition: SuggestContext.Visible,
    handler: function (x) { return x.toggleSuggestionDetails(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 2048 /* CtrlCmd */ | 10 /* Space */,
        mac: { primary: 256 /* WinCtrl */ | 10 /* Space */ }
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'toggleExplainMode',
    precondition: SuggestContext.Visible,
    handler: function (x) { return x.toggleExplainMode(); },
    kbOpts: {
        weight: 100 /* EditorContrib */,
        primary: 2048 /* CtrlCmd */ | 85 /* US_SLASH */,
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'toggleSuggestionFocus',
    precondition: SuggestContext.Visible,
    handler: function (x) { return x.toggleSuggestionFocus(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 2048 /* CtrlCmd */ | 512 /* Alt */ | 10 /* Space */,
        mac: { primary: 256 /* WinCtrl */ | 512 /* Alt */ | 10 /* Space */ }
    }
}));
//#region tab completions
registerEditorCommand(new SuggestCommand({
    id: 'insertBestCompletion',
    precondition: ContextKeyExpr.and(ContextKeyExpr.equals('config.editor.tabCompletion', 'on'), WordContextKey.AtEnd, SuggestContext.Visible.toNegated(), SuggestAlternatives.OtherSuggestions.toNegated(), SnippetController2.InSnippetMode.toNegated()),
    handler: function (x, arg) {
        x.triggerSuggestAndAcceptBest(isObject(arg) ? __assign({ fallback: 'tab' }, arg) : { fallback: 'tab' });
    },
    kbOpts: {
        weight: weight,
        primary: 2 /* Tab */
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'insertNextSuggestion',
    precondition: ContextKeyExpr.and(ContextKeyExpr.equals('config.editor.tabCompletion', 'on'), SuggestAlternatives.OtherSuggestions, SuggestContext.Visible.toNegated(), SnippetController2.InSnippetMode.toNegated()),
    handler: function (x) { return x.acceptNextSuggestion(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 2 /* Tab */
    }
}));
registerEditorCommand(new SuggestCommand({
    id: 'insertPrevSuggestion',
    precondition: ContextKeyExpr.and(ContextKeyExpr.equals('config.editor.tabCompletion', 'on'), SuggestAlternatives.OtherSuggestions, SuggestContext.Visible.toNegated(), SnippetController2.InSnippetMode.toNegated()),
    handler: function (x) { return x.acceptPrevSuggestion(); },
    kbOpts: {
        weight: weight,
        kbExpr: EditorContextKeys.textInputFocus,
        primary: 1024 /* Shift */ | 2 /* Tab */
    }
}));
