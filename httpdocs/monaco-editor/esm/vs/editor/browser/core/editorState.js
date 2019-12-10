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
import * as strings from '../../../base/common/strings.js';
import { CancellationTokenSource } from '../../../base/common/cancellation.js';
import { DisposableStore } from '../../../base/common/lifecycle.js';
import { EditorKeybindingCancellationTokenSource } from './keybindingCancellation.js';
var EditorState = /** @class */ (function () {
    function EditorState(editor, flags) {
        this.flags = flags;
        if ((this.flags & 1 /* Value */) !== 0) {
            var model = editor.getModel();
            this.modelVersionId = model ? strings.format('{0}#{1}', model.uri.toString(), model.getVersionId()) : null;
        }
        else {
            this.modelVersionId = null;
        }
        if ((this.flags & 4 /* Position */) !== 0) {
            this.position = editor.getPosition();
        }
        else {
            this.position = null;
        }
        if ((this.flags & 2 /* Selection */) !== 0) {
            this.selection = editor.getSelection();
        }
        else {
            this.selection = null;
        }
        if ((this.flags & 8 /* Scroll */) !== 0) {
            this.scrollLeft = editor.getScrollLeft();
            this.scrollTop = editor.getScrollTop();
        }
        else {
            this.scrollLeft = -1;
            this.scrollTop = -1;
        }
    }
    EditorState.prototype._equals = function (other) {
        if (!(other instanceof EditorState)) {
            return false;
        }
        var state = other;
        if (this.modelVersionId !== state.modelVersionId) {
            return false;
        }
        if (this.scrollLeft !== state.scrollLeft || this.scrollTop !== state.scrollTop) {
            return false;
        }
        if (!this.position && state.position || this.position && !state.position || this.position && state.position && !this.position.equals(state.position)) {
            return false;
        }
        if (!this.selection && state.selection || this.selection && !state.selection || this.selection && state.selection && !this.selection.equalsRange(state.selection)) {
            return false;
        }
        return true;
    };
    EditorState.prototype.validate = function (editor) {
        return this._equals(new EditorState(editor, this.flags));
    };
    return EditorState;
}());
export { EditorState };
/**
 * A cancellation token source that cancels when the editor changes as expressed
 * by the provided flags
 */
var EditorStateCancellationTokenSource = /** @class */ (function (_super) {
    __extends(EditorStateCancellationTokenSource, _super);
    function EditorStateCancellationTokenSource(editor, flags, parent) {
        var _this = _super.call(this, editor, parent) || this;
        _this.editor = editor;
        _this._listener = new DisposableStore();
        if (flags & 4 /* Position */) {
            _this._listener.add(editor.onDidChangeCursorPosition(function (_) { return _this.cancel(); }));
        }
        if (flags & 2 /* Selection */) {
            _this._listener.add(editor.onDidChangeCursorSelection(function (_) { return _this.cancel(); }));
        }
        if (flags & 8 /* Scroll */) {
            _this._listener.add(editor.onDidScrollChange(function (_) { return _this.cancel(); }));
        }
        if (flags & 1 /* Value */) {
            _this._listener.add(editor.onDidChangeModel(function (_) { return _this.cancel(); }));
            _this._listener.add(editor.onDidChangeModelContent(function (_) { return _this.cancel(); }));
        }
        return _this;
    }
    EditorStateCancellationTokenSource.prototype.dispose = function () {
        this._listener.dispose();
        _super.prototype.dispose.call(this);
    };
    return EditorStateCancellationTokenSource;
}(EditorKeybindingCancellationTokenSource));
export { EditorStateCancellationTokenSource };
/**
 * A cancellation token source that cancels when the provided model changes
 */
var TextModelCancellationTokenSource = /** @class */ (function (_super) {
    __extends(TextModelCancellationTokenSource, _super);
    function TextModelCancellationTokenSource(model, parent) {
        var _this = _super.call(this, parent) || this;
        _this._listener = model.onDidChangeContent(function () { return _this.cancel(); });
        return _this;
    }
    TextModelCancellationTokenSource.prototype.dispose = function () {
        this._listener.dispose();
        _super.prototype.dispose.call(this);
    };
    return TextModelCancellationTokenSource;
}(CancellationTokenSource));
export { TextModelCancellationTokenSource };
var StableEditorScrollState = /** @class */ (function () {
    function StableEditorScrollState(_visiblePosition, _visiblePositionScrollDelta) {
        this._visiblePosition = _visiblePosition;
        this._visiblePositionScrollDelta = _visiblePositionScrollDelta;
    }
    StableEditorScrollState.capture = function (editor) {
        var visiblePosition = null;
        var visiblePositionScrollDelta = 0;
        if (editor.getScrollTop() !== 0) {
            var visibleRanges = editor.getVisibleRanges();
            if (visibleRanges.length > 0) {
                visiblePosition = visibleRanges[0].getStartPosition();
                var visiblePositionScrollTop = editor.getTopForPosition(visiblePosition.lineNumber, visiblePosition.column);
                visiblePositionScrollDelta = editor.getScrollTop() - visiblePositionScrollTop;
            }
        }
        return new StableEditorScrollState(visiblePosition, visiblePositionScrollDelta);
    };
    StableEditorScrollState.prototype.restore = function (editor) {
        if (this._visiblePosition) {
            var visiblePositionScrollTop = editor.getTopForPosition(this._visiblePosition.lineNumber, this._visiblePosition.column);
            editor.setScrollTop(visiblePositionScrollTop + this._visiblePositionScrollDelta);
        }
    };
    return StableEditorScrollState;
}());
export { StableEditorScrollState };
