/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
'use strict';
import * as cssService from './_deps/vscode-css-languageservice/cssLanguageService.js';
import * as ls from './_deps/vscode-languageserver-types/main.js';
var CSSWorker = /** @class */ (function () {
    function CSSWorker(ctx, createData) {
        this._ctx = ctx;
        this._languageSettings = createData.languageSettings;
        this._languageId = createData.languageId;
        switch (this._languageId) {
            case 'css':
                this._languageService = cssService.getCSSLanguageService();
                break;
            case 'less':
                this._languageService = cssService.getLESSLanguageService();
                break;
            case 'scss':
                this._languageService = cssService.getSCSSLanguageService();
                break;
            default:
                throw new Error('Invalid language id: ' + this._languageId);
        }
        this._languageService.configure(this._languageSettings);
    }
    // --- language service host ---------------
    CSSWorker.prototype.doValidation = function (uri) {
        var document = this._getTextDocument(uri);
        if (document) {
            var stylesheet = this._languageService.parseStylesheet(document);
            var diagnostics = this._languageService.doValidation(document, stylesheet);
            return Promise.resolve(diagnostics);
        }
        return Promise.resolve([]);
    };
    CSSWorker.prototype.doComplete = function (uri, position) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var completions = this._languageService.doComplete(document, position, stylesheet);
        return Promise.resolve(completions);
    };
    CSSWorker.prototype.doHover = function (uri, position) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var hover = this._languageService.doHover(document, position, stylesheet);
        return Promise.resolve(hover);
    };
    CSSWorker.prototype.findDefinition = function (uri, position) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var definition = this._languageService.findDefinition(document, position, stylesheet);
        return Promise.resolve(definition);
    };
    CSSWorker.prototype.findReferences = function (uri, position) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var references = this._languageService.findReferences(document, position, stylesheet);
        return Promise.resolve(references);
    };
    CSSWorker.prototype.findDocumentHighlights = function (uri, position) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var highlights = this._languageService.findDocumentHighlights(document, position, stylesheet);
        return Promise.resolve(highlights);
    };
    CSSWorker.prototype.findDocumentSymbols = function (uri) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var symbols = this._languageService.findDocumentSymbols(document, stylesheet);
        return Promise.resolve(symbols);
    };
    CSSWorker.prototype.doCodeActions = function (uri, range, context) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var actions = this._languageService.doCodeActions(document, range, context, stylesheet);
        return Promise.resolve(actions);
    };
    CSSWorker.prototype.findDocumentColors = function (uri) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var colorSymbols = this._languageService.findDocumentColors(document, stylesheet);
        return Promise.resolve(colorSymbols);
    };
    CSSWorker.prototype.getColorPresentations = function (uri, color, range) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var colorPresentations = this._languageService.getColorPresentations(document, stylesheet, color, range);
        return Promise.resolve(colorPresentations);
    };
    CSSWorker.prototype.provideFoldingRanges = function (uri, context) {
        var document = this._getTextDocument(uri);
        var ranges = this._languageService.getFoldingRanges(document, context);
        return Promise.resolve(ranges);
    };
    CSSWorker.prototype.doRename = function (uri, position, newName) {
        var document = this._getTextDocument(uri);
        var stylesheet = this._languageService.parseStylesheet(document);
        var renames = this._languageService.doRename(document, position, newName, stylesheet);
        return Promise.resolve(renames);
    };
    CSSWorker.prototype._getTextDocument = function (uri) {
        var models = this._ctx.getMirrorModels();
        for (var _i = 0, models_1 = models; _i < models_1.length; _i++) {
            var model = models_1[_i];
            if (model.uri.toString() === uri) {
                return ls.TextDocument.create(uri, this._languageId, model.version, model.getValue());
            }
        }
        return null;
    };
    return CSSWorker;
}());
export { CSSWorker };
export function create(ctx, createData) {
    return new CSSWorker(ctx, createData);
}
