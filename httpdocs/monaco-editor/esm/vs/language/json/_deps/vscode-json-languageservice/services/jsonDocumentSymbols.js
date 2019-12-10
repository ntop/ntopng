/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as Parser from '../parser/jsonParser.js';
import * as Strings from '../utils/strings.js';
import { colorFromHex } from '../utils/colors.js';
import { SymbolKind, Range, Location, TextEdit } from '../_deps/vscode-languageserver-types/main.js';
var JSONDocumentSymbols = /** @class */ (function () {
    function JSONDocumentSymbols(schemaService) {
        this.schemaService = schemaService;
    }
    JSONDocumentSymbols.prototype.findDocumentSymbols = function (document, doc) {
        var _this = this;
        var root = doc.root;
        if (!root) {
            return null;
        }
        // special handling for key bindings
        var resourceString = document.uri;
        if ((resourceString === 'vscode://defaultsettings/keybindings.json') || Strings.endsWith(resourceString.toLowerCase(), '/user/keybindings.json')) {
            if (root.type === 'array') {
                var result_1 = [];
                root.items.forEach(function (item) {
                    if (item.type === 'object') {
                        for (var _i = 0, _a = item.properties; _i < _a.length; _i++) {
                            var property = _a[_i];
                            if (property.keyNode.value === 'key') {
                                if (property.valueNode) {
                                    if (property.valueNode) {
                                        var location = Location.create(document.uri, getRange(document, item));
                                        result_1.push({ name: Parser.getNodeValue(property.valueNode), kind: SymbolKind.Function, location: location });
                                    }
                                    return;
                                }
                            }
                        }
                    }
                });
                return result_1;
            }
        }
        var collectOutlineEntries = function (result, node, containerName) {
            if (node.type === 'array') {
                node.items.forEach(function (node) { return collectOutlineEntries(result, node, containerName); });
            }
            else if (node.type === 'object') {
                node.properties.forEach(function (property) {
                    var location = Location.create(document.uri, getRange(document, property));
                    var valueNode = property.valueNode;
                    if (valueNode) {
                        var childContainerName = containerName ? containerName + '.' + property.keyNode.value : property.keyNode.value;
                        result.push({ name: _this.getKeyLabel(property), kind: _this.getSymbolKind(valueNode.type), location: location, containerName: containerName });
                        collectOutlineEntries(result, valueNode, childContainerName);
                    }
                });
            }
            return result;
        };
        var result = collectOutlineEntries([], root, void 0);
        return result;
    };
    JSONDocumentSymbols.prototype.findDocumentSymbols2 = function (document, doc) {
        var _this = this;
        var root = doc.root;
        if (!root) {
            return null;
        }
        // special handling for key bindings
        var resourceString = document.uri;
        if ((resourceString === 'vscode://defaultsettings/keybindings.json') || Strings.endsWith(resourceString.toLowerCase(), '/user/keybindings.json')) {
            if (root.type === 'array') {
                var result_2 = [];
                root.items.forEach(function (item) {
                    if (item.type === 'object') {
                        for (var _i = 0, _a = item.properties; _i < _a.length; _i++) {
                            var property = _a[_i];
                            if (property.keyNode.value === 'key') {
                                if (property.valueNode) {
                                    var range = getRange(document, item);
                                    var selectionRange = getRange(document, property.keyNode);
                                    result_2.push({ name: Parser.getNodeValue(property.valueNode), kind: SymbolKind.Function, range: range, selectionRange: selectionRange });
                                }
                                return;
                            }
                        }
                    }
                });
                return result_2;
            }
        }
        var collectOutlineEntries = function (result, node) {
            if (node.type === 'array') {
                node.items.forEach(function (node, index) {
                    if (node) {
                        var range = getRange(document, node);
                        var selectionRange = range;
                        var name = String(index);
                        var children = collectOutlineEntries([], node);
                        result.push({ name: name, kind: _this.getSymbolKind(node.type), range: range, selectionRange: selectionRange, children: children });
                    }
                });
            }
            else if (node.type === 'object') {
                node.properties.forEach(function (property) {
                    var valueNode = property.valueNode;
                    if (valueNode) {
                        var range = getRange(document, property);
                        var selectionRange = getRange(document, property.keyNode);
                        var children = collectOutlineEntries([], valueNode);
                        result.push({ name: _this.getKeyLabel(property), kind: _this.getSymbolKind(valueNode.type), range: range, selectionRange: selectionRange, children: children });
                    }
                });
            }
            return result;
        };
        var result = collectOutlineEntries([], root);
        return result;
    };
    JSONDocumentSymbols.prototype.getSymbolKind = function (nodeType) {
        switch (nodeType) {
            case 'object':
                return SymbolKind.Module;
            case 'string':
                return SymbolKind.String;
            case 'number':
                return SymbolKind.Number;
            case 'array':
                return SymbolKind.Array;
            case 'boolean':
                return SymbolKind.Boolean;
            default: // 'null'
                return SymbolKind.Variable;
        }
    };
    JSONDocumentSymbols.prototype.getKeyLabel = function (property) {
        var name = property.keyNode.value;
        if (name) {
            name = name.replace(/[\n]/g, '↵');
        }
        if (name && name.trim()) {
            return name;
        }
        return "\"" + name + "\"";
    };
    JSONDocumentSymbols.prototype.findDocumentColors = function (document, doc) {
        return this.schemaService.getSchemaForResource(document.uri, doc).then(function (schema) {
            var result = [];
            if (schema) {
                var matchingSchemas = doc.getMatchingSchemas(schema.schema);
                var visitedNode = {};
                for (var _i = 0, matchingSchemas_1 = matchingSchemas; _i < matchingSchemas_1.length; _i++) {
                    var s = matchingSchemas_1[_i];
                    if (!s.inverted && s.schema && (s.schema.format === 'color' || s.schema.format === 'color-hex') && s.node && s.node.type === 'string') {
                        var nodeId = String(s.node.offset);
                        if (!visitedNode[nodeId]) {
                            var color = colorFromHex(Parser.getNodeValue(s.node));
                            if (color) {
                                var range = getRange(document, s.node);
                                result.push({ color: color, range: range });
                            }
                            visitedNode[nodeId] = true;
                        }
                    }
                }
            }
            return result;
        });
    };
    JSONDocumentSymbols.prototype.getColorPresentations = function (document, doc, color, range) {
        var result = [];
        var red256 = Math.round(color.red * 255), green256 = Math.round(color.green * 255), blue256 = Math.round(color.blue * 255);
        function toTwoDigitHex(n) {
            var r = n.toString(16);
            return r.length !== 2 ? '0' + r : r;
        }
        var label;
        if (color.alpha === 1) {
            label = "#" + toTwoDigitHex(red256) + toTwoDigitHex(green256) + toTwoDigitHex(blue256);
        }
        else {
            label = "#" + toTwoDigitHex(red256) + toTwoDigitHex(green256) + toTwoDigitHex(blue256) + toTwoDigitHex(Math.round(color.alpha * 255));
        }
        result.push({ label: label, textEdit: TextEdit.replace(range, JSON.stringify(label)) });
        return result;
    };
    return JSONDocumentSymbols;
}());
export { JSONDocumentSymbols };
function getRange(document, node) {
    return Range.create(document.positionAt(node.offset), document.positionAt(node.offset + node.length));
}
