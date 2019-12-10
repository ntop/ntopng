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
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var _a;
import { createStyleSheet } from '../../../base/browser/dom.js';
import { DefaultStyleController, isSelectionRangeChangeEvent, isSelectionSingleChangeEvent } from '../../../base/browser/ui/list/listWidget.js';
import { Disposable, dispose, toDisposable, DisposableStore, combinedDisposable } from '../../../base/common/lifecycle.js';
import { localize } from '../../../nls.js';
import { IConfigurationService, getMigratedSettingValue } from '../../configuration/common/configuration.js';
import { Extensions as ConfigurationExtensions } from '../../configuration/common/configurationRegistry.js';
import { IContextKeyService, RawContextKey } from '../../contextkey/common/contextkey.js';
import { createDecorator } from '../../instantiation/common/instantiation.js';
import { IKeybindingService } from '../../keybinding/common/keybinding.js';
import { Registry } from '../../registry/common/platform.js';
import { attachListStyler, computeStyles, defaultListStyles } from '../../theme/common/styler.js';
import { IThemeService } from '../../theme/common/themeService.js';
import { ObjectTree } from '../../../base/browser/ui/tree/objectTree.js';
import { AsyncDataTree } from '../../../base/browser/ui/tree/asyncDataTree.js';
import { DataTree } from '../../../base/browser/ui/tree/dataTree.js';
import { IAccessibilityService } from '../../accessibility/common/accessibility.js';
export var IListService = createDecorator('listService');
var ListService = /** @class */ (function () {
    function ListService(contextKeyService) {
        this.lists = [];
        this._lastFocusedWidget = undefined;
    }
    Object.defineProperty(ListService.prototype, "lastFocusedList", {
        get: function () {
            return this._lastFocusedWidget;
        },
        enumerable: true,
        configurable: true
    });
    ListService.prototype.register = function (widget, extraContextKeys) {
        var _this = this;
        if (this.lists.some(function (l) { return l.widget === widget; })) {
            throw new Error('Cannot register the same widget multiple times');
        }
        // Keep in our lists list
        var registeredList = { widget: widget, extraContextKeys: extraContextKeys };
        this.lists.push(registeredList);
        // Check for currently being focused
        if (widget.getHTMLElement() === document.activeElement) {
            this._lastFocusedWidget = widget;
        }
        return combinedDisposable(widget.onDidFocus(function () { return _this._lastFocusedWidget = widget; }), toDisposable(function () { return _this.lists.splice(_this.lists.indexOf(registeredList), 1); }), widget.onDidDispose(function () {
            _this.lists = _this.lists.filter(function (l) { return l !== registeredList; });
            if (_this._lastFocusedWidget === widget) {
                _this._lastFocusedWidget = undefined;
            }
        }));
    };
    ListService = __decorate([
        __param(0, IContextKeyService)
    ], ListService);
    return ListService;
}());
export { ListService };
var RawWorkbenchListFocusContextKey = new RawContextKey('listFocus', true);
export var WorkbenchListSupportsMultiSelectContextKey = new RawContextKey('listSupportsMultiselect', true);
export var WorkbenchListHasSelectionOrFocus = new RawContextKey('listHasSelectionOrFocus', false);
export var WorkbenchListDoubleSelection = new RawContextKey('listDoubleSelection', false);
export var WorkbenchListMultiSelection = new RawContextKey('listMultiSelection', false);
export var WorkbenchListSupportsKeyboardNavigation = new RawContextKey('listSupportsKeyboardNavigation', true);
export var WorkbenchListAutomaticKeyboardNavigationKey = 'listAutomaticKeyboardNavigation';
export var WorkbenchListAutomaticKeyboardNavigation = new RawContextKey(WorkbenchListAutomaticKeyboardNavigationKey, true);
export var didBindWorkbenchListAutomaticKeyboardNavigation = false;
function createScopedContextKeyService(contextKeyService, widget) {
    var result = contextKeyService.createScoped(widget.getHTMLElement());
    RawWorkbenchListFocusContextKey.bindTo(result);
    return result;
}
export var multiSelectModifierSettingKey = 'workbench.list.multiSelectModifier';
export var openModeSettingKey = 'workbench.list.openMode';
export var horizontalScrollingKey = 'workbench.list.horizontalScrolling';
export var keyboardNavigationSettingKey = 'workbench.list.keyboardNavigation';
export var automaticKeyboardNavigationSettingKey = 'workbench.list.automaticKeyboardNavigation';
var treeIndentKey = 'workbench.tree.indent';
var treeRenderIndentGuidesKey = 'workbench.tree.renderIndentGuides';
function getHorizontalScrollingSetting(configurationService) {
    return getMigratedSettingValue(configurationService, horizontalScrollingKey, 'workbench.tree.horizontalScrolling');
}
function useAltAsMultipleSelectionModifier(configurationService) {
    return configurationService.getValue(multiSelectModifierSettingKey) === 'alt';
}
function useSingleClickToOpen(configurationService) {
    return configurationService.getValue(openModeSettingKey) !== 'doubleClick';
}
var MultipleSelectionController = /** @class */ (function (_super) {
    __extends(MultipleSelectionController, _super);
    function MultipleSelectionController(configurationService) {
        var _this = _super.call(this) || this;
        _this.configurationService = configurationService;
        _this.useAltAsMultipleSelectionModifier = useAltAsMultipleSelectionModifier(configurationService);
        _this.registerListeners();
        return _this;
    }
    MultipleSelectionController.prototype.registerListeners = function () {
        var _this = this;
        this._register(this.configurationService.onDidChangeConfiguration(function (e) {
            if (e.affectsConfiguration(multiSelectModifierSettingKey)) {
                _this.useAltAsMultipleSelectionModifier = useAltAsMultipleSelectionModifier(_this.configurationService);
            }
        }));
    };
    MultipleSelectionController.prototype.isSelectionSingleChangeEvent = function (event) {
        if (this.useAltAsMultipleSelectionModifier) {
            return event.browserEvent.altKey;
        }
        return isSelectionSingleChangeEvent(event);
    };
    MultipleSelectionController.prototype.isSelectionRangeChangeEvent = function (event) {
        return isSelectionRangeChangeEvent(event);
    };
    return MultipleSelectionController;
}(Disposable));
var WorkbenchOpenController = /** @class */ (function (_super) {
    __extends(WorkbenchOpenController, _super);
    function WorkbenchOpenController(configurationService, existingOpenController) {
        var _this = _super.call(this) || this;
        _this.configurationService = configurationService;
        _this.existingOpenController = existingOpenController;
        _this.openOnSingleClick = useSingleClickToOpen(configurationService);
        _this.registerListeners();
        return _this;
    }
    WorkbenchOpenController.prototype.registerListeners = function () {
        var _this = this;
        this._register(this.configurationService.onDidChangeConfiguration(function (e) {
            if (e.affectsConfiguration(openModeSettingKey)) {
                _this.openOnSingleClick = useSingleClickToOpen(_this.configurationService);
            }
        }));
    };
    WorkbenchOpenController.prototype.shouldOpen = function (event) {
        if (event instanceof MouseEvent) {
            var isLeftButton = event.button === 0;
            var isDoubleClick = event.detail === 2;
            if (isLeftButton && !this.openOnSingleClick && !isDoubleClick) {
                return false;
            }
            if (isLeftButton /* left mouse button */ || event.button === 1 /* middle mouse button */) {
                return this.existingOpenController ? this.existingOpenController.shouldOpen(event) : true;
            }
            return false;
        }
        return this.existingOpenController ? this.existingOpenController.shouldOpen(event) : true;
    };
    return WorkbenchOpenController;
}(Disposable));
function toWorkbenchListOptions(options, configurationService, keybindingService) {
    var disposables = new DisposableStore();
    var result = __assign({}, options);
    if (options.multipleSelectionSupport !== false && !options.multipleSelectionController) {
        var multipleSelectionController = new MultipleSelectionController(configurationService);
        result.multipleSelectionController = multipleSelectionController;
        disposables.add(multipleSelectionController);
    }
    var openController = new WorkbenchOpenController(configurationService, options.openController);
    result.openController = openController;
    disposables.add(openController);
    if (options.keyboardNavigationLabelProvider) {
        var tlp_1 = options.keyboardNavigationLabelProvider;
        result.keyboardNavigationLabelProvider = {
            getKeyboardNavigationLabel: function (e) { return tlp_1.getKeyboardNavigationLabel(e); },
            mightProducePrintableCharacter: function (e) { return keybindingService.mightProducePrintableCharacter(e); }
        };
    }
    return [result, disposables];
}
var sharedListStyleSheet;
function getSharedListStyleSheet() {
    if (!sharedListStyleSheet) {
        sharedListStyleSheet = createStyleSheet();
    }
    return sharedListStyleSheet;
}
function createKeyboardNavigationEventFilter(container, keybindingService) {
    var inChord = false;
    return function (event) {
        if (inChord) {
            inChord = false;
            return false;
        }
        var result = keybindingService.softDispatch(event, container);
        if (result && result.enterChord) {
            inChord = true;
            return false;
        }
        inChord = false;
        return true;
    };
}
var WorkbenchObjectTree = /** @class */ (function (_super) {
    __extends(WorkbenchObjectTree, _super);
    function WorkbenchObjectTree(container, delegate, renderers, options, contextKeyService, listService, themeService, configurationService, keybindingService, accessibilityService) {
        var _this = this;
        var _a = workbenchTreeDataPreamble(container, options, contextKeyService, themeService, configurationService, keybindingService, accessibilityService), treeOptions = _a.options, getAutomaticKeyboardNavigation = _a.getAutomaticKeyboardNavigation, disposable = _a.disposable;
        _this = _super.call(this, container, delegate, renderers, treeOptions) || this;
        _this.disposables.push(disposable);
        _this.internals = new WorkbenchTreeInternals(_this, treeOptions, getAutomaticKeyboardNavigation, contextKeyService, listService, themeService, configurationService, accessibilityService);
        _this.disposables.push(_this.internals);
        return _this;
    }
    WorkbenchObjectTree = __decorate([
        __param(4, IContextKeyService),
        __param(5, IListService),
        __param(6, IThemeService),
        __param(7, IConfigurationService),
        __param(8, IKeybindingService),
        __param(9, IAccessibilityService)
    ], WorkbenchObjectTree);
    return WorkbenchObjectTree;
}(ObjectTree));
export { WorkbenchObjectTree };
var WorkbenchDataTree = /** @class */ (function (_super) {
    __extends(WorkbenchDataTree, _super);
    function WorkbenchDataTree(container, delegate, renderers, dataSource, options, contextKeyService, listService, themeService, configurationService, keybindingService, accessibilityService) {
        var _this = this;
        var _a = workbenchTreeDataPreamble(container, options, contextKeyService, themeService, configurationService, keybindingService, accessibilityService), treeOptions = _a.options, getAutomaticKeyboardNavigation = _a.getAutomaticKeyboardNavigation, disposable = _a.disposable;
        _this = _super.call(this, container, delegate, renderers, dataSource, treeOptions) || this;
        _this.disposables.push(disposable);
        _this.internals = new WorkbenchTreeInternals(_this, treeOptions, getAutomaticKeyboardNavigation, contextKeyService, listService, themeService, configurationService, accessibilityService);
        _this.disposables.push(_this.internals);
        return _this;
    }
    WorkbenchDataTree = __decorate([
        __param(5, IContextKeyService),
        __param(6, IListService),
        __param(7, IThemeService),
        __param(8, IConfigurationService),
        __param(9, IKeybindingService),
        __param(10, IAccessibilityService)
    ], WorkbenchDataTree);
    return WorkbenchDataTree;
}(DataTree));
export { WorkbenchDataTree };
var WorkbenchAsyncDataTree = /** @class */ (function (_super) {
    __extends(WorkbenchAsyncDataTree, _super);
    function WorkbenchAsyncDataTree(container, delegate, renderers, dataSource, options, contextKeyService, listService, themeService, configurationService, keybindingService, accessibilityService) {
        var _this = this;
        var _a = workbenchTreeDataPreamble(container, options, contextKeyService, themeService, configurationService, keybindingService, accessibilityService), treeOptions = _a.options, getAutomaticKeyboardNavigation = _a.getAutomaticKeyboardNavigation, disposable = _a.disposable;
        _this = _super.call(this, container, delegate, renderers, dataSource, treeOptions) || this;
        _this.disposables.push(disposable);
        _this.internals = new WorkbenchTreeInternals(_this, treeOptions, getAutomaticKeyboardNavigation, contextKeyService, listService, themeService, configurationService, accessibilityService);
        _this.disposables.push(_this.internals);
        return _this;
    }
    Object.defineProperty(WorkbenchAsyncDataTree.prototype, "contextKeyService", {
        get: function () { return this.internals.contextKeyService; },
        enumerable: true,
        configurable: true
    });
    WorkbenchAsyncDataTree = __decorate([
        __param(5, IContextKeyService),
        __param(6, IListService),
        __param(7, IThemeService),
        __param(8, IConfigurationService),
        __param(9, IKeybindingService),
        __param(10, IAccessibilityService)
    ], WorkbenchAsyncDataTree);
    return WorkbenchAsyncDataTree;
}(AsyncDataTree));
export { WorkbenchAsyncDataTree };
function workbenchTreeDataPreamble(container, options, contextKeyService, themeService, configurationService, keybindingService, accessibilityService) {
    WorkbenchListSupportsKeyboardNavigation.bindTo(contextKeyService);
    if (!didBindWorkbenchListAutomaticKeyboardNavigation) {
        WorkbenchListAutomaticKeyboardNavigation.bindTo(contextKeyService);
        didBindWorkbenchListAutomaticKeyboardNavigation = true;
    }
    var getAutomaticKeyboardNavigation = function () {
        // give priority to the context key value to disable this completely
        var automaticKeyboardNavigation = contextKeyService.getContextKeyValue(WorkbenchListAutomaticKeyboardNavigationKey);
        if (automaticKeyboardNavigation) {
            automaticKeyboardNavigation = configurationService.getValue(automaticKeyboardNavigationSettingKey);
        }
        return automaticKeyboardNavigation;
    };
    var accessibilityOn = accessibilityService.getAccessibilitySupport() === 2 /* Enabled */;
    var keyboardNavigation = accessibilityOn ? 'simple' : configurationService.getValue(keyboardNavigationSettingKey);
    var horizontalScrolling = typeof options.horizontalScrolling !== 'undefined' ? options.horizontalScrolling : getHorizontalScrollingSetting(configurationService);
    var openOnSingleClick = useSingleClickToOpen(configurationService);
    var _a = toWorkbenchListOptions(options, configurationService, keybindingService), workbenchListOptions = _a[0], disposable = _a[1];
    var additionalScrollHeight = options.additionalScrollHeight;
    return {
        getAutomaticKeyboardNavigation: getAutomaticKeyboardNavigation,
        disposable: disposable,
        options: __assign({ keyboardSupport: false, styleController: new DefaultStyleController(getSharedListStyleSheet()) }, computeStyles(themeService.getTheme(), defaultListStyles), workbenchListOptions, { indent: configurationService.getValue(treeIndentKey), renderIndentGuides: configurationService.getValue(treeRenderIndentGuidesKey), automaticKeyboardNavigation: getAutomaticKeyboardNavigation(), simpleKeyboardNavigation: keyboardNavigation === 'simple', filterOnType: keyboardNavigation === 'filter', horizontalScrolling: horizontalScrolling,
            openOnSingleClick: openOnSingleClick, keyboardNavigationEventFilter: createKeyboardNavigationEventFilter(container, keybindingService), additionalScrollHeight: additionalScrollHeight })
    };
}
var WorkbenchTreeInternals = /** @class */ (function () {
    function WorkbenchTreeInternals(tree, options, getAutomaticKeyboardNavigation, contextKeyService, listService, themeService, configurationService, accessibilityService) {
        var _this = this;
        this.disposables = [];
        this.contextKeyService = createScopedContextKeyService(contextKeyService, tree);
        var listSupportsMultiSelect = WorkbenchListSupportsMultiSelectContextKey.bindTo(this.contextKeyService);
        listSupportsMultiSelect.set(!(options.multipleSelectionSupport === false));
        this.hasSelectionOrFocus = WorkbenchListHasSelectionOrFocus.bindTo(this.contextKeyService);
        this.hasDoubleSelection = WorkbenchListDoubleSelection.bindTo(this.contextKeyService);
        this.hasMultiSelection = WorkbenchListMultiSelection.bindTo(this.contextKeyService);
        this._useAltAsMultipleSelectionModifier = useAltAsMultipleSelectionModifier(configurationService);
        var interestingContextKeys = new Set();
        interestingContextKeys.add(WorkbenchListAutomaticKeyboardNavigationKey);
        var updateKeyboardNavigation = function () {
            var accessibilityOn = accessibilityService.getAccessibilitySupport() === 2 /* Enabled */;
            var keyboardNavigation = accessibilityOn ? 'simple' : configurationService.getValue(keyboardNavigationSettingKey);
            tree.updateOptions({
                simpleKeyboardNavigation: keyboardNavigation === 'simple',
                filterOnType: keyboardNavigation === 'filter'
            });
        };
        this.disposables.push(this.contextKeyService, listService.register(tree), attachListStyler(tree, themeService), tree.onDidChangeSelection(function () {
            var selection = tree.getSelection();
            var focus = tree.getFocus();
            _this.hasSelectionOrFocus.set(selection.length > 0 || focus.length > 0);
            _this.hasMultiSelection.set(selection.length > 1);
            _this.hasDoubleSelection.set(selection.length === 2);
        }), tree.onDidChangeFocus(function () {
            var selection = tree.getSelection();
            var focus = tree.getFocus();
            _this.hasSelectionOrFocus.set(selection.length > 0 || focus.length > 0);
        }), configurationService.onDidChangeConfiguration(function (e) {
            if (e.affectsConfiguration(openModeSettingKey)) {
                tree.updateOptions({ openOnSingleClick: useSingleClickToOpen(configurationService) });
            }
            if (e.affectsConfiguration(multiSelectModifierSettingKey)) {
                _this._useAltAsMultipleSelectionModifier = useAltAsMultipleSelectionModifier(configurationService);
            }
            if (e.affectsConfiguration(treeIndentKey)) {
                var indent = configurationService.getValue(treeIndentKey);
                tree.updateOptions({ indent: indent });
            }
            if (e.affectsConfiguration(treeRenderIndentGuidesKey)) {
                var renderIndentGuides = configurationService.getValue(treeRenderIndentGuidesKey);
                tree.updateOptions({ renderIndentGuides: renderIndentGuides });
            }
            if (e.affectsConfiguration(keyboardNavigationSettingKey)) {
                updateKeyboardNavigation();
            }
            if (e.affectsConfiguration(automaticKeyboardNavigationSettingKey)) {
                tree.updateOptions({ automaticKeyboardNavigation: getAutomaticKeyboardNavigation() });
            }
        }), this.contextKeyService.onDidChangeContext(function (e) {
            if (e.affectsSome(interestingContextKeys)) {
                tree.updateOptions({ automaticKeyboardNavigation: getAutomaticKeyboardNavigation() });
            }
        }), accessibilityService.onDidChangeAccessibilitySupport(function () { return updateKeyboardNavigation(); }));
    }
    WorkbenchTreeInternals.prototype.dispose = function () {
        this.disposables = dispose(this.disposables);
    };
    WorkbenchTreeInternals = __decorate([
        __param(3, IContextKeyService),
        __param(4, IListService),
        __param(5, IThemeService),
        __param(6, IConfigurationService),
        __param(7, IAccessibilityService)
    ], WorkbenchTreeInternals);
    return WorkbenchTreeInternals;
}());
var configurationRegistry = Registry.as(ConfigurationExtensions.Configuration);
configurationRegistry.registerConfiguration({
    'id': 'workbench',
    'order': 7,
    'title': localize('workbenchConfigurationTitle', "Workbench"),
    'type': 'object',
    'properties': (_a = {},
        _a[multiSelectModifierSettingKey] = {
            'type': 'string',
            'enum': ['ctrlCmd', 'alt'],
            'enumDescriptions': [
                localize('multiSelectModifier.ctrlCmd', "Maps to `Control` on Windows and Linux and to `Command` on macOS."),
                localize('multiSelectModifier.alt', "Maps to `Alt` on Windows and Linux and to `Option` on macOS.")
            ],
            'default': 'ctrlCmd',
            'description': localize({
                key: 'multiSelectModifier',
                comment: [
                    '- `ctrlCmd` refers to a value the setting can take and should not be localized.',
                    '- `Control` and `Command` refer to the modifier keys Ctrl or Cmd on the keyboard and can be localized.'
                ]
            }, "The modifier to be used to add an item in trees and lists to a multi-selection with the mouse (for example in the explorer, open editors and scm view). The 'Open to Side' mouse gestures - if supported - will adapt such that they do not conflict with the multiselect modifier.")
        },
        _a[openModeSettingKey] = {
            'type': 'string',
            'enum': ['singleClick', 'doubleClick'],
            'default': 'singleClick',
            'description': localize({
                key: 'openModeModifier',
                comment: ['`singleClick` and `doubleClick` refers to a value the setting can take and should not be localized.']
            }, "Controls how to open items in trees and lists using the mouse (if supported). For parents with children in trees, this setting will control if a single click expands the parent or a double click. Note that some trees and lists might choose to ignore this setting if it is not applicable. ")
        },
        _a[horizontalScrollingKey] = {
            'type': 'boolean',
            'default': false,
            'description': localize('horizontalScrolling setting', "Controls whether lists and trees support horizontal scrolling in the workbench.")
        },
        _a['workbench.tree.horizontalScrolling'] = {
            'type': 'boolean',
            'default': false,
            'description': localize('tree horizontalScrolling setting', "Controls whether trees support horizontal scrolling in the workbench."),
            'deprecationMessage': localize('deprecated', "This setting is deprecated, please use '{0}' instead.", horizontalScrollingKey)
        },
        _a[treeIndentKey] = {
            'type': 'number',
            'default': 8,
            minimum: 0,
            maximum: 40,
            'description': localize('tree indent setting', "Controls tree indentation in pixels.")
        },
        _a[treeRenderIndentGuidesKey] = {
            type: 'string',
            enum: ['none', 'onHover', 'always'],
            default: 'onHover',
            description: localize('render tree indent guides', "Controls whether the tree should render indent guides.")
        },
        _a[keyboardNavigationSettingKey] = {
            'type': 'string',
            'enum': ['simple', 'highlight', 'filter'],
            'enumDescriptions': [
                localize('keyboardNavigationSettingKey.simple', "Simple keyboard navigation focuses elements which match the keyboard input. Matching is done only on prefixes."),
                localize('keyboardNavigationSettingKey.highlight', "Highlight keyboard navigation highlights elements which match the keyboard input. Further up and down navigation will traverse only the highlighted elements."),
                localize('keyboardNavigationSettingKey.filter', "Filter keyboard navigation will filter out and hide all the elements which do not match the keyboard input.")
            ],
            'default': 'highlight',
            'description': localize('keyboardNavigationSettingKey', "Controls the keyboard navigation style for lists and trees in the workbench. Can be simple, highlight and filter.")
        },
        _a[automaticKeyboardNavigationSettingKey] = {
            'type': 'boolean',
            'default': true,
            markdownDescription: localize('automatic keyboard navigation setting', "Controls whether keyboard navigation in lists and trees is automatically triggered simply by typing. If set to `false`, keyboard navigation is only triggered when executing the `list.toggleKeyboardNavigation` command, for which you can assign a keyboard shortcut.")
        },
        _a)
});
