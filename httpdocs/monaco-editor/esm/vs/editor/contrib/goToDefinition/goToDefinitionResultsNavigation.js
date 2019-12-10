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
import { RawContextKey, IContextKeyService, ContextKeyExpr } from '../../../platform/contextkey/common/contextkey.js';
import { createDecorator } from '../../../platform/instantiation/common/instantiation.js';
import { registerSingleton } from '../../../platform/instantiation/common/extensions.js';
import { KeybindingsRegistry } from '../../../platform/keybinding/common/keybindingsRegistry.js';
import { registerEditorCommand, EditorCommand } from '../../browser/editorExtensions.js';
import { ICodeEditorService } from '../../browser/services/codeEditorService.js';
import { Range } from '../../common/core/range.js';
import { dispose, combinedDisposable, DisposableStore } from '../../../base/common/lifecycle.js';
import { Emitter } from '../../../base/common/event.js';
import { localize } from '../../../nls.js';
import { IKeybindingService } from '../../../platform/keybinding/common/keybinding.js';
import { INotificationService } from '../../../platform/notification/common/notification.js';
export var ctxHasSymbols = new RawContextKey('hasSymbols', false);
export var ISymbolNavigationService = createDecorator('ISymbolNavigationService');
var SymbolNavigationService = /** @class */ (function () {
    function SymbolNavigationService(contextKeyService, _editorService, _notificationService, _keybindingService) {
        this._editorService = _editorService;
        this._notificationService = _notificationService;
        this._keybindingService = _keybindingService;
        this._currentModel = undefined;
        this._currentIdx = -1;
        this._ignoreEditorChange = false;
        this._ctxHasSymbols = ctxHasSymbols.bindTo(contextKeyService);
    }
    SymbolNavigationService.prototype.reset = function () {
        this._ctxHasSymbols.reset();
        dispose(this._currentState);
        dispose(this._currentMessage);
        this._currentModel = undefined;
        this._currentIdx = -1;
    };
    SymbolNavigationService.prototype.put = function (anchor) {
        var _this = this;
        var refModel = anchor.parent.parent;
        if (refModel.references.length <= 1) {
            this.reset();
            return;
        }
        this._currentModel = refModel;
        this._currentIdx = refModel.references.indexOf(anchor);
        this._ctxHasSymbols.set(true);
        this._showMessage();
        var editorState = new EditorState(this._editorService);
        var listener = editorState.onDidChange(function (_) {
            if (_this._ignoreEditorChange) {
                return;
            }
            var editor = _this._editorService.getActiveCodeEditor();
            if (!editor) {
                return;
            }
            var model = editor.getModel();
            var position = editor.getPosition();
            if (!model || !position) {
                return;
            }
            var seenUri = false;
            var seenPosition = false;
            for (var _i = 0, _a = refModel.references; _i < _a.length; _i++) {
                var reference = _a[_i];
                if (reference.uri.toString() === model.uri.toString()) {
                    seenUri = true;
                    seenPosition = seenPosition || Range.containsPosition(reference.range, position);
                }
                else if (seenUri) {
                    break;
                }
            }
            if (!seenUri || !seenPosition) {
                _this.reset();
            }
        });
        this._currentState = combinedDisposable(editorState, listener);
    };
    SymbolNavigationService.prototype.revealNext = function (source) {
        var _this = this;
        if (!this._currentModel) {
            return Promise.resolve();
        }
        // get next result and advance
        this._currentIdx += 1;
        this._currentIdx %= this._currentModel.references.length;
        var reference = this._currentModel.references[this._currentIdx];
        // status
        this._showMessage();
        // open editor, ignore events while that happens
        this._ignoreEditorChange = true;
        return this._editorService.openCodeEditor({
            resource: reference.uri,
            options: {
                selection: Range.collapseToStart(reference.range),
                revealInCenterIfOutsideViewport: true
            }
        }, source).finally(function () {
            _this._ignoreEditorChange = false;
        });
    };
    SymbolNavigationService.prototype._showMessage = function () {
        dispose(this._currentMessage);
        var kb = this._keybindingService.lookupKeybinding('editor.gotoNextSymbolFromResult');
        var message = kb
            ? localize('location.kb', "Symbol {0} of {1}, {2} for next", this._currentIdx + 1, this._currentModel.references.length, kb.getLabel())
            : localize('location', "Symbol {0} of {1}", this._currentIdx + 1, this._currentModel.references.length);
        this._currentMessage = this._notificationService.status(message);
    };
    SymbolNavigationService = __decorate([
        __param(0, IContextKeyService),
        __param(1, ICodeEditorService),
        __param(2, INotificationService),
        __param(3, IKeybindingService)
    ], SymbolNavigationService);
    return SymbolNavigationService;
}());
registerSingleton(ISymbolNavigationService, SymbolNavigationService, true);
registerEditorCommand(new /** @class */ (function (_super) {
    __extends(class_1, _super);
    function class_1() {
        return _super.call(this, {
            id: 'editor.gotoNextSymbolFromResult',
            precondition: ContextKeyExpr.and(ctxHasSymbols, ContextKeyExpr.equals('config.editor.gotoLocation.multiple', 'goto')),
            kbOpts: {
                weight: 100 /* EditorContrib */,
                primary: 70 /* F12 */
            }
        }) || this;
    }
    class_1.prototype.runEditorCommand = function (accessor, editor) {
        return accessor.get(ISymbolNavigationService).revealNext(editor);
    };
    return class_1;
}(EditorCommand)));
KeybindingsRegistry.registerCommandAndKeybindingRule({
    id: 'editor.gotoNextSymbolFromResult.cancel',
    weight: 100 /* EditorContrib */,
    when: ctxHasSymbols,
    primary: 9 /* Escape */,
    handler: function (accessor) {
        accessor.get(ISymbolNavigationService).reset();
    }
});
//
var EditorState = /** @class */ (function () {
    function EditorState(editorService) {
        this._listener = new Map();
        this._disposables = new DisposableStore();
        this._onDidChange = new Emitter();
        this.onDidChange = this._onDidChange.event;
        this._disposables.add(editorService.onCodeEditorRemove(this._onDidRemoveEditor, this));
        this._disposables.add(editorService.onCodeEditorAdd(this._onDidAddEditor, this));
        editorService.listCodeEditors().forEach(this._onDidAddEditor, this);
    }
    EditorState.prototype.dispose = function () {
        this._disposables.dispose();
        this._onDidChange.dispose();
        this._listener.forEach(dispose);
    };
    EditorState.prototype._onDidAddEditor = function (editor) {
        var _this = this;
        this._listener.set(editor, combinedDisposable(editor.onDidChangeCursorPosition(function (_) { return _this._onDidChange.fire({ editor: editor }); }), editor.onDidChangeModelContent(function (_) { return _this._onDidChange.fire({ editor: editor }); })));
    };
    EditorState.prototype._onDidRemoveEditor = function (editor) {
        dispose(this._listener.get(editor));
        this._listener.delete(editor);
    };
    EditorState = __decorate([
        __param(0, ICodeEditorService)
    ], EditorState);
    return EditorState;
}());
