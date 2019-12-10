/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { RunOnceScheduler, createCancelablePromise, disposableTimeout } from '../../../base/common/async.js';
import { onUnexpectedError, onUnexpectedExternalError } from '../../../base/common/errors.js';
import { toDisposable, DisposableStore, dispose } from '../../../base/common/lifecycle.js';
import { StableEditorScrollState } from '../../browser/core/editorState.js';
import { registerEditorContribution } from '../../browser/editorExtensions.js';
import { CodeLensProviderRegistry } from '../../common/modes.js';
import { getCodeLensData } from './codelens.js';
import { CodeLensWidget, CodeLensHelper } from './codelensWidget.js';
import { ICommandService } from '../../../platform/commands/common/commands.js';
import { INotificationService } from '../../../platform/notification/common/notification.js';
import { ICodeLensCache } from './codeLensCache.js';
var CodeLensContribution = /** @class */ (function () {
    function CodeLensContribution(_editor, _commandService, _notificationService, _codeLensCache) {
        var _this = this;
        this._editor = _editor;
        this._commandService = _commandService;
        this._notificationService = _notificationService;
        this._codeLensCache = _codeLensCache;
        this._globalToDispose = new DisposableStore();
        this._localToDispose = new DisposableStore();
        this._lenses = [];
        this._oldCodeLensModels = new DisposableStore();
        this._modelChangeCounter = 0;
        this._isEnabled = this._editor.getConfiguration().contribInfo.codeLens;
        this._globalToDispose.add(this._editor.onDidChangeModel(function () { return _this._onModelChange(); }));
        this._globalToDispose.add(this._editor.onDidChangeModelLanguage(function () { return _this._onModelChange(); }));
        this._globalToDispose.add(this._editor.onDidChangeConfiguration(function () {
            var prevIsEnabled = _this._isEnabled;
            _this._isEnabled = _this._editor.getConfiguration().contribInfo.codeLens;
            if (prevIsEnabled !== _this._isEnabled) {
                _this._onModelChange();
            }
        }));
        this._globalToDispose.add(CodeLensProviderRegistry.onDidChange(this._onModelChange, this));
        this._onModelChange();
    }
    CodeLensContribution.prototype.dispose = function () {
        this._localDispose();
        this._globalToDispose.dispose();
        this._oldCodeLensModels.dispose();
        dispose(this._currentCodeLensModel);
    };
    CodeLensContribution.prototype._localDispose = function () {
        if (this._currentFindCodeLensSymbolsPromise) {
            this._currentFindCodeLensSymbolsPromise.cancel();
            this._currentFindCodeLensSymbolsPromise = undefined;
            this._modelChangeCounter++;
        }
        if (this._currentResolveCodeLensSymbolsPromise) {
            this._currentResolveCodeLensSymbolsPromise.cancel();
            this._currentResolveCodeLensSymbolsPromise = undefined;
        }
        this._localToDispose.clear();
        this._oldCodeLensModels.clear();
        dispose(this._currentCodeLensModel);
    };
    CodeLensContribution.prototype.getId = function () {
        return CodeLensContribution.ID;
    };
    CodeLensContribution.prototype._onModelChange = function () {
        var _this = this;
        this._localDispose();
        var model = this._editor.getModel();
        if (!model) {
            return;
        }
        if (!this._isEnabled) {
            return;
        }
        var cachedLenses = this._codeLensCache.get(model);
        if (cachedLenses) {
            this._renderCodeLensSymbols(cachedLenses);
        }
        if (!CodeLensProviderRegistry.has(model)) {
            // no provider -> return but check with
            // cached lenses. they expire after 30 seconds
            if (cachedLenses) {
                this._localToDispose.add(disposableTimeout(function () {
                    var cachedLensesNow = _this._codeLensCache.get(model);
                    if (cachedLenses === cachedLensesNow) {
                        _this._codeLensCache.delete(model);
                        _this._onModelChange();
                    }
                }, 30 * 1000));
            }
            return;
        }
        for (var _i = 0, _a = CodeLensProviderRegistry.all(model); _i < _a.length; _i++) {
            var provider = _a[_i];
            if (typeof provider.onDidChange === 'function') {
                var registration = provider.onDidChange(function () { return scheduler.schedule(); });
                this._localToDispose.add(registration);
            }
        }
        var detectVisibleLenses = this._detectVisibleLenses = new RunOnceScheduler(function () { return _this._onViewportChanged(); }, 250);
        var scheduler = new RunOnceScheduler(function () {
            var counterValue = ++_this._modelChangeCounter;
            if (_this._currentFindCodeLensSymbolsPromise) {
                _this._currentFindCodeLensSymbolsPromise.cancel();
            }
            _this._currentFindCodeLensSymbolsPromise = createCancelablePromise(function (token) { return getCodeLensData(model, token); });
            _this._currentFindCodeLensSymbolsPromise.then(function (result) {
                if (counterValue === _this._modelChangeCounter) { // only the last one wins
                    if (_this._currentCodeLensModel) {
                        _this._oldCodeLensModels.add(_this._currentCodeLensModel);
                    }
                    _this._currentCodeLensModel = result;
                    // cache model to reduce flicker
                    _this._codeLensCache.put(model, result);
                    // render lenses
                    _this._renderCodeLensSymbols(result);
                    detectVisibleLenses.schedule();
                }
            }, onUnexpectedError);
        }, 250);
        this._localToDispose.add(scheduler);
        this._localToDispose.add(detectVisibleLenses);
        this._localToDispose.add(this._editor.onDidChangeModelContent(function () {
            _this._editor.changeDecorations(function (decorationsAccessor) {
                _this._editor.changeViewZones(function (viewZonesAccessor) {
                    var toDispose = [];
                    var lastLensLineNumber = -1;
                    _this._lenses.forEach(function (lens) {
                        if (!lens.isValid() || lastLensLineNumber === lens.getLineNumber()) {
                            // invalid -> lens collapsed, attach range doesn't exist anymore
                            // line_number -> lenses should never be on the same line
                            toDispose.push(lens);
                        }
                        else {
                            lens.update(viewZonesAccessor);
                            lastLensLineNumber = lens.getLineNumber();
                        }
                    });
                    var helper = new CodeLensHelper();
                    toDispose.forEach(function (l) {
                        l.dispose(helper, viewZonesAccessor);
                        _this._lenses.splice(_this._lenses.indexOf(l), 1);
                    });
                    helper.commit(decorationsAccessor);
                });
            });
            // Compute new `visible` code lenses
            detectVisibleLenses.schedule();
            // Ask for all references again
            scheduler.schedule();
        }));
        this._localToDispose.add(this._editor.onDidScrollChange(function (e) {
            if (e.scrollTopChanged && _this._lenses.length > 0) {
                detectVisibleLenses.schedule();
            }
        }));
        this._localToDispose.add(this._editor.onDidLayoutChange(function () {
            detectVisibleLenses.schedule();
        }));
        this._localToDispose.add(toDisposable(function () {
            if (_this._editor.getModel()) {
                var scrollState = StableEditorScrollState.capture(_this._editor);
                _this._editor.changeDecorations(function (decorationsAccessor) {
                    _this._editor.changeViewZones(function (viewZonesAccessor) {
                        _this._disposeAllLenses(decorationsAccessor, viewZonesAccessor);
                    });
                });
                scrollState.restore(_this._editor);
            }
            else {
                // No accessors available
                _this._disposeAllLenses(undefined, undefined);
            }
        }));
        this._localToDispose.add(this._editor.onDidChangeConfiguration(function (e) {
            if (e.fontInfo) {
                for (var _i = 0, _a = _this._lenses; _i < _a.length; _i++) {
                    var lens = _a[_i];
                    lens.updateHeight();
                }
            }
        }));
        this._localToDispose.add(this._editor.onMouseUp(function (e) {
            var _a;
            if (e.target.type === 9 /* CONTENT_WIDGET */ && e.target.element && e.target.element.tagName === 'A') {
                for (var _i = 0, _b = _this._lenses; _i < _b.length; _i++) {
                    var lens = _b[_i];
                    var command = lens.getCommand(e.target.element);
                    if (command) {
                        (_a = _this._commandService).executeCommand.apply(_a, [command.id].concat((command.arguments || []))).catch(function (err) { return _this._notificationService.error(err); });
                        break;
                    }
                }
            }
        }));
        scheduler.schedule();
    };
    CodeLensContribution.prototype._disposeAllLenses = function (decChangeAccessor, viewZoneChangeAccessor) {
        var helper = new CodeLensHelper();
        this._lenses.forEach(function (lens) { return lens.dispose(helper, viewZoneChangeAccessor); });
        if (decChangeAccessor) {
            helper.commit(decChangeAccessor);
        }
        this._lenses = [];
    };
    CodeLensContribution.prototype._renderCodeLensSymbols = function (symbols) {
        var _this = this;
        if (!this._editor.hasModel()) {
            return;
        }
        var maxLineNumber = this._editor.getModel().getLineCount();
        var groups = [];
        var lastGroup;
        for (var _i = 0, _a = symbols.lenses; _i < _a.length; _i++) {
            var symbol = _a[_i];
            var line = symbol.symbol.range.startLineNumber;
            if (line < 1 || line > maxLineNumber) {
                // invalid code lens
                continue;
            }
            else if (lastGroup && lastGroup[lastGroup.length - 1].symbol.range.startLineNumber === line) {
                // on same line as previous
                lastGroup.push(symbol);
            }
            else {
                // on later line as previous
                lastGroup = [symbol];
                groups.push(lastGroup);
            }
        }
        var scrollState = StableEditorScrollState.capture(this._editor);
        this._editor.changeDecorations(function (decorationsAccessor) {
            _this._editor.changeViewZones(function (viewZoneAccessor) {
                var helper = new CodeLensHelper();
                var codeLensIndex = 0;
                var groupsIndex = 0;
                while (groupsIndex < groups.length && codeLensIndex < _this._lenses.length) {
                    var symbolsLineNumber = groups[groupsIndex][0].symbol.range.startLineNumber;
                    var codeLensLineNumber = _this._lenses[codeLensIndex].getLineNumber();
                    if (codeLensLineNumber < symbolsLineNumber) {
                        _this._lenses[codeLensIndex].dispose(helper, viewZoneAccessor);
                        _this._lenses.splice(codeLensIndex, 1);
                    }
                    else if (codeLensLineNumber === symbolsLineNumber) {
                        _this._lenses[codeLensIndex].updateCodeLensSymbols(groups[groupsIndex], helper);
                        groupsIndex++;
                        codeLensIndex++;
                    }
                    else {
                        _this._lenses.splice(codeLensIndex, 0, new CodeLensWidget(groups[groupsIndex], _this._editor, helper, viewZoneAccessor, function () { return _this._detectVisibleLenses && _this._detectVisibleLenses.schedule(); }));
                        codeLensIndex++;
                        groupsIndex++;
                    }
                }
                // Delete extra code lenses
                while (codeLensIndex < _this._lenses.length) {
                    _this._lenses[codeLensIndex].dispose(helper, viewZoneAccessor);
                    _this._lenses.splice(codeLensIndex, 1);
                }
                // Create extra symbols
                while (groupsIndex < groups.length) {
                    _this._lenses.push(new CodeLensWidget(groups[groupsIndex], _this._editor, helper, viewZoneAccessor, function () { return _this._detectVisibleLenses && _this._detectVisibleLenses.schedule(); }));
                    groupsIndex++;
                }
                helper.commit(decorationsAccessor);
            });
        });
        scrollState.restore(this._editor);
    };
    CodeLensContribution.prototype._onViewportChanged = function () {
        var _this = this;
        if (this._currentResolveCodeLensSymbolsPromise) {
            this._currentResolveCodeLensSymbolsPromise.cancel();
            this._currentResolveCodeLensSymbolsPromise = undefined;
        }
        var model = this._editor.getModel();
        if (!model) {
            return;
        }
        var toResolve = [];
        var lenses = [];
        this._lenses.forEach(function (lens) {
            var request = lens.computeIfNecessary(model);
            if (request) {
                toResolve.push(request);
                lenses.push(lens);
            }
        });
        if (toResolve.length === 0) {
            return;
        }
        this._currentResolveCodeLensSymbolsPromise = createCancelablePromise(function (token) {
            var promises = toResolve.map(function (request, i) {
                var resolvedSymbols = new Array(request.length);
                var promises = request.map(function (request, i) {
                    if (!request.symbol.command && typeof request.provider.resolveCodeLens === 'function') {
                        return Promise.resolve(request.provider.resolveCodeLens(model, request.symbol, token)).then(function (symbol) {
                            resolvedSymbols[i] = symbol;
                        }, onUnexpectedExternalError);
                    }
                    else {
                        resolvedSymbols[i] = request.symbol;
                        return Promise.resolve(undefined);
                    }
                });
                return Promise.all(promises).then(function () {
                    if (!token.isCancellationRequested) {
                        lenses[i].updateCommands(resolvedSymbols);
                    }
                });
            });
            return Promise.all(promises);
        });
        this._currentResolveCodeLensSymbolsPromise.then(function () {
            _this._oldCodeLensModels.clear(); // dispose old models once we have updated the UI with the current model
            _this._currentResolveCodeLensSymbolsPromise = undefined;
        }, function (err) {
            onUnexpectedError(err); // can also be cancellation!
            _this._currentResolveCodeLensSymbolsPromise = undefined;
        });
    };
    CodeLensContribution.ID = 'css.editor.codeLens';
    CodeLensContribution = __decorate([
        __param(1, ICommandService),
        __param(2, INotificationService),
        __param(3, ICodeLensCache)
    ], CodeLensContribution);
    return CodeLensContribution;
}());
export { CodeLensContribution };
registerEditorContribution(CodeLensContribution);
