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
import { renderMarkdown } from '../../../base/browser/markdownRenderer.js';
import { IOpenerService, NullOpenerService } from '../../../platform/opener/common/opener.js';
import { IModeService } from '../../common/services/modeService.js';
import { URI } from '../../../base/common/uri.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { tokenizeToString } from '../../common/modes/textToHtmlTokenizer.js';
import { optional } from '../../../platform/instantiation/common/instantiation.js';
import { Emitter } from '../../../base/common/event.js';
import { DisposableStore, Disposable } from '../../../base/common/lifecycle.js';
import { TokenizationRegistry } from '../../common/modes.js';
var MarkdownRenderer = /** @class */ (function (_super) {
    __extends(MarkdownRenderer, _super);
    function MarkdownRenderer(_editor, _modeService, _openerService) {
        if (_openerService === void 0) { _openerService = NullOpenerService; }
        var _this = _super.call(this) || this;
        _this._editor = _editor;
        _this._modeService = _modeService;
        _this._openerService = _openerService;
        _this._onDidRenderCodeBlock = _this._register(new Emitter());
        _this.onDidRenderCodeBlock = _this._onDidRenderCodeBlock.event;
        return _this;
    }
    MarkdownRenderer.prototype.getOptions = function (disposeables) {
        var _this = this;
        return {
            codeBlockRenderer: function (languageAlias, value) {
                // In markdown,
                // it is possible that we stumble upon language aliases (e.g.js instead of javascript)
                // it is possible no alias is given in which case we fall back to the current editor lang
                var modeId = null;
                if (languageAlias) {
                    modeId = _this._modeService.getModeIdForLanguageName(languageAlias);
                }
                else {
                    var model = _this._editor.getModel();
                    if (model) {
                        modeId = model.getLanguageIdentifier().language;
                    }
                }
                _this._modeService.triggerMode(modeId || '');
                return Promise.resolve(true).then(function (_) {
                    var promise = TokenizationRegistry.getPromise(modeId || '');
                    if (promise) {
                        return promise.then(function (support) { return tokenizeToString(value, support); });
                    }
                    return tokenizeToString(value, undefined);
                }).then(function (code) {
                    return "<span style=\"font-family: " + _this._editor.getConfiguration().fontInfo.fontFamily + "\">" + code + "</span>";
                });
            },
            codeBlockRenderCallback: function () { return _this._onDidRenderCodeBlock.fire(); },
            actionHandler: {
                callback: function (content) {
                    var uri;
                    try {
                        uri = URI.parse(content);
                    }
                    catch (_a) {
                        // ignore
                    }
                    if (uri && _this._openerService) {
                        _this._openerService.open(uri).catch(onUnexpectedError);
                    }
                },
                disposeables: disposeables
            }
        };
    };
    MarkdownRenderer.prototype.render = function (markdown) {
        var disposeables = new DisposableStore();
        var element;
        if (!markdown) {
            element = document.createElement('span');
        }
        else {
            element = renderMarkdown(markdown, this.getOptions(disposeables));
        }
        return {
            element: element,
            dispose: function () { return disposeables.dispose(); }
        };
    };
    MarkdownRenderer = __decorate([
        __param(1, IModeService),
        __param(2, optional(IOpenerService))
    ], MarkdownRenderer);
    return MarkdownRenderer;
}(Disposable));
export { MarkdownRenderer };
