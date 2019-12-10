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
import { RawContextKey, IContextKeyService } from '../../../platform/contextkey/common/contextkey.js';
import { dispose, Disposable } from '../../../base/common/lifecycle.js';
var WordContextKey = /** @class */ (function (_super) {
    __extends(WordContextKey, _super);
    function WordContextKey(_editor, contextKeyService) {
        var _this = _super.call(this) || this;
        _this._editor = _editor;
        _this._enabled = false;
        _this._ckAtEnd = WordContextKey.AtEnd.bindTo(contextKeyService);
        _this._register(_this._editor.onDidChangeConfiguration(function (e) { return e.contribInfo && _this._update(); }));
        _this._update();
        return _this;
    }
    WordContextKey.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
        dispose(this._selectionListener);
        this._ckAtEnd.reset();
    };
    WordContextKey.prototype._update = function () {
        var _this = this;
        // only update this when tab completions are enabled
        var enabled = this._editor.getConfiguration().contribInfo.tabCompletion === 'on';
        if (this._enabled === enabled) {
            return;
        }
        this._enabled = enabled;
        if (this._enabled) {
            var checkForWordEnd = function () {
                if (!_this._editor.hasModel()) {
                    _this._ckAtEnd.set(false);
                    return;
                }
                var model = _this._editor.getModel();
                var selection = _this._editor.getSelection();
                var word = model.getWordAtPosition(selection.getStartPosition());
                if (!word) {
                    _this._ckAtEnd.set(false);
                    return;
                }
                _this._ckAtEnd.set(word.endColumn === selection.getStartPosition().column);
            };
            this._selectionListener = this._editor.onDidChangeCursorSelection(checkForWordEnd);
            checkForWordEnd();
        }
        else if (this._selectionListener) {
            this._ckAtEnd.reset();
            this._selectionListener.dispose();
            this._selectionListener = undefined;
        }
    };
    WordContextKey.AtEnd = new RawContextKey('atEndOfWord', false);
    WordContextKey = __decorate([
        __param(1, IContextKeyService)
    ], WordContextKey);
    return WordContextKey;
}(Disposable));
export { WordContextKey };
