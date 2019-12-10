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
import './quickOutline.css';
import { CancellationToken } from '../../../../base/common/cancellation.js';
import { matchesFuzzy } from '../../../../base/common/filters.js';
import * as strings from '../../../../base/common/strings.js';
import { QuickOpenEntryGroup, QuickOpenModel } from '../../../../base/parts/quickopen/browser/quickOpenModel.js';
import { registerEditorAction } from '../../../browser/editorExtensions.js';
import { Range } from '../../../common/core/range.js';
import { EditorContextKeys } from '../../../common/editorContextKeys.js';
import { DocumentSymbolProviderRegistry, symbolKindToCssClass } from '../../../common/modes.js';
import { getDocumentSymbols } from '../../../contrib/quickOpen/quickOpen.js';
import { BaseEditorQuickOpenAction } from './editorQuickOpen.js';
import { QuickOutlineNLS } from '../../../common/standaloneStrings.js';
var SCOPE_PREFIX = ':';
var SymbolEntry = /** @class */ (function (_super) {
    __extends(SymbolEntry, _super);
    function SymbolEntry(name, type, description, range, highlights, editor, decorator) {
        var _this = _super.call(this) || this;
        _this.name = name;
        _this.type = type;
        _this.description = description;
        _this.range = range;
        _this.setHighlights(highlights);
        _this.editor = editor;
        _this.decorator = decorator;
        return _this;
    }
    SymbolEntry.prototype.getLabel = function () {
        return this.name;
    };
    SymbolEntry.prototype.getAriaLabel = function () {
        return strings.format(QuickOutlineNLS.entryAriaLabel, this.name);
    };
    SymbolEntry.prototype.getIcon = function () {
        return this.type;
    };
    SymbolEntry.prototype.getDescription = function () {
        return this.description;
    };
    SymbolEntry.prototype.getType = function () {
        return this.type;
    };
    SymbolEntry.prototype.getRange = function () {
        return this.range;
    };
    SymbolEntry.prototype.run = function (mode, context) {
        if (mode === 1 /* OPEN */) {
            return this.runOpen(context);
        }
        return this.runPreview();
    };
    SymbolEntry.prototype.runOpen = function (_context) {
        // Apply selection and focus
        var range = this.toSelection();
        this.editor.setSelection(range);
        this.editor.revealRangeInCenter(range, 0 /* Smooth */);
        this.editor.focus();
        return true;
    };
    SymbolEntry.prototype.runPreview = function () {
        // Select Outline Position
        var range = this.toSelection();
        this.editor.revealRangeInCenter(range, 0 /* Smooth */);
        // Decorate if possible
        this.decorator.decorateLine(this.range, this.editor);
        return false;
    };
    SymbolEntry.prototype.toSelection = function () {
        return new Range(this.range.startLineNumber, this.range.startColumn || 1, this.range.startLineNumber, this.range.startColumn || 1);
    };
    return SymbolEntry;
}(QuickOpenEntryGroup));
export { SymbolEntry };
var QuickOutlineAction = /** @class */ (function (_super) {
    __extends(QuickOutlineAction, _super);
    function QuickOutlineAction() {
        return _super.call(this, QuickOutlineNLS.quickOutlineActionInput, {
            id: 'editor.action.quickOutline',
            label: QuickOutlineNLS.quickOutlineActionLabel,
            alias: 'Go to Symbol...',
            precondition: EditorContextKeys.hasDocumentSymbolProvider,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: 2048 /* CtrlCmd */ | 1024 /* Shift */ | 45 /* KEY_O */,
                weight: 100 /* EditorContrib */
            },
            menuOpts: {
                group: 'navigation',
                order: 3
            }
        }) || this;
    }
    QuickOutlineAction.prototype.run = function (accessor, editor) {
        var _this = this;
        if (!editor.hasModel()) {
            return undefined;
        }
        var model = editor.getModel();
        if (!DocumentSymbolProviderRegistry.has(model)) {
            return undefined;
        }
        // Resolve outline
        return getDocumentSymbols(model, true, CancellationToken.None).then(function (result) {
            if (result.length === 0) {
                return;
            }
            _this._run(editor, result);
        });
    };
    QuickOutlineAction.prototype._run = function (editor, result) {
        var _this = this;
        this._show(this.getController(editor), {
            getModel: function (value) {
                return new QuickOpenModel(_this.toQuickOpenEntries(editor, result, value));
            },
            getAutoFocus: function (searchValue) {
                // Remove any type pattern (:) from search value as needed
                if (searchValue.indexOf(SCOPE_PREFIX) === 0) {
                    searchValue = searchValue.substr(SCOPE_PREFIX.length);
                }
                return {
                    autoFocusPrefixMatch: searchValue,
                    autoFocusFirstEntry: !!searchValue
                };
            }
        });
    };
    QuickOutlineAction.prototype.symbolEntry = function (name, type, description, range, highlights, editor, decorator) {
        return new SymbolEntry(name, type, description, Range.lift(range), highlights, editor, decorator);
    };
    QuickOutlineAction.prototype.toQuickOpenEntries = function (editor, flattened, searchValue) {
        var controller = this.getController(editor);
        var results = [];
        // Convert to Entries
        var normalizedSearchValue = searchValue;
        if (searchValue.indexOf(SCOPE_PREFIX) === 0) {
            normalizedSearchValue = normalizedSearchValue.substr(SCOPE_PREFIX.length);
        }
        for (var _i = 0, flattened_1 = flattened; _i < flattened_1.length; _i++) {
            var element = flattened_1[_i];
            var label = strings.trim(element.name);
            // Check for meatch
            var highlights = matchesFuzzy(normalizedSearchValue, label);
            if (highlights) {
                // Show parent scope as description
                var description = undefined;
                if (element.containerName) {
                    description = element.containerName;
                }
                // Add
                results.push(this.symbolEntry(label, symbolKindToCssClass(element.kind), description, element.range, highlights, editor, controller));
            }
        }
        // Sort properly if actually searching
        if (searchValue) {
            if (searchValue.indexOf(SCOPE_PREFIX) === 0) {
                results = results.sort(this.sortScoped.bind(this, searchValue.toLowerCase()));
            }
            else {
                results = results.sort(this.sortNormal.bind(this, searchValue.toLowerCase()));
            }
        }
        // Mark all type groups
        if (results.length > 0 && searchValue.indexOf(SCOPE_PREFIX) === 0) {
            var currentType = null;
            var currentResult = null;
            var typeCounter = 0;
            for (var i = 0; i < results.length; i++) {
                var result = results[i];
                // Found new type
                if (currentType !== result.getType()) {
                    // Update previous result with count
                    if (currentResult) {
                        currentResult.setGroupLabel(this.typeToLabel(currentType || '', typeCounter));
                    }
                    currentType = result.getType();
                    currentResult = result;
                    typeCounter = 1;
                    result.setShowBorder(i > 0);
                }
                // Existing type, keep counting
                else {
                    typeCounter++;
                }
            }
            // Update previous result with count
            if (currentResult) {
                currentResult.setGroupLabel(this.typeToLabel(currentType || '', typeCounter));
            }
        }
        // Mark first entry as outline
        else if (results.length > 0) {
            results[0].setGroupLabel(strings.format(QuickOutlineNLS._symbols_, results.length));
        }
        return results;
    };
    QuickOutlineAction.prototype.typeToLabel = function (type, count) {
        switch (type) {
            case 'module': return strings.format(QuickOutlineNLS._modules_, count);
            case 'class': return strings.format(QuickOutlineNLS._class_, count);
            case 'interface': return strings.format(QuickOutlineNLS._interface_, count);
            case 'method': return strings.format(QuickOutlineNLS._method_, count);
            case 'function': return strings.format(QuickOutlineNLS._function_, count);
            case 'property': return strings.format(QuickOutlineNLS._property_, count);
            case 'variable': return strings.format(QuickOutlineNLS._variable_, count);
            case 'var': return strings.format(QuickOutlineNLS._variable2_, count);
            case 'constructor': return strings.format(QuickOutlineNLS._constructor_, count);
            case 'call': return strings.format(QuickOutlineNLS._call_, count);
        }
        return type;
    };
    QuickOutlineAction.prototype.sortNormal = function (searchValue, elementA, elementB) {
        var elementAName = elementA.getLabel().toLowerCase();
        var elementBName = elementB.getLabel().toLowerCase();
        // Compare by name
        var r = elementAName.localeCompare(elementBName);
        if (r !== 0) {
            return r;
        }
        // If name identical sort by range instead
        var elementARange = elementA.getRange();
        var elementBRange = elementB.getRange();
        return elementARange.startLineNumber - elementBRange.startLineNumber;
    };
    QuickOutlineAction.prototype.sortScoped = function (searchValue, elementA, elementB) {
        // Remove scope char
        searchValue = searchValue.substr(SCOPE_PREFIX.length);
        // Sort by type first if scoped search
        var elementAType = elementA.getType();
        var elementBType = elementB.getType();
        var r = elementAType.localeCompare(elementBType);
        if (r !== 0) {
            return r;
        }
        // Special sort when searching in scoped mode
        if (searchValue) {
            var elementAName = elementA.getLabel().toLowerCase();
            var elementBName = elementB.getLabel().toLowerCase();
            // Compare by name
            var r_1 = elementAName.localeCompare(elementBName);
            if (r_1 !== 0) {
                return r_1;
            }
        }
        // Default to sort by range
        var elementARange = elementA.getRange();
        var elementBRange = elementB.getRange();
        return elementARange.startLineNumber - elementBRange.startLineNumber;
    };
    return QuickOutlineAction;
}(BaseEditorQuickOpenAction));
export { QuickOutlineAction };
registerEditorAction(QuickOutlineAction);
