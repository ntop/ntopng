/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { isNonEmptyArray } from '../../../base/common/arrays.js';
import { DisposableStore } from '../../../base/common/lifecycle.js';
import { CharacterSet } from '../../common/core/characterClassifier.js';
var CommitCharacterController = /** @class */ (function () {
    function CommitCharacterController(editor, widget, accept) {
        var _this = this;
        this._disposables = new DisposableStore();
        this._disposables.add(widget.onDidShow(function () { return _this._onItem(widget.getFocusedItem()); }));
        this._disposables.add(widget.onDidFocus(this._onItem, this));
        this._disposables.add(widget.onDidHide(this.reset, this));
        this._disposables.add(editor.onWillType(function (text) {
            if (_this._active) {
                var ch = text.charCodeAt(text.length - 1);
                if (_this._active.acceptCharacters.has(ch) && editor.getConfiguration().contribInfo.acceptSuggestionOnCommitCharacter) {
                    accept(_this._active.item);
                }
            }
        }));
    }
    CommitCharacterController.prototype._onItem = function (selected) {
        if (!selected || !isNonEmptyArray(selected.item.completion.commitCharacters)) {
            // no item or no commit characters
            this.reset();
            return;
        }
        if (this._active && this._active.item.item === selected.item) {
            // still the same item
            return;
        }
        // keep item and its commit characters
        var acceptCharacters = new CharacterSet();
        for (var _i = 0, _a = selected.item.completion.commitCharacters; _i < _a.length; _i++) {
            var ch = _a[_i];
            if (ch.length > 0) {
                acceptCharacters.add(ch.charCodeAt(0));
            }
        }
        this._active = { acceptCharacters: acceptCharacters, item: selected };
    };
    CommitCharacterController.prototype.reset = function () {
        this._active = undefined;
    };
    CommitCharacterController.prototype.dispose = function () {
        this._disposables.dispose();
    };
    return CommitCharacterController;
}());
export { CommitCharacterController };
