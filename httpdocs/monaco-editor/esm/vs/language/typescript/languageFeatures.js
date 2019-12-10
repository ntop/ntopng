/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
'use strict';
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
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (_) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
var Uri = monaco.Uri;
var Range = monaco.Range;
//#region utils copied from typescript to prevent loading the entire typescriptServices ---
var IndentStyle;
(function (IndentStyle) {
    IndentStyle[IndentStyle["None"] = 0] = "None";
    IndentStyle[IndentStyle["Block"] = 1] = "Block";
    IndentStyle[IndentStyle["Smart"] = 2] = "Smart";
})(IndentStyle || (IndentStyle = {}));
export function flattenDiagnosticMessageText(diag, newLine, indent) {
    if (indent === void 0) { indent = 0; }
    if (typeof diag === "string") {
        return diag;
    }
    else if (diag === undefined) {
        return "";
    }
    var result = "";
    if (indent) {
        result += newLine;
        for (var i = 0; i < indent; i++) {
            result += "  ";
        }
    }
    result += diag.messageText;
    indent++;
    if (diag.next) {
        for (var _i = 0, _a = diag.next; _i < _a.length; _i++) {
            var kid = _a[_i];
            result += flattenDiagnosticMessageText(kid, newLine, indent);
        }
    }
    return result;
}
function displayPartsToString(displayParts) {
    if (displayParts) {
        return displayParts.map(function (displayPart) { return displayPart.text; }).join("");
    }
    return "";
}
//#endregion
var Adapter = /** @class */ (function () {
    function Adapter(_worker) {
        this._worker = _worker;
    }
    Adapter.prototype._positionToOffset = function (uri, position) {
        var model = monaco.editor.getModel(uri);
        return model.getOffsetAt(position);
    };
    Adapter.prototype._offsetToPosition = function (uri, offset) {
        var model = monaco.editor.getModel(uri);
        return model.getPositionAt(offset);
    };
    Adapter.prototype._textSpanToRange = function (uri, span) {
        var p1 = this._offsetToPosition(uri, span.start);
        var p2 = this._offsetToPosition(uri, span.start + span.length);
        var startLineNumber = p1.lineNumber, startColumn = p1.column;
        var endLineNumber = p2.lineNumber, endColumn = p2.column;
        return { startLineNumber: startLineNumber, startColumn: startColumn, endLineNumber: endLineNumber, endColumn: endColumn };
    };
    return Adapter;
}());
export { Adapter };
// --- diagnostics --- ---
var DiagnostcsAdapter = /** @class */ (function (_super) {
    __extends(DiagnostcsAdapter, _super);
    function DiagnostcsAdapter(_defaults, _selector, worker) {
        var _this = _super.call(this, worker) || this;
        _this._defaults = _defaults;
        _this._selector = _selector;
        _this._disposables = [];
        _this._listener = Object.create(null);
        var onModelAdd = function (model) {
            if (model.getModeId() !== _selector) {
                return;
            }
            var handle;
            var changeSubscription = model.onDidChangeContent(function () {
                clearTimeout(handle);
                handle = setTimeout(function () { return _this._doValidate(model.uri); }, 500);
            });
            _this._listener[model.uri.toString()] = {
                dispose: function () {
                    changeSubscription.dispose();
                    clearTimeout(handle);
                }
            };
            _this._doValidate(model.uri);
        };
        var onModelRemoved = function (model) {
            monaco.editor.setModelMarkers(model, _this._selector, []);
            var key = model.uri.toString();
            if (_this._listener[key]) {
                _this._listener[key].dispose();
                delete _this._listener[key];
            }
        };
        _this._disposables.push(monaco.editor.onDidCreateModel(onModelAdd));
        _this._disposables.push(monaco.editor.onWillDisposeModel(onModelRemoved));
        _this._disposables.push(monaco.editor.onDidChangeModelLanguage(function (event) {
            onModelRemoved(event.model);
            onModelAdd(event.model);
        }));
        _this._disposables.push({
            dispose: function () {
                for (var _i = 0, _a = monaco.editor.getModels(); _i < _a.length; _i++) {
                    var model = _a[_i];
                    onModelRemoved(model);
                }
            }
        });
        var recomputeDiagostics = function () {
            // redo diagnostics when options change
            for (var _i = 0, _a = monaco.editor.getModels(); _i < _a.length; _i++) {
                var model = _a[_i];
                onModelRemoved(model);
                onModelAdd(model);
            }
        };
        _this._disposables.push(_this._defaults.onDidChange(recomputeDiagostics));
        _this._disposables.push(_this._defaults.onDidExtraLibsChange(recomputeDiagostics));
        monaco.editor.getModels().forEach(onModelAdd);
        return _this;
    }
    DiagnostcsAdapter.prototype.dispose = function () {
        this._disposables.forEach(function (d) { return d && d.dispose(); });
        this._disposables = [];
    };
    DiagnostcsAdapter.prototype._doValidate = function (resource) {
        var _this = this;
        this._worker(resource).then(function (worker) {
            if (!monaco.editor.getModel(resource)) {
                // model was disposed in the meantime
                return null;
            }
            var promises = [];
            var _a = _this._defaults.getDiagnosticsOptions(), noSyntaxValidation = _a.noSyntaxValidation, noSemanticValidation = _a.noSemanticValidation;
            if (!noSyntaxValidation) {
                promises.push(worker.getSyntacticDiagnostics(resource.toString()));
            }
            if (!noSemanticValidation) {
                promises.push(worker.getSemanticDiagnostics(resource.toString()));
            }
            return Promise.all(promises);
        }).then(function (diagnostics) {
            if (!diagnostics || !monaco.editor.getModel(resource)) {
                // model was disposed in the meantime
                return null;
            }
            var markers = diagnostics
                .reduce(function (p, c) { return c.concat(p); }, [])
                .map(function (d) { return _this._convertDiagnostics(resource, d); });
            monaco.editor.setModelMarkers(monaco.editor.getModel(resource), _this._selector, markers);
        }).then(undefined, function (err) {
            console.error(err);
        });
    };
    DiagnostcsAdapter.prototype._convertDiagnostics = function (resource, diag) {
        var _a = this._offsetToPosition(resource, diag.start), startLineNumber = _a.lineNumber, startColumn = _a.column;
        var _b = this._offsetToPosition(resource, diag.start + diag.length), endLineNumber = _b.lineNumber, endColumn = _b.column;
        return {
            severity: monaco.MarkerSeverity.Error,
            startLineNumber: startLineNumber,
            startColumn: startColumn,
            endLineNumber: endLineNumber,
            endColumn: endColumn,
            message: flattenDiagnosticMessageText(diag.messageText, '\n')
        };
    };
    return DiagnostcsAdapter;
}(Adapter));
export { DiagnostcsAdapter };
var SuggestAdapter = /** @class */ (function (_super) {
    __extends(SuggestAdapter, _super);
    function SuggestAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    Object.defineProperty(SuggestAdapter.prototype, "triggerCharacters", {
        get: function () {
            return ['.'];
        },
        enumerable: true,
        configurable: true
    });
    SuggestAdapter.prototype.provideCompletionItems = function (model, position, _context, token) {
        var wordInfo = model.getWordUntilPosition(position);
        var wordRange = new Range(position.lineNumber, wordInfo.startColumn, position.lineNumber, wordInfo.endColumn);
        var resource = model.uri;
        var offset = this._positionToOffset(resource, position);
        return this._worker(resource).then(function (worker) {
            return worker.getCompletionsAtPosition(resource.toString(), offset);
        }).then(function (info) {
            if (!info) {
                return;
            }
            var suggestions = info.entries.map(function (entry) {
                var range = wordRange;
                if (entry.replacementSpan) {
                    var p1 = model.getPositionAt(entry.replacementSpan.start);
                    var p2 = model.getPositionAt(entry.replacementSpan.start + entry.replacementSpan.length);
                    range = new Range(p1.lineNumber, p1.column, p2.lineNumber, p2.column);
                }
                return {
                    uri: resource,
                    position: position,
                    range: range,
                    label: entry.name,
                    insertText: entry.name,
                    sortText: entry.sortText,
                    kind: SuggestAdapter.convertKind(entry.kind)
                };
            });
            return {
                suggestions: suggestions
            };
        });
    };
    SuggestAdapter.prototype.resolveCompletionItem = function (_model, _position, item, token) {
        var _this = this;
        var myItem = item;
        var resource = myItem.uri;
        var position = myItem.position;
        return this._worker(resource).then(function (worker) {
            return worker.getCompletionEntryDetails(resource.toString(), _this._positionToOffset(resource, position), myItem.label);
        }).then(function (details) {
            if (!details) {
                return myItem;
            }
            return {
                uri: resource,
                position: position,
                label: details.name,
                kind: SuggestAdapter.convertKind(details.kind),
                detail: displayPartsToString(details.displayParts),
                documentation: {
                    value: displayPartsToString(details.documentation)
                }
            };
        });
    };
    SuggestAdapter.convertKind = function (kind) {
        switch (kind) {
            case Kind.primitiveType:
            case Kind.keyword:
                return monaco.languages.CompletionItemKind.Keyword;
            case Kind.variable:
            case Kind.localVariable:
                return monaco.languages.CompletionItemKind.Variable;
            case Kind.memberVariable:
            case Kind.memberGetAccessor:
            case Kind.memberSetAccessor:
                return monaco.languages.CompletionItemKind.Field;
            case Kind.function:
            case Kind.memberFunction:
            case Kind.constructSignature:
            case Kind.callSignature:
            case Kind.indexSignature:
                return monaco.languages.CompletionItemKind.Function;
            case Kind.enum:
                return monaco.languages.CompletionItemKind.Enum;
            case Kind.module:
                return monaco.languages.CompletionItemKind.Module;
            case Kind.class:
                return monaco.languages.CompletionItemKind.Class;
            case Kind.interface:
                return monaco.languages.CompletionItemKind.Interface;
            case Kind.warning:
                return monaco.languages.CompletionItemKind.File;
        }
        return monaco.languages.CompletionItemKind.Property;
    };
    return SuggestAdapter;
}(Adapter));
export { SuggestAdapter };
var SignatureHelpAdapter = /** @class */ (function (_super) {
    __extends(SignatureHelpAdapter, _super);
    function SignatureHelpAdapter() {
        var _this = _super !== null && _super.apply(this, arguments) || this;
        _this.signatureHelpTriggerCharacters = ['(', ','];
        return _this;
    }
    SignatureHelpAdapter.prototype.provideSignatureHelp = function (model, position, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) { return worker.getSignatureHelpItems(resource.toString(), _this._positionToOffset(resource, position)); }).then(function (info) {
            if (!info) {
                return;
            }
            var ret = {
                activeSignature: info.selectedItemIndex,
                activeParameter: info.argumentIndex,
                signatures: []
            };
            info.items.forEach(function (item) {
                var signature = {
                    label: '',
                    parameters: []
                };
                signature.label += displayPartsToString(item.prefixDisplayParts);
                item.parameters.forEach(function (p, i, a) {
                    var label = displayPartsToString(p.displayParts);
                    var parameter = {
                        label: label,
                        documentation: displayPartsToString(p.documentation)
                    };
                    signature.label += label;
                    signature.parameters.push(parameter);
                    if (i < a.length - 1) {
                        signature.label += displayPartsToString(item.separatorDisplayParts);
                    }
                });
                signature.label += displayPartsToString(item.suffixDisplayParts);
                ret.signatures.push(signature);
            });
            return {
                value: ret,
                dispose: function () { }
            };
        });
    };
    return SignatureHelpAdapter;
}(Adapter));
export { SignatureHelpAdapter };
// --- hover ------
var QuickInfoAdapter = /** @class */ (function (_super) {
    __extends(QuickInfoAdapter, _super);
    function QuickInfoAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    QuickInfoAdapter.prototype.provideHover = function (model, position, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) {
            return worker.getQuickInfoAtPosition(resource.toString(), _this._positionToOffset(resource, position));
        }).then(function (info) {
            if (!info) {
                return;
            }
            var documentation = displayPartsToString(info.documentation);
            var tags = info.tags ? info.tags.map(function (tag) {
                var label = "*@" + tag.name + "*";
                if (!tag.text) {
                    return label;
                }
                return label + (tag.text.match(/\r\n|\n/g) ? ' \n' + tag.text : " - " + tag.text);
            })
                .join('  \n\n') : '';
            var contents = displayPartsToString(info.displayParts);
            return {
                range: _this._textSpanToRange(resource, info.textSpan),
                contents: [{
                        value: '```js\n' + contents + '\n```\n'
                    }, {
                        value: documentation + (tags ? '\n\n' + tags : '')
                    }]
            };
        });
    };
    return QuickInfoAdapter;
}(Adapter));
export { QuickInfoAdapter };
// --- occurrences ------
var OccurrencesAdapter = /** @class */ (function (_super) {
    __extends(OccurrencesAdapter, _super);
    function OccurrencesAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    OccurrencesAdapter.prototype.provideDocumentHighlights = function (model, position, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) {
            return worker.getOccurrencesAtPosition(resource.toString(), _this._positionToOffset(resource, position));
        }).then(function (entries) {
            if (!entries) {
                return;
            }
            return entries.map(function (entry) {
                return {
                    range: _this._textSpanToRange(resource, entry.textSpan),
                    kind: entry.isWriteAccess ? monaco.languages.DocumentHighlightKind.Write : monaco.languages.DocumentHighlightKind.Text
                };
            });
        });
    };
    return OccurrencesAdapter;
}(Adapter));
export { OccurrencesAdapter };
// --- definition ------
var DefinitionAdapter = /** @class */ (function (_super) {
    __extends(DefinitionAdapter, _super);
    function DefinitionAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    DefinitionAdapter.prototype.provideDefinition = function (model, position, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) {
            return worker.getDefinitionAtPosition(resource.toString(), _this._positionToOffset(resource, position));
        }).then(function (entries) {
            if (!entries) {
                return;
            }
            var result = [];
            for (var _i = 0, entries_1 = entries; _i < entries_1.length; _i++) {
                var entry = entries_1[_i];
                var uri = Uri.parse(entry.fileName);
                if (monaco.editor.getModel(uri)) {
                    result.push({
                        uri: uri,
                        range: _this._textSpanToRange(uri, entry.textSpan)
                    });
                }
            }
            return result;
        });
    };
    return DefinitionAdapter;
}(Adapter));
export { DefinitionAdapter };
// --- references ------
var ReferenceAdapter = /** @class */ (function (_super) {
    __extends(ReferenceAdapter, _super);
    function ReferenceAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    ReferenceAdapter.prototype.provideReferences = function (model, position, context, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) {
            return worker.getReferencesAtPosition(resource.toString(), _this._positionToOffset(resource, position));
        }).then(function (entries) {
            if (!entries) {
                return;
            }
            var result = [];
            for (var _i = 0, entries_2 = entries; _i < entries_2.length; _i++) {
                var entry = entries_2[_i];
                var uri = Uri.parse(entry.fileName);
                if (monaco.editor.getModel(uri)) {
                    result.push({
                        uri: uri,
                        range: _this._textSpanToRange(uri, entry.textSpan)
                    });
                }
            }
            return result;
        });
    };
    return ReferenceAdapter;
}(Adapter));
export { ReferenceAdapter };
// --- outline ------
var OutlineAdapter = /** @class */ (function (_super) {
    __extends(OutlineAdapter, _super);
    function OutlineAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    OutlineAdapter.prototype.provideDocumentSymbols = function (model, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) { return worker.getNavigationBarItems(resource.toString()); }).then(function (items) {
            if (!items) {
                return;
            }
            var convert = function (bucket, item, containerLabel) {
                var result = {
                    name: item.text,
                    detail: '',
                    kind: (outlineTypeTable[item.kind] || monaco.languages.SymbolKind.Variable),
                    range: _this._textSpanToRange(resource, item.spans[0]),
                    selectionRange: _this._textSpanToRange(resource, item.spans[0]),
                    tags: [],
                    containerName: containerLabel
                };
                if (item.childItems && item.childItems.length > 0) {
                    for (var _i = 0, _a = item.childItems; _i < _a.length; _i++) {
                        var child = _a[_i];
                        convert(bucket, child, result.name);
                    }
                }
                bucket.push(result);
            };
            var result = [];
            items.forEach(function (item) { return convert(result, item); });
            return result;
        });
    };
    return OutlineAdapter;
}(Adapter));
export { OutlineAdapter };
var Kind = /** @class */ (function () {
    function Kind() {
    }
    Kind.unknown = '';
    Kind.keyword = 'keyword';
    Kind.script = 'script';
    Kind.module = 'module';
    Kind.class = 'class';
    Kind.interface = 'interface';
    Kind.type = 'type';
    Kind.enum = 'enum';
    Kind.variable = 'var';
    Kind.localVariable = 'local var';
    Kind.function = 'function';
    Kind.localFunction = 'local function';
    Kind.memberFunction = 'method';
    Kind.memberGetAccessor = 'getter';
    Kind.memberSetAccessor = 'setter';
    Kind.memberVariable = 'property';
    Kind.constructorImplementation = 'constructor';
    Kind.callSignature = 'call';
    Kind.indexSignature = 'index';
    Kind.constructSignature = 'construct';
    Kind.parameter = 'parameter';
    Kind.typeParameter = 'type parameter';
    Kind.primitiveType = 'primitive type';
    Kind.label = 'label';
    Kind.alias = 'alias';
    Kind.const = 'const';
    Kind.let = 'let';
    Kind.warning = 'warning';
    return Kind;
}());
export { Kind };
var outlineTypeTable = Object.create(null);
outlineTypeTable[Kind.module] = monaco.languages.SymbolKind.Module;
outlineTypeTable[Kind.class] = monaco.languages.SymbolKind.Class;
outlineTypeTable[Kind.enum] = monaco.languages.SymbolKind.Enum;
outlineTypeTable[Kind.interface] = monaco.languages.SymbolKind.Interface;
outlineTypeTable[Kind.memberFunction] = monaco.languages.SymbolKind.Method;
outlineTypeTable[Kind.memberVariable] = monaco.languages.SymbolKind.Property;
outlineTypeTable[Kind.memberGetAccessor] = monaco.languages.SymbolKind.Property;
outlineTypeTable[Kind.memberSetAccessor] = monaco.languages.SymbolKind.Property;
outlineTypeTable[Kind.variable] = monaco.languages.SymbolKind.Variable;
outlineTypeTable[Kind.const] = monaco.languages.SymbolKind.Variable;
outlineTypeTable[Kind.localVariable] = monaco.languages.SymbolKind.Variable;
outlineTypeTable[Kind.variable] = monaco.languages.SymbolKind.Variable;
outlineTypeTable[Kind.function] = monaco.languages.SymbolKind.Function;
outlineTypeTable[Kind.localFunction] = monaco.languages.SymbolKind.Function;
// --- formatting ----
var FormatHelper = /** @class */ (function (_super) {
    __extends(FormatHelper, _super);
    function FormatHelper() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    FormatHelper._convertOptions = function (options) {
        return {
            ConvertTabsToSpaces: options.insertSpaces,
            TabSize: options.tabSize,
            IndentSize: options.tabSize,
            IndentStyle: IndentStyle.Smart,
            NewLineCharacter: '\n',
            InsertSpaceAfterCommaDelimiter: true,
            InsertSpaceAfterSemicolonInForStatements: true,
            InsertSpaceBeforeAndAfterBinaryOperators: true,
            InsertSpaceAfterKeywordsInControlFlowStatements: true,
            InsertSpaceAfterFunctionKeywordForAnonymousFunctions: true,
            InsertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis: false,
            InsertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets: false,
            InsertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces: false,
            PlaceOpenBraceOnNewLineForControlBlocks: false,
            PlaceOpenBraceOnNewLineForFunctions: false
        };
    };
    FormatHelper.prototype._convertTextChanges = function (uri, change) {
        return {
            text: change.newText,
            range: this._textSpanToRange(uri, change.span)
        };
    };
    return FormatHelper;
}(Adapter));
export { FormatHelper };
var FormatAdapter = /** @class */ (function (_super) {
    __extends(FormatAdapter, _super);
    function FormatAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    FormatAdapter.prototype.provideDocumentRangeFormattingEdits = function (model, range, options, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) {
            return worker.getFormattingEditsForRange(resource.toString(), _this._positionToOffset(resource, { lineNumber: range.startLineNumber, column: range.startColumn }), _this._positionToOffset(resource, { lineNumber: range.endLineNumber, column: range.endColumn }), FormatHelper._convertOptions(options));
        }).then(function (edits) {
            if (edits) {
                return edits.map(function (edit) { return _this._convertTextChanges(resource, edit); });
            }
        });
    };
    return FormatAdapter;
}(FormatHelper));
export { FormatAdapter };
var FormatOnTypeAdapter = /** @class */ (function (_super) {
    __extends(FormatOnTypeAdapter, _super);
    function FormatOnTypeAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    Object.defineProperty(FormatOnTypeAdapter.prototype, "autoFormatTriggerCharacters", {
        get: function () {
            return [';', '}', '\n'];
        },
        enumerable: true,
        configurable: true
    });
    FormatOnTypeAdapter.prototype.provideOnTypeFormattingEdits = function (model, position, ch, options, token) {
        var _this = this;
        var resource = model.uri;
        return this._worker(resource).then(function (worker) {
            return worker.getFormattingEditsAfterKeystroke(resource.toString(), _this._positionToOffset(resource, position), ch, FormatHelper._convertOptions(options));
        }).then(function (edits) {
            if (edits) {
                return edits.map(function (edit) { return _this._convertTextChanges(resource, edit); });
            }
        });
    };
    return FormatOnTypeAdapter;
}(FormatHelper));
export { FormatOnTypeAdapter };
// --- rename ----
var RenameAdapter = /** @class */ (function (_super) {
    __extends(RenameAdapter, _super);
    function RenameAdapter() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    RenameAdapter.prototype.provideRenameEdits = function (model, position, newName, token) {
        return __awaiter(this, void 0, void 0, function () {
            var resource, fileName, offset, worker, renameInfo, renameLocations, fileNameToResourceTextEditMap, edits, _i, renameLocations_1, renameLocation, resourceTextEdit;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        resource = model.uri;
                        fileName = resource.toString();
                        offset = this._positionToOffset(resource, position);
                        return [4 /*yield*/, this._worker(resource)];
                    case 1:
                        worker = _a.sent();
                        return [4 /*yield*/, worker.getRenameInfo(fileName, offset, { allowRenameOfImportPath: false })];
                    case 2:
                        renameInfo = _a.sent();
                        if (renameInfo.canRename === false) { // use explicit comparison so that the discriminated union gets resolved properly
                            return [2 /*return*/, {
                                    edits: [],
                                    rejectReason: renameInfo.localizedErrorMessage
                                }];
                        }
                        if (renameInfo.fileToRename !== undefined) {
                            throw new Error("Renaming files is not supported.");
                        }
                        return [4 /*yield*/, worker.findRenameLocations(fileName, offset, /*strings*/ false, /*comments*/ false, /*prefixAndSuffix*/ false)];
                    case 3:
                        renameLocations = _a.sent();
                        fileNameToResourceTextEditMap = {};
                        edits = [];
                        for (_i = 0, renameLocations_1 = renameLocations; _i < renameLocations_1.length; _i++) {
                            renameLocation = renameLocations_1[_i];
                            if (!(renameLocation.fileName in fileNameToResourceTextEditMap)) {
                                resourceTextEdit = {
                                    edits: [],
                                    resource: monaco.Uri.parse(renameLocation.fileName)
                                };
                                fileNameToResourceTextEditMap[renameLocation.fileName] = resourceTextEdit;
                                edits.push(resourceTextEdit);
                            }
                            fileNameToResourceTextEditMap[renameLocation.fileName].edits.push({
                                range: this._textSpanToRange(resource, renameLocation.textSpan),
                                text: newName
                            });
                        }
                        return [2 /*return*/, { edits: edits }];
                }
            });
        });
    };
    return RenameAdapter;
}(Adapter));
export { RenameAdapter };
