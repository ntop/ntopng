/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as Json from '../../jsonc-parser/main.js';
import { URI } from '../../vscode-uri/index.js';
import * as Strings from '../utils/strings.js';
import * as Parser from '../parser/jsonParser.js';
import * as nls from '../../../fillers/vscode-nls.js';
var localize = nls.loadMessageBundle();
var FilePatternAssociation = /** @class */ (function () {
    function FilePatternAssociation(pattern) {
        try {
            this.patternRegExp = new RegExp(Strings.convertSimple2RegExpPattern(pattern) + '$');
        }
        catch (e) {
            // invalid pattern
            this.patternRegExp = null;
        }
        this.schemas = [];
    }
    FilePatternAssociation.prototype.addSchema = function (id) {
        this.schemas.push(id);
    };
    FilePatternAssociation.prototype.matchesPattern = function (fileName) {
        return this.patternRegExp && this.patternRegExp.test(fileName);
    };
    FilePatternAssociation.prototype.getSchemas = function () {
        return this.schemas;
    };
    return FilePatternAssociation;
}());
var SchemaHandle = /** @class */ (function () {
    function SchemaHandle(service, url, unresolvedSchemaContent) {
        this.service = service;
        this.url = url;
        this.dependencies = {};
        if (unresolvedSchemaContent) {
            this.unresolvedSchema = this.service.promise.resolve(new UnresolvedSchema(unresolvedSchemaContent));
        }
    }
    SchemaHandle.prototype.getUnresolvedSchema = function () {
        if (!this.unresolvedSchema) {
            this.unresolvedSchema = this.service.loadSchema(this.url);
        }
        return this.unresolvedSchema;
    };
    SchemaHandle.prototype.getResolvedSchema = function () {
        var _this = this;
        if (!this.resolvedSchema) {
            this.resolvedSchema = this.getUnresolvedSchema().then(function (unresolved) {
                return _this.service.resolveSchemaContent(unresolved, _this.url, _this.dependencies);
            });
        }
        return this.resolvedSchema;
    };
    SchemaHandle.prototype.clearSchema = function () {
        this.resolvedSchema = null;
        this.unresolvedSchema = null;
        this.dependencies = {};
    };
    return SchemaHandle;
}());
var UnresolvedSchema = /** @class */ (function () {
    function UnresolvedSchema(schema, errors) {
        if (errors === void 0) { errors = []; }
        this.schema = schema;
        this.errors = errors;
    }
    return UnresolvedSchema;
}());
export { UnresolvedSchema };
var ResolvedSchema = /** @class */ (function () {
    function ResolvedSchema(schema, errors) {
        if (errors === void 0) { errors = []; }
        this.schema = schema;
        this.errors = errors;
    }
    ResolvedSchema.prototype.getSection = function (path) {
        return Parser.asSchema(this.getSectionRecursive(path, this.schema));
    };
    ResolvedSchema.prototype.getSectionRecursive = function (path, schema) {
        if (!schema || typeof schema === 'boolean' || path.length === 0) {
            return schema;
        }
        var next = path.shift();
        if (schema.properties && typeof schema.properties[next]) {
            return this.getSectionRecursive(path, schema.properties[next]);
        }
        else if (schema.patternProperties) {
            for (var _i = 0, _a = Object.keys(schema.patternProperties); _i < _a.length; _i++) {
                var pattern = _a[_i];
                var regex = new RegExp(pattern);
                if (regex.test(next)) {
                    return this.getSectionRecursive(path, schema.patternProperties[pattern]);
                }
            }
        }
        else if (typeof schema.additionalProperties === 'object') {
            return this.getSectionRecursive(path, schema.additionalProperties);
        }
        else if (next.match('[0-9]+')) {
            if (Array.isArray(schema.items)) {
                var index = parseInt(next, 10);
                if (!isNaN(index) && schema.items[index]) {
                    return this.getSectionRecursive(path, schema.items[index]);
                }
            }
            else if (schema.items) {
                return this.getSectionRecursive(path, schema.items);
            }
        }
        return null;
    };
    return ResolvedSchema;
}());
export { ResolvedSchema };
var JSONSchemaService = /** @class */ (function () {
    function JSONSchemaService(requestService, contextService, promiseConstructor) {
        this.contextService = contextService;
        this.requestService = requestService;
        this.promiseConstructor = promiseConstructor || Promise;
        this.callOnDispose = [];
        this.contributionSchemas = {};
        this.contributionAssociations = {};
        this.schemasById = {};
        this.filePatternAssociations = [];
        this.filePatternAssociationById = {};
        this.registeredSchemasIds = {};
    }
    JSONSchemaService.prototype.getRegisteredSchemaIds = function (filter) {
        return Object.keys(this.registeredSchemasIds).filter(function (id) {
            var scheme = URI.parse(id).scheme;
            return scheme !== 'schemaservice' && (!filter || filter(scheme));
        });
    };
    Object.defineProperty(JSONSchemaService.prototype, "promise", {
        get: function () {
            return this.promiseConstructor;
        },
        enumerable: true,
        configurable: true
    });
    JSONSchemaService.prototype.dispose = function () {
        while (this.callOnDispose.length > 0) {
            this.callOnDispose.pop()();
        }
    };
    JSONSchemaService.prototype.onResourceChange = function (uri) {
        var _this = this;
        var hasChanges = false;
        uri = this.normalizeId(uri);
        var toWalk = [uri];
        var all = Object.keys(this.schemasById).map(function (key) { return _this.schemasById[key]; });
        while (toWalk.length) {
            var curr = toWalk.pop();
            for (var i = 0; i < all.length; i++) {
                var handle = all[i];
                if (handle && (handle.url === curr || handle.dependencies[curr])) {
                    if (handle.url !== curr) {
                        toWalk.push(handle.url);
                    }
                    handle.clearSchema();
                    all[i] = undefined;
                    hasChanges = true;
                }
            }
        }
        return hasChanges;
    };
    JSONSchemaService.prototype.normalizeId = function (id) {
        // remove trailing '#', normalize drive capitalization
        try {
            return URI.parse(id).toString();
        }
        catch (e) {
            return id;
        }
    };
    JSONSchemaService.prototype.setSchemaContributions = function (schemaContributions) {
        if (schemaContributions.schemas) {
            var schemas = schemaContributions.schemas;
            for (var id in schemas) {
                var normalizedId = this.normalizeId(id);
                this.contributionSchemas[normalizedId] = this.addSchemaHandle(normalizedId, schemas[id]);
            }
        }
        if (schemaContributions.schemaAssociations) {
            var schemaAssociations = schemaContributions.schemaAssociations;
            for (var pattern in schemaAssociations) {
                var associations = schemaAssociations[pattern];
                this.contributionAssociations[pattern] = associations;
                var fpa = this.getOrAddFilePatternAssociation(pattern);
                for (var _i = 0, associations_1 = associations; _i < associations_1.length; _i++) {
                    var schemaId = associations_1[_i];
                    var id = this.normalizeId(schemaId);
                    fpa.addSchema(id);
                }
            }
        }
    };
    JSONSchemaService.prototype.addSchemaHandle = function (id, unresolvedSchemaContent) {
        var schemaHandle = new SchemaHandle(this, id, unresolvedSchemaContent);
        this.schemasById[id] = schemaHandle;
        return schemaHandle;
    };
    JSONSchemaService.prototype.getOrAddSchemaHandle = function (id, unresolvedSchemaContent) {
        return this.schemasById[id] || this.addSchemaHandle(id, unresolvedSchemaContent);
    };
    JSONSchemaService.prototype.getOrAddFilePatternAssociation = function (pattern) {
        var fpa = this.filePatternAssociationById[pattern];
        if (!fpa) {
            fpa = new FilePatternAssociation(pattern);
            this.filePatternAssociationById[pattern] = fpa;
            this.filePatternAssociations.push(fpa);
        }
        return fpa;
    };
    JSONSchemaService.prototype.registerExternalSchema = function (uri, filePatterns, unresolvedSchemaContent) {
        if (filePatterns === void 0) { filePatterns = null; }
        var id = this.normalizeId(uri);
        this.registeredSchemasIds[id] = true;
        if (filePatterns) {
            for (var _i = 0, filePatterns_1 = filePatterns; _i < filePatterns_1.length; _i++) {
                var pattern = filePatterns_1[_i];
                this.getOrAddFilePatternAssociation(pattern).addSchema(id);
            }
        }
        return unresolvedSchemaContent ? this.addSchemaHandle(id, unresolvedSchemaContent) : this.getOrAddSchemaHandle(id);
    };
    JSONSchemaService.prototype.clearExternalSchemas = function () {
        this.schemasById = {};
        this.filePatternAssociations = [];
        this.filePatternAssociationById = {};
        this.registeredSchemasIds = {};
        for (var id in this.contributionSchemas) {
            this.schemasById[id] = this.contributionSchemas[id];
            this.registeredSchemasIds[id] = true;
        }
        for (var pattern in this.contributionAssociations) {
            var fpa = this.getOrAddFilePatternAssociation(pattern);
            for (var _i = 0, _a = this.contributionAssociations[pattern]; _i < _a.length; _i++) {
                var schemaId = _a[_i];
                var id = this.normalizeId(schemaId);
                fpa.addSchema(id);
            }
        }
    };
    JSONSchemaService.prototype.getResolvedSchema = function (schemaId) {
        var id = this.normalizeId(schemaId);
        var schemaHandle = this.schemasById[id];
        if (schemaHandle) {
            return schemaHandle.getResolvedSchema();
        }
        return this.promise.resolve(null);
    };
    JSONSchemaService.prototype.loadSchema = function (url) {
        if (!this.requestService) {
            var errorMessage = localize('json.schema.norequestservice', 'Unable to load schema from \'{0}\'. No schema request service available', toDisplayString(url));
            return this.promise.resolve(new UnresolvedSchema({}, [errorMessage]));
        }
        return this.requestService(url).then(function (content) {
            if (!content) {
                var errorMessage = localize('json.schema.nocontent', 'Unable to load schema from \'{0}\': No content.', toDisplayString(url));
                return new UnresolvedSchema({}, [errorMessage]);
            }
            var schemaContent = {};
            var jsonErrors = [];
            schemaContent = Json.parse(content, jsonErrors);
            var errors = jsonErrors.length ? [localize('json.schema.invalidFormat', 'Unable to parse content from \'{0}\': Parse error at offset {1}.', toDisplayString(url), jsonErrors[0].offset)] : [];
            return new UnresolvedSchema(schemaContent, errors);
        }, function (error) {
            var errorMessage = error.toString();
            var errorSplit = error.toString().split('Error: ');
            if (errorSplit.length > 1) {
                // more concise error message, URL and context are attached by caller anyways
                errorMessage = errorSplit[1];
            }
            return new UnresolvedSchema({}, [errorMessage]);
        });
    };
    JSONSchemaService.prototype.resolveSchemaContent = function (schemaToResolve, schemaURL, dependencies) {
        var _this = this;
        var resolveErrors = schemaToResolve.errors.slice(0);
        var schema = schemaToResolve.schema;
        var contextService = this.contextService;
        var findSection = function (schema, path) {
            if (!path) {
                return schema;
            }
            var current = schema;
            if (path[0] === '/') {
                path = path.substr(1);
            }
            path.split('/').some(function (part) {
                current = current[part];
                return !current;
            });
            return current;
        };
        var merge = function (target, sourceRoot, sourceURI, path) {
            var section = findSection(sourceRoot, path);
            if (section) {
                for (var key in section) {
                    if (section.hasOwnProperty(key) && !target.hasOwnProperty(key)) {
                        target[key] = section[key];
                    }
                }
            }
            else {
                resolveErrors.push(localize('json.schema.invalidref', '$ref \'{0}\' in \'{1}\' can not be resolved.', path, sourceURI));
            }
        };
        var resolveExternalLink = function (node, uri, linkPath, parentSchemaURL, parentSchemaDependencies) {
            if (contextService && !/^\w+:\/\/.*/.test(uri)) {
                uri = contextService.resolveRelativePath(uri, parentSchemaURL);
            }
            uri = _this.normalizeId(uri);
            var referencedHandle = _this.getOrAddSchemaHandle(uri);
            return referencedHandle.getUnresolvedSchema().then(function (unresolvedSchema) {
                parentSchemaDependencies[uri] = true;
                if (unresolvedSchema.errors.length) {
                    var loc = linkPath ? uri + '#' + linkPath : uri;
                    resolveErrors.push(localize('json.schema.problemloadingref', 'Problems loading reference \'{0}\': {1}', loc, unresolvedSchema.errors[0]));
                }
                merge(node, unresolvedSchema.schema, uri, linkPath);
                return resolveRefs(node, unresolvedSchema.schema, uri, referencedHandle.dependencies);
            });
        };
        var resolveRefs = function (node, parentSchema, parentSchemaURL, parentSchemaDependencies) {
            if (!node || typeof node !== 'object') {
                return Promise.resolve(null);
            }
            var toWalk = [node];
            var seen = [];
            var openPromises = [];
            var collectEntries = function () {
                var entries = [];
                for (var _i = 0; _i < arguments.length; _i++) {
                    entries[_i] = arguments[_i];
                }
                for (var _a = 0, entries_1 = entries; _a < entries_1.length; _a++) {
                    var entry = entries_1[_a];
                    if (typeof entry === 'object') {
                        toWalk.push(entry);
                    }
                }
            };
            var collectMapEntries = function () {
                var maps = [];
                for (var _i = 0; _i < arguments.length; _i++) {
                    maps[_i] = arguments[_i];
                }
                for (var _a = 0, maps_1 = maps; _a < maps_1.length; _a++) {
                    var map = maps_1[_a];
                    if (typeof map === 'object') {
                        for (var key in map) {
                            var entry = map[key];
                            if (typeof entry === 'object') {
                                toWalk.push(entry);
                            }
                        }
                    }
                }
            };
            var collectArrayEntries = function () {
                var arrays = [];
                for (var _i = 0; _i < arguments.length; _i++) {
                    arrays[_i] = arguments[_i];
                }
                for (var _a = 0, arrays_1 = arrays; _a < arrays_1.length; _a++) {
                    var array = arrays_1[_a];
                    if (Array.isArray(array)) {
                        for (var _b = 0, array_1 = array; _b < array_1.length; _b++) {
                            var entry = array_1[_b];
                            if (typeof entry === 'object') {
                                toWalk.push(entry);
                            }
                        }
                    }
                }
            };
            var handleRef = function (next) {
                var seenRefs = [];
                while (next.$ref) {
                    var ref = next.$ref;
                    var segments = ref.split('#', 2);
                    delete next.$ref;
                    if (segments[0].length > 0) {
                        openPromises.push(resolveExternalLink(next, segments[0], segments[1], parentSchemaURL, parentSchemaDependencies));
                        return;
                    }
                    else {
                        if (seenRefs.indexOf(ref) === -1) {
                            merge(next, parentSchema, parentSchemaURL, segments[1]); // can set next.$ref again, use seenRefs to avoid circle
                            seenRefs.push(ref);
                        }
                    }
                }
                collectEntries(next.items, next.additionalProperties, next.not, next.contains, next.propertyNames, next.if, next.then, next.else);
                collectMapEntries(next.definitions, next.properties, next.patternProperties, next.dependencies);
                collectArrayEntries(next.anyOf, next.allOf, next.oneOf, next.items);
            };
            while (toWalk.length) {
                var next = toWalk.pop();
                if (seen.indexOf(next) >= 0) {
                    continue;
                }
                seen.push(next);
                handleRef(next);
            }
            return _this.promise.all(openPromises);
        };
        return resolveRefs(schema, schema, schemaURL, dependencies).then(function (_) { return new ResolvedSchema(schema, resolveErrors); });
    };
    JSONSchemaService.prototype.getSchemaForResource = function (resource, document) {
        // first use $schema if present
        if (document && document.root && document.root.type === 'object') {
            var schemaProperties = document.root.properties.filter(function (p) { return (p.keyNode.value === '$schema') && p.valueNode && p.valueNode.type === 'string'; });
            if (schemaProperties.length > 0) {
                var schemeId = Parser.getNodeValue(schemaProperties[0].valueNode);
                if (schemeId && Strings.startsWith(schemeId, '.') && this.contextService) {
                    schemeId = this.contextService.resolveRelativePath(schemeId, resource);
                }
                if (schemeId) {
                    var id = this.normalizeId(schemeId);
                    return this.getOrAddSchemaHandle(id).getResolvedSchema();
                }
            }
        }
        var seen = Object.create(null);
        var schemas = [];
        for (var _i = 0, _a = this.filePatternAssociations; _i < _a.length; _i++) {
            var entry = _a[_i];
            if (entry.matchesPattern(resource)) {
                for (var _b = 0, _c = entry.getSchemas(); _b < _c.length; _b++) {
                    var schemaId = _c[_b];
                    if (!seen[schemaId]) {
                        schemas.push(schemaId);
                        seen[schemaId] = true;
                    }
                }
            }
        }
        if (schemas.length > 0) {
            return this.createCombinedSchema(resource, schemas).getResolvedSchema();
        }
        return this.promise.resolve(null);
    };
    JSONSchemaService.prototype.createCombinedSchema = function (resource, schemaIds) {
        if (schemaIds.length === 1) {
            return this.getOrAddSchemaHandle(schemaIds[0]);
        }
        else {
            var combinedSchemaId = 'schemaservice://combinedSchema/' + encodeURIComponent(resource);
            var combinedSchema = {
                allOf: schemaIds.map(function (schemaId) { return ({ $ref: schemaId }); })
            };
            return this.addSchemaHandle(combinedSchemaId, combinedSchema);
        }
    };
    return JSONSchemaService;
}());
export { JSONSchemaService };
function toDisplayString(url) {
    try {
        var uri = URI.parse(url);
        if (uri.scheme === 'file') {
            return uri.fsPath;
        }
    }
    catch (e) {
        // ignore
    }
    return url;
}
