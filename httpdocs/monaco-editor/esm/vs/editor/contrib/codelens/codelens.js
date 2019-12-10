/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { mergeSort } from '../../../base/common/arrays.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { illegalArgument, onUnexpectedExternalError } from '../../../base/common/errors.js';
import { URI } from '../../../base/common/uri.js';
import { registerLanguageCommand } from '../../browser/editorExtensions.js';
import { CodeLensProviderRegistry } from '../../common/modes.js';
import { IModelService } from '../../common/services/modelService.js';
import { DisposableStore } from '../../../base/common/lifecycle.js';
var CodeLensModel = /** @class */ (function () {
    function CodeLensModel() {
        this.lenses = [];
        this._dispoables = new DisposableStore();
    }
    CodeLensModel.prototype.dispose = function () {
        this._dispoables.dispose();
    };
    CodeLensModel.prototype.add = function (list, provider) {
        this._dispoables.add(list);
        for (var _i = 0, _a = list.lenses; _i < _a.length; _i++) {
            var symbol = _a[_i];
            this.lenses.push({ symbol: symbol, provider: provider });
        }
    };
    return CodeLensModel;
}());
export { CodeLensModel };
export function getCodeLensData(model, token) {
    var provider = CodeLensProviderRegistry.ordered(model);
    var providerRanks = new Map();
    var result = new CodeLensModel();
    var promises = provider.map(function (provider, i) {
        providerRanks.set(provider, i);
        return Promise.resolve(provider.provideCodeLenses(model, token))
            .then(function (list) { return list && result.add(list, provider); })
            .catch(onUnexpectedExternalError);
    });
    return Promise.all(promises).then(function () {
        result.lenses = mergeSort(result.lenses, function (a, b) {
            // sort by lineNumber, provider-rank, and column
            if (a.symbol.range.startLineNumber < b.symbol.range.startLineNumber) {
                return -1;
            }
            else if (a.symbol.range.startLineNumber > b.symbol.range.startLineNumber) {
                return 1;
            }
            else if (providerRanks.get(a.provider) < providerRanks.get(b.provider)) {
                return -1;
            }
            else if (providerRanks.get(a.provider) > providerRanks.get(b.provider)) {
                return 1;
            }
            else if (a.symbol.range.startColumn < b.symbol.range.startColumn) {
                return -1;
            }
            else if (a.symbol.range.startColumn > b.symbol.range.startColumn) {
                return 1;
            }
            else {
                return 0;
            }
        });
        return result;
    });
}
registerLanguageCommand('_executeCodeLensProvider', function (accessor, args) {
    var resource = args.resource, itemResolveCount = args.itemResolveCount;
    if (!(resource instanceof URI)) {
        throw illegalArgument();
    }
    var model = accessor.get(IModelService).getModel(resource);
    if (!model) {
        throw illegalArgument();
    }
    var result = [];
    var disposables = new DisposableStore();
    return getCodeLensData(model, CancellationToken.None).then(function (value) {
        disposables.add(value);
        var resolve = [];
        var _loop_1 = function (item) {
            if (typeof itemResolveCount === 'undefined' || Boolean(item.symbol.command)) {
                result.push(item.symbol);
            }
            else if (itemResolveCount-- > 0 && item.provider.resolveCodeLens) {
                resolve.push(Promise.resolve(item.provider.resolveCodeLens(model, item.symbol, CancellationToken.None)).then(function (symbol) { return result.push(symbol || item.symbol); }));
            }
        };
        for (var _i = 0, _a = value.lenses; _i < _a.length; _i++) {
            var item = _a[_i];
            _loop_1(item);
        }
        return Promise.all(resolve);
    }).then(function () {
        return result;
    }).finally(function () {
        // make sure to return results, then (on next tick)
        // dispose the results
        setTimeout(function () { return disposables.dispose(); }, 100);
    });
});
