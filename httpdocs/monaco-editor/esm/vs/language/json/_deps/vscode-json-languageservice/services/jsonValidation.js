/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { UnresolvedSchema } from './jsonSchemaService.js';
import { Diagnostic, DiagnosticSeverity, Range } from '../_deps/vscode-languageserver-types/main.js';
import { ErrorCode } from '../jsonLanguageTypes.js';
import * as nls from '../../../fillers/vscode-nls.js';
import { isBoolean } from '../utils/objects.js';
var localize = nls.loadMessageBundle();
var JSONValidation = /** @class */ (function () {
    function JSONValidation(jsonSchemaService, promiseConstructor) {
        this.jsonSchemaService = jsonSchemaService;
        this.promise = promiseConstructor;
        this.validationEnabled = true;
    }
    JSONValidation.prototype.configure = function (raw) {
        if (raw) {
            this.validationEnabled = raw.validate;
            this.commentSeverity = raw.allowComments ? void 0 : DiagnosticSeverity.Error;
        }
    };
    JSONValidation.prototype.doValidation = function (textDocument, jsonDocument, documentSettings, schema) {
        var _this = this;
        if (!this.validationEnabled) {
            return this.promise.resolve([]);
        }
        var diagnostics = [];
        var added = {};
        var addProblem = function (problem) {
            // remove duplicated messages
            var signature = problem.range.start.line + ' ' + problem.range.start.character + ' ' + problem.message;
            if (!added[signature]) {
                added[signature] = true;
                diagnostics.push(problem);
            }
        };
        var getDiagnostics = function (schema) {
            var trailingCommaSeverity = documentSettings ? toDiagnosticSeverity(documentSettings.trailingCommas) : DiagnosticSeverity.Error;
            var commentSeverity = documentSettings ? toDiagnosticSeverity(documentSettings.comments) : _this.commentSeverity;
            if (schema) {
                if (schema.errors.length && jsonDocument.root) {
                    var astRoot = jsonDocument.root;
                    var property = astRoot.type === 'object' ? astRoot.properties[0] : null;
                    if (property && property.keyNode.value === '$schema') {
                        var node = property.valueNode || property;
                        var range = Range.create(textDocument.positionAt(node.offset), textDocument.positionAt(node.offset + node.length));
                        addProblem(Diagnostic.create(range, schema.errors[0], DiagnosticSeverity.Warning, ErrorCode.SchemaResolveError));
                    }
                    else {
                        var range = Range.create(textDocument.positionAt(astRoot.offset), textDocument.positionAt(astRoot.offset + 1));
                        addProblem(Diagnostic.create(range, schema.errors[0], DiagnosticSeverity.Warning, ErrorCode.SchemaResolveError));
                    }
                }
                else {
                    var semanticErrors = jsonDocument.validate(textDocument, schema.schema);
                    if (semanticErrors) {
                        semanticErrors.forEach(addProblem);
                    }
                }
                if (schemaAllowsComments(schema.schema)) {
                    commentSeverity = void 0;
                }
                if (schemaAllowsTrailingCommas(schema.schema)) {
                    trailingCommaSeverity = void 0;
                }
            }
            for (var _i = 0, _a = jsonDocument.syntaxErrors; _i < _a.length; _i++) {
                var p = _a[_i];
                if (p.code === ErrorCode.TrailingComma) {
                    if (typeof trailingCommaSeverity !== 'number') {
                        continue;
                    }
                    p.severity = trailingCommaSeverity;
                }
                addProblem(p);
            }
            if (typeof commentSeverity === 'number') {
                var message_1 = localize('InvalidCommentToken', 'Comments are not permitted in JSON.');
                jsonDocument.comments.forEach(function (c) {
                    addProblem(Diagnostic.create(c, message_1, commentSeverity, ErrorCode.CommentNotPermitted));
                });
            }
            return diagnostics;
        };
        if (schema) {
            var id = schema.id || ('schemaservice://untitled/' + idCounter++);
            return this.jsonSchemaService.resolveSchemaContent(new UnresolvedSchema(schema), id, {}).then(function (resolvedSchema) {
                return getDiagnostics(resolvedSchema);
            });
        }
        return this.jsonSchemaService.getSchemaForResource(textDocument.uri, jsonDocument).then(function (schema) {
            return getDiagnostics(schema);
        });
    };
    return JSONValidation;
}());
export { JSONValidation };
var idCounter = 0;
function schemaAllowsComments(schemaRef) {
    if (schemaRef && typeof schemaRef === 'object') {
        if (isBoolean(schemaRef.allowComments)) {
            return schemaRef.allowComments;
        }
        if (schemaRef.allOf) {
            for (var _i = 0, _a = schemaRef.allOf; _i < _a.length; _i++) {
                var schema = _a[_i];
                var allow = schemaAllowsComments(schema);
                if (isBoolean(allow)) {
                    return allow;
                }
            }
        }
    }
    return undefined;
}
function schemaAllowsTrailingCommas(schemaRef) {
    if (schemaRef && typeof schemaRef === 'object') {
        if (isBoolean(schemaRef.allowsTrailingCommas)) {
            return schemaRef.allowsTrailingCommas;
        }
        if (schemaRef.allOf) {
            for (var _i = 0, _a = schemaRef.allOf; _i < _a.length; _i++) {
                var schema = _a[_i];
                var allow = schemaAllowsTrailingCommas(schema);
                if (isBoolean(allow)) {
                    return allow;
                }
            }
        }
    }
    return undefined;
}
function toDiagnosticSeverity(severityLevel) {
    switch (severityLevel) {
        case 'error': return DiagnosticSeverity.Error;
        case 'warning': return DiagnosticSeverity.Warning;
        case 'ignore': return void 0;
    }
    return void 0;
}
