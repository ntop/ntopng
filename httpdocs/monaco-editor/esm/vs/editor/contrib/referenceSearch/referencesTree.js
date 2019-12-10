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
import { ReferencesModel, FileReferences, OneReference } from './referencesModel.js';
import { ITextModelService } from '../../common/services/resolverService.js';
import { IconLabel } from '../../../base/browser/ui/iconLabel/iconLabel.js';
import { CountBadge } from '../../../base/browser/ui/countBadge/countBadge.js';
import { ILabelService } from '../../../platform/label/common/label.js';
import { IThemeService } from '../../../platform/theme/common/themeService.js';
import { attachBadgeStyler } from '../../../platform/theme/common/styler.js';
import * as dom from '../../../base/browser/dom.js';
import { localize } from '../../../nls.js';
import { getBaseLabel } from '../../../base/common/labels.js';
import { dirname, basename } from '../../../base/common/resources.js';
import { Disposable } from '../../../base/common/lifecycle.js';
import { IInstantiationService } from '../../../platform/instantiation/common/instantiation.js';
import { IKeybindingService } from '../../../platform/keybinding/common/keybinding.js';
import { FuzzyScore, createMatches } from '../../../base/common/filters.js';
import { HighlightedLabel } from '../../../base/browser/ui/highlightedlabel/highlightedLabel.js';
var DataSource = /** @class */ (function () {
    function DataSource(_resolverService) {
        this._resolverService = _resolverService;
    }
    DataSource.prototype.hasChildren = function (element) {
        if (element instanceof ReferencesModel) {
            return true;
        }
        if (element instanceof FileReferences && !element.failure) {
            return true;
        }
        return false;
    };
    DataSource.prototype.getChildren = function (element) {
        if (element instanceof ReferencesModel) {
            return element.groups;
        }
        if (element instanceof FileReferences) {
            return element.resolve(this._resolverService).then(function (val) {
                // if (element.failure) {
                // 	// refresh the element on failure so that
                // 	// we can update its rendering
                // 	return tree.refresh(element).then(() => val.children);
                // }
                return val.children;
            });
        }
        throw new Error('bad tree');
    };
    DataSource = __decorate([
        __param(0, ITextModelService)
    ], DataSource);
    return DataSource;
}());
export { DataSource };
//#endregion
var Delegate = /** @class */ (function () {
    function Delegate() {
    }
    Delegate.prototype.getHeight = function () {
        return 23;
    };
    Delegate.prototype.getTemplateId = function (element) {
        if (element instanceof FileReferences) {
            return FileReferencesRenderer.id;
        }
        else {
            return OneReferenceRenderer.id;
        }
    };
    return Delegate;
}());
export { Delegate };
var StringRepresentationProvider = /** @class */ (function () {
    function StringRepresentationProvider(_keybindingService) {
        this._keybindingService = _keybindingService;
    }
    StringRepresentationProvider.prototype.getKeyboardNavigationLabel = function (element) {
        if (element instanceof OneReference) {
            var preview = element.parent.preview;
            var parts = preview && preview.preview(element.range);
            if (parts) {
                return parts.value;
            }
        }
        // FileReferences or unresolved OneReference
        return basename(element.uri);
    };
    StringRepresentationProvider.prototype.mightProducePrintableCharacter = function (event) {
        return this._keybindingService.mightProducePrintableCharacter(event);
    };
    StringRepresentationProvider = __decorate([
        __param(0, IKeybindingService)
    ], StringRepresentationProvider);
    return StringRepresentationProvider;
}());
export { StringRepresentationProvider };
var IdentityProvider = /** @class */ (function () {
    function IdentityProvider() {
    }
    IdentityProvider.prototype.getId = function (element) {
        return element.id;
    };
    return IdentityProvider;
}());
export { IdentityProvider };
//#region render: File
var FileReferencesTemplate = /** @class */ (function (_super) {
    __extends(FileReferencesTemplate, _super);
    function FileReferencesTemplate(container, _uriLabel, themeService) {
        var _this = _super.call(this) || this;
        _this._uriLabel = _uriLabel;
        var parent = document.createElement('div');
        dom.addClass(parent, 'reference-file');
        _this.file = _this._register(new IconLabel(parent, { supportHighlights: true }));
        _this.badge = new CountBadge(dom.append(parent, dom.$('.count')));
        _this._register(attachBadgeStyler(_this.badge, themeService));
        container.appendChild(parent);
        return _this;
    }
    FileReferencesTemplate.prototype.set = function (element, matches) {
        var parent = dirname(element.uri);
        this.file.setLabel(getBaseLabel(element.uri), this._uriLabel.getUriLabel(parent, { relative: true }), { title: this._uriLabel.getUriLabel(element.uri), matches: matches });
        var len = element.children.length;
        this.badge.setCount(len);
        if (element.failure) {
            this.badge.setTitleFormat(localize('referencesFailre', "Failed to resolve file."));
        }
        else if (len > 1) {
            this.badge.setTitleFormat(localize('referencesCount', "{0} references", len));
        }
        else {
            this.badge.setTitleFormat(localize('referenceCount', "{0} reference", len));
        }
    };
    FileReferencesTemplate = __decorate([
        __param(1, ILabelService),
        __param(2, IThemeService)
    ], FileReferencesTemplate);
    return FileReferencesTemplate;
}(Disposable));
var FileReferencesRenderer = /** @class */ (function () {
    function FileReferencesRenderer(_instantiationService) {
        this._instantiationService = _instantiationService;
        this.templateId = FileReferencesRenderer.id;
    }
    FileReferencesRenderer.prototype.renderTemplate = function (container) {
        return this._instantiationService.createInstance(FileReferencesTemplate, container);
    };
    FileReferencesRenderer.prototype.renderElement = function (node, index, template) {
        template.set(node.element, createMatches(node.filterData));
    };
    FileReferencesRenderer.prototype.disposeTemplate = function (templateData) {
        templateData.dispose();
    };
    FileReferencesRenderer.id = 'FileReferencesRenderer';
    FileReferencesRenderer = __decorate([
        __param(0, IInstantiationService)
    ], FileReferencesRenderer);
    return FileReferencesRenderer;
}());
export { FileReferencesRenderer };
//#endregion
//#region render: Reference
var OneReferenceTemplate = /** @class */ (function () {
    function OneReferenceTemplate(container) {
        this.label = new HighlightedLabel(container, false);
    }
    OneReferenceTemplate.prototype.set = function (element, score) {
        var filePreview = element.parent.preview;
        var preview = filePreview && filePreview.preview(element.range);
        if (!preview) {
            // this means we FAILED to resolve the document...
            this.label.set(basename(element.uri) + ":" + (element.range.startLineNumber + 1) + ":" + (element.range.startColumn + 1));
        }
        else {
            // render search match as highlight unless
            // we have score, then render the score
            var value = preview.value, highlight = preview.highlight;
            if (score && !FuzzyScore.isDefault(score)) {
                dom.toggleClass(this.label.element, 'referenceMatch', false);
                this.label.set(value, createMatches(score));
            }
            else {
                dom.toggleClass(this.label.element, 'referenceMatch', true);
                this.label.set(value, [highlight]);
            }
        }
    };
    return OneReferenceTemplate;
}());
var OneReferenceRenderer = /** @class */ (function () {
    function OneReferenceRenderer() {
        this.templateId = OneReferenceRenderer.id;
    }
    OneReferenceRenderer.prototype.renderTemplate = function (container) {
        return new OneReferenceTemplate(container);
    };
    OneReferenceRenderer.prototype.renderElement = function (node, index, templateData) {
        templateData.set(node.element, node.filterData);
    };
    OneReferenceRenderer.prototype.disposeTemplate = function () {
    };
    OneReferenceRenderer.id = 'OneReferenceRenderer';
    return OneReferenceRenderer;
}());
export { OneReferenceRenderer };
//#endregion
var AriaProvider = /** @class */ (function () {
    function AriaProvider() {
    }
    AriaProvider.prototype.getAriaLabel = function (element) {
        if (element instanceof FileReferences) {
            return element.getAriaMessage();
        }
        else if (element instanceof OneReference) {
            return element.getAriaMessage();
        }
        else {
            return null;
        }
    };
    return AriaProvider;
}());
export { AriaProvider };
