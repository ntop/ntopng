/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
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
import { illegalArgument } from '../../../base/common/errors.js';
import { URI } from '../../../base/common/uri.js';
import { Range } from '../../common/core/range.js';
import { registerLanguageCommand } from '../../browser/editorExtensions.js';
import { IModelService } from '../../common/services/modelService.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { ITextModelService } from '../../common/services/resolverService.js';
import { OutlineModel, OutlineElement } from '../documentSymbols/outlineModel.js';
import { values } from '../../../base/common/collections.js';
export function getDocumentSymbols(document, flat, token) {
    return __awaiter(this, void 0, void 0, function () {
        var model, roots, _i, _a, child, flatEntries;
        return __generator(this, function (_b) {
            switch (_b.label) {
                case 0: return [4 /*yield*/, OutlineModel.create(document, token)];
                case 1:
                    model = _b.sent();
                    roots = [];
                    for (_i = 0, _a = values(model.children); _i < _a.length; _i++) {
                        child = _a[_i];
                        if (child instanceof OutlineElement) {
                            roots.push(child.symbol);
                        }
                        else {
                            roots.push.apply(roots, values(child.children).map(function (child) { return child.symbol; }));
                        }
                    }
                    flatEntries = [];
                    if (token.isCancellationRequested) {
                        return [2 /*return*/, flatEntries];
                    }
                    if (flat) {
                        flatten(flatEntries, roots, '');
                    }
                    else {
                        flatEntries = roots;
                    }
                    return [2 /*return*/, flatEntries.sort(compareEntriesUsingStart)];
            }
        });
    });
}
function compareEntriesUsingStart(a, b) {
    return Range.compareRangesUsingStarts(a.range, b.range);
}
function flatten(bucket, entries, overrideContainerLabel) {
    for (var _i = 0, entries_1 = entries; _i < entries_1.length; _i++) {
        var entry = entries_1[_i];
        bucket.push({
            kind: entry.kind,
            tags: entry.tags,
            name: entry.name,
            detail: entry.detail,
            containerName: entry.containerName || overrideContainerLabel,
            range: entry.range,
            selectionRange: entry.selectionRange,
            children: undefined,
        });
        if (entry.children) {
            flatten(bucket, entry.children, entry.name);
        }
    }
}
registerLanguageCommand('_executeDocumentSymbolProvider', function (accessor, args) {
    var resource = args.resource;
    if (!(resource instanceof URI)) {
        throw illegalArgument('resource');
    }
    var model = accessor.get(IModelService).getModel(resource);
    if (model) {
        return getDocumentSymbols(model, false, CancellationToken.None);
    }
    return accessor.get(ITextModelService).createModelReference(resource).then(function (reference) {
        return new Promise(function (resolve, reject) {
            try {
                var result = getDocumentSymbols(reference.object.textEditorModel, false, CancellationToken.None);
                resolve(result);
            }
            catch (err) {
                reject(err);
            }
        }).finally(function () {
            reference.dispose();
        });
    });
});
