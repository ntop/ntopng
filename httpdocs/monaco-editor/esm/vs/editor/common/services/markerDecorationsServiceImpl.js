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
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { IMarkerService, MarkerSeverity } from '../../../platform/markers/common/markers.js';
import { Disposable, toDisposable } from '../../../base/common/lifecycle.js';
import { OverviewRulerLane } from '../model.js';
import { themeColorFromId } from '../../../platform/theme/common/themeService.js';
import { overviewRulerWarning, overviewRulerInfo, overviewRulerError } from '../view/editorColorRegistry.js';
import { IModelService } from './modelService.js';
import { Range } from '../core/range.js';
import { keys } from '../../../base/common/map.js';
import { Schemas } from '../../../base/common/network.js';
import { Emitter } from '../../../base/common/event.js';
import { withUndefinedAsNull } from '../../../base/common/types.js';
function MODEL_ID(resource) {
    return resource.toString();
}
var MarkerDecorations = /** @class */ (function (_super) {
    __extends(MarkerDecorations, _super);
    function MarkerDecorations(model) {
        var _this = _super.call(this) || this;
        _this.model = model;
        _this._markersData = new Map();
        _this._register(toDisposable(function () {
            _this.model.deltaDecorations(keys(_this._markersData), []);
            _this._markersData.clear();
        }));
        return _this;
    }
    MarkerDecorations.prototype.update = function (markers, newDecorations) {
        var ids = this.model.deltaDecorations(keys(this._markersData), newDecorations);
        for (var index = 0; index < ids.length; index++) {
            this._markersData.set(ids[index], markers[index]);
        }
    };
    MarkerDecorations.prototype.getMarker = function (decoration) {
        return this._markersData.get(decoration.id);
    };
    return MarkerDecorations;
}(Disposable));
var MarkerDecorationsService = /** @class */ (function (_super) {
    __extends(MarkerDecorationsService, _super);
    function MarkerDecorationsService(modelService, _markerService) {
        var _this = _super.call(this) || this;
        _this._markerService = _markerService;
        _this._onDidChangeMarker = _this._register(new Emitter());
        _this._markerDecorations = new Map();
        modelService.getModels().forEach(function (model) { return _this._onModelAdded(model); });
        _this._register(modelService.onModelAdded(_this._onModelAdded, _this));
        _this._register(modelService.onModelRemoved(_this._onModelRemoved, _this));
        _this._register(_this._markerService.onMarkerChanged(_this._handleMarkerChange, _this));
        return _this;
    }
    MarkerDecorationsService.prototype.dispose = function () {
        _super.prototype.dispose.call(this);
        this._markerDecorations.forEach(function (value) { return value.dispose(); });
        this._markerDecorations.clear();
    };
    MarkerDecorationsService.prototype.getMarker = function (model, decoration) {
        var markerDecorations = this._markerDecorations.get(MODEL_ID(model.uri));
        return markerDecorations ? withUndefinedAsNull(markerDecorations.getMarker(decoration)) : null;
    };
    MarkerDecorationsService.prototype._handleMarkerChange = function (changedResources) {
        var _this = this;
        changedResources.forEach(function (resource) {
            var markerDecorations = _this._markerDecorations.get(MODEL_ID(resource));
            if (markerDecorations) {
                _this._updateDecorations(markerDecorations);
            }
        });
    };
    MarkerDecorationsService.prototype._onModelAdded = function (model) {
        var markerDecorations = new MarkerDecorations(model);
        this._markerDecorations.set(MODEL_ID(model.uri), markerDecorations);
        this._updateDecorations(markerDecorations);
    };
    MarkerDecorationsService.prototype._onModelRemoved = function (model) {
        var _this = this;
        var markerDecorations = this._markerDecorations.get(MODEL_ID(model.uri));
        if (markerDecorations) {
            markerDecorations.dispose();
            this._markerDecorations.delete(MODEL_ID(model.uri));
        }
        // clean up markers for internal, transient models
        if (model.uri.scheme === Schemas.inMemory
            || model.uri.scheme === Schemas.internal
            || model.uri.scheme === Schemas.vscode) {
            if (this._markerService) {
                this._markerService.read({ resource: model.uri }).map(function (marker) { return marker.owner; }).forEach(function (owner) { return _this._markerService.remove(owner, [model.uri]); });
            }
        }
    };
    MarkerDecorationsService.prototype._updateDecorations = function (markerDecorations) {
        var _this = this;
        // Limit to the first 500 errors/warnings
        var markers = this._markerService.read({ resource: markerDecorations.model.uri, take: 500 });
        var newModelDecorations = markers.map(function (marker) {
            return {
                range: _this._createDecorationRange(markerDecorations.model, marker),
                options: _this._createDecorationOption(marker)
            };
        });
        markerDecorations.update(markers, newModelDecorations);
        this._onDidChangeMarker.fire(markerDecorations.model);
    };
    MarkerDecorationsService.prototype._createDecorationRange = function (model, rawMarker) {
        var ret = Range.lift(rawMarker);
        if (rawMarker.severity === MarkerSeverity.Hint) {
            if (!rawMarker.tags || rawMarker.tags.indexOf(1 /* Unnecessary */) === -1) {
                // * never render hints on multiple lines
                // * make enough space for three dots
                ret = ret.setEndPosition(ret.startLineNumber, ret.startColumn + 2);
            }
        }
        ret = model.validateRange(ret);
        if (ret.isEmpty()) {
            var word = model.getWordAtPosition(ret.getStartPosition());
            if (word) {
                ret = new Range(ret.startLineNumber, word.startColumn, ret.endLineNumber, word.endColumn);
            }
            else {
                var maxColumn = model.getLineLastNonWhitespaceColumn(ret.startLineNumber) ||
                    model.getLineMaxColumn(ret.startLineNumber);
                if (maxColumn === 1) {
                    // empty line
                    // console.warn('marker on empty line:', marker);
                }
                else if (ret.endColumn >= maxColumn) {
                    // behind eol
                    ret = new Range(ret.startLineNumber, maxColumn - 1, ret.endLineNumber, maxColumn);
                }
                else {
                    // extend marker to width = 1
                    ret = new Range(ret.startLineNumber, ret.startColumn, ret.endLineNumber, ret.endColumn + 1);
                }
            }
        }
        else if (rawMarker.endColumn === Number.MAX_VALUE && rawMarker.startColumn === 1 && ret.startLineNumber === ret.endLineNumber) {
            var minColumn = model.getLineFirstNonWhitespaceColumn(rawMarker.startLineNumber);
            if (minColumn < ret.endColumn) {
                ret = new Range(ret.startLineNumber, minColumn, ret.endLineNumber, ret.endColumn);
                rawMarker.startColumn = minColumn;
            }
        }
        return ret;
    };
    MarkerDecorationsService.prototype._createDecorationOption = function (marker) {
        var className;
        var color = undefined;
        var zIndex;
        var inlineClassName = undefined;
        switch (marker.severity) {
            case MarkerSeverity.Hint:
                if (marker.tags && marker.tags.indexOf(1 /* Unnecessary */) >= 0) {
                    className = "squiggly-unnecessary" /* EditorUnnecessaryDecoration */;
                }
                else {
                    className = "squiggly-hint" /* EditorHintDecoration */;
                }
                zIndex = 0;
                break;
            case MarkerSeverity.Warning:
                className = "squiggly-warning" /* EditorWarningDecoration */;
                color = themeColorFromId(overviewRulerWarning);
                zIndex = 20;
                break;
            case MarkerSeverity.Info:
                className = "squiggly-info" /* EditorInfoDecoration */;
                color = themeColorFromId(overviewRulerInfo);
                zIndex = 10;
                break;
            case MarkerSeverity.Error:
            default:
                className = "squiggly-error" /* EditorErrorDecoration */;
                color = themeColorFromId(overviewRulerError);
                zIndex = 30;
                break;
        }
        if (marker.tags) {
            if (marker.tags.indexOf(1 /* Unnecessary */) !== -1) {
                inlineClassName = "squiggly-inline-unnecessary" /* EditorUnnecessaryInlineDecoration */;
            }
            if (marker.tags.indexOf(2 /* Deprecated */) !== -1) {
                inlineClassName = "squiggly-inline-deprecated" /* EditorDeprecatedInlineDecoration */;
            }
        }
        return {
            stickiness: 1 /* NeverGrowsWhenTypingAtEdges */,
            className: className,
            showIfCollapsed: true,
            overviewRuler: {
                color: color,
                position: OverviewRulerLane.Right
            },
            zIndex: zIndex,
            inlineClassName: inlineClassName,
        };
    };
    MarkerDecorationsService = __decorate([
        __param(0, IModelService),
        __param(1, IMarkerService)
    ], MarkerDecorationsService);
    return MarkerDecorationsService;
}(Disposable));
export { MarkerDecorationsService };
