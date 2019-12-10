/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { createScanner } from './parser/htmlScanner.js';
import { parse } from './parser/htmlParser.js';
import { HTMLCompletion } from './services/htmlCompletion.js';
import { doHover } from './services/htmlHover.js';
import { format } from './services/htmlFormatter.js';
import { findDocumentLinks } from './services/htmlLinks.js';
import { findDocumentHighlights } from './services/htmlHighlighting.js';
import { findDocumentSymbols } from './services/htmlSymbolsProvider.js';
import { getFoldingRanges } from './services/htmlFolding.js';
import { getSelectionRanges } from './services/htmlSelectionRange.js';
import { handleCustomDataProviders } from './languageFacts/builtinDataProviders.js';
import { HTMLDataProvider } from './languageFacts/dataProvider.js';
export * from './htmlLanguageTypes.js';
export * from '../vscode-languageserver-types/main.js';
export function getLanguageService(options) {
    var htmlCompletion = new HTMLCompletion();
    if (options && options.customDataProviders) {
        handleCustomDataProviders(options.customDataProviders);
    }
    return {
        createScanner: createScanner,
        parseHTMLDocument: function (document) { return parse(document.getText()); },
        doComplete: htmlCompletion.doComplete.bind(htmlCompletion),
        setCompletionParticipants: htmlCompletion.setCompletionParticipants.bind(htmlCompletion),
        doHover: doHover,
        format: format,
        findDocumentHighlights: findDocumentHighlights,
        findDocumentLinks: findDocumentLinks,
        findDocumentSymbols: findDocumentSymbols,
        getFoldingRanges: getFoldingRanges,
        getSelectionRanges: getSelectionRanges,
        doTagComplete: htmlCompletion.doTagComplete.bind(htmlCompletion),
    };
}
export function newHTMLDataProvider(id, customData) {
    return new HTMLDataProvider(id, customData);
}
