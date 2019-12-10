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
import { EditorCommand, registerEditorCommand } from '../editorExtensions.js';
import { IContextKeyService, RawContextKey } from '../../../platform/contextkey/common/contextkey.js';
import { CancellationTokenSource } from '../../../base/common/cancellation.js';
import { LinkedList } from '../../../base/common/linkedList.js';
import { createDecorator } from '../../../platform/instantiation/common/instantiation.js';
import { registerSingleton } from '../../../platform/instantiation/common/extensions.js';
var IEditorCancellationTokens = createDecorator('IEditorCancelService');
var ctxCancellableOperation = new RawContextKey('cancellableOperation', false);
registerSingleton(IEditorCancellationTokens, /** @class */ (function () {
    function class_1() {
        this._tokens = new WeakMap();
    }
    class_1.prototype.add = function (editor, cts) {
        var data = this._tokens.get(editor);
        if (!data) {
            data = editor.invokeWithinContext(function (accessor) {
                var key = ctxCancellableOperation.bindTo(accessor.get(IContextKeyService));
                var tokens = new LinkedList();
                return { key: key, tokens: tokens };
            });
            this._tokens.set(editor, data);
        }
        var removeFn;
        data.key.set(true);
        removeFn = data.tokens.push(cts);
        return function () {
            // remove w/o cancellation
            if (removeFn) {
                removeFn();
                data.key.set(!data.tokens.isEmpty());
                removeFn = undefined;
            }
        };
    };
    class_1.prototype.cancel = function (editor) {
        var data = this._tokens.get(editor);
        if (!data) {
            return;
        }
        // remove with cancellation
        var cts = data.tokens.pop();
        if (cts) {
            cts.cancel();
            data.key.set(!data.tokens.isEmpty());
        }
    };
    return class_1;
}()), true);
var EditorKeybindingCancellationTokenSource = /** @class */ (function (_super) {
    __extends(EditorKeybindingCancellationTokenSource, _super);
    function EditorKeybindingCancellationTokenSource(editor, parent) {
        var _this = _super.call(this, parent) || this;
        _this.editor = editor;
        _this._unregister = editor.invokeWithinContext(function (accessor) { return accessor.get(IEditorCancellationTokens).add(editor, _this); });
        return _this;
    }
    EditorKeybindingCancellationTokenSource.prototype.dispose = function () {
        this._unregister();
        _super.prototype.dispose.call(this);
    };
    return EditorKeybindingCancellationTokenSource;
}(CancellationTokenSource));
export { EditorKeybindingCancellationTokenSource };
registerEditorCommand(new /** @class */ (function (_super) {
    __extends(class_2, _super);
    function class_2() {
        return _super.call(this, {
            id: 'editor.cancelOperation',
            kbOpts: {
                weight: 100 /* EditorContrib */,
                primary: 9 /* Escape */
            },
            precondition: ctxCancellableOperation
        }) || this;
    }
    class_2.prototype.runEditorCommand = function (accessor, editor) {
        accessor.get(IEditorCancellationTokens).cancel(editor);
    };
    return class_2;
}(EditorCommand)));
