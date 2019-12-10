/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
'use strict';
import { WorkerManager } from './workerManager.js';
import * as languageFeatures from './languageFeatures.js';
import { createTokenizationSupport } from './tokenization.js';
export function setupMode(defaults) {
    var disposables = [];
    var providers = [];
    var client = new WorkerManager(defaults);
    disposables.push(client);
    var worker = function () {
        var uris = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            uris[_i] = arguments[_i];
        }
        return client.getLanguageServiceWorker.apply(client, uris);
    };
    function registerProviders() {
        var languageId = defaults.languageId, modeConfiguration = defaults.modeConfiguration;
        disposeAll(providers);
        if (modeConfiguration.documentFormattingEdits) {
            providers.push(monaco.languages.registerDocumentFormattingEditProvider(languageId, new languageFeatures.DocumentFormattingEditProvider(worker)));
        }
        if (modeConfiguration.documentRangeFormattingEdits) {
            providers.push(monaco.languages.registerDocumentRangeFormattingEditProvider(languageId, new languageFeatures.DocumentRangeFormattingEditProvider(worker)));
        }
        if (modeConfiguration.completionItems) {
            providers.push(monaco.languages.registerCompletionItemProvider(languageId, new languageFeatures.CompletionAdapter(worker)));
        }
        if (modeConfiguration.hovers) {
            providers.push(monaco.languages.registerHoverProvider(languageId, new languageFeatures.HoverAdapter(worker)));
        }
        if (modeConfiguration.documentSymbols) {
            providers.push(monaco.languages.registerDocumentSymbolProvider(languageId, new languageFeatures.DocumentSymbolAdapter(worker)));
        }
        if (modeConfiguration.tokens) {
            providers.push(monaco.languages.setTokensProvider(languageId, createTokenizationSupport(true)));
        }
        if (modeConfiguration.colors) {
            providers.push(monaco.languages.registerColorProvider(languageId, new languageFeatures.DocumentColorAdapter(worker)));
        }
        if (modeConfiguration.foldingRanges) {
            providers.push(monaco.languages.registerFoldingRangeProvider(languageId, new languageFeatures.FoldingRangeAdapter(worker)));
        }
        if (modeConfiguration.diagnostics) {
            providers.push(new languageFeatures.DiagnosticsAdapter(languageId, worker, defaults));
        }
    }
    registerProviders();
    disposables.push(monaco.languages.setLanguageConfiguration(defaults.languageId, richEditConfiguration));
    var modeConfiguration = defaults.modeConfiguration;
    defaults.onDidChange(function (newDefaults) {
        if (newDefaults.modeConfiguration !== modeConfiguration) {
            modeConfiguration = newDefaults.modeConfiguration;
            registerProviders();
        }
    });
    disposables.push(asDisposable(providers));
    return asDisposable(disposables);
}
function asDisposable(disposables) {
    return { dispose: function () { return disposeAll(disposables); } };
}
function disposeAll(disposables) {
    while (disposables.length) {
        disposables.pop().dispose();
    }
}
var richEditConfiguration = {
    wordPattern: /(-?\d*\.\d\w*)|([^\[\{\]\}\:\"\,\s]+)/g,
    comments: {
        lineComment: '//',
        blockComment: ['/*', '*/']
    },
    brackets: [
        ['{', '}'],
        ['[', ']']
    ],
    autoClosingPairs: [
        { open: '{', close: '}', notIn: ['string'] },
        { open: '[', close: ']', notIn: ['string'] },
        { open: '"', close: '"', notIn: ['string'] }
    ]
};
