/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as platform from '../../registry/common/platform.js';
import { Color, RGBA } from '../../../base/common/color.js';
import { Emitter } from '../../../base/common/event.js';
import * as nls from '../../../nls.js';
import { Extensions as JSONExtensions } from '../../jsonschemas/common/jsonContributionRegistry.js';
import { RunOnceScheduler } from '../../../base/common/async.js';
// color registry
export var Extensions = {
    ColorContribution: 'base.contributions.colors'
};
var ColorRegistry = /** @class */ (function () {
    function ColorRegistry() {
        this._onDidChangeSchema = new Emitter();
        this.onDidChangeSchema = this._onDidChangeSchema.event;
        this.colorSchema = { type: 'object', properties: {} };
        this.colorReferenceSchema = { type: 'string', enum: [], enumDescriptions: [] };
        this.colorsById = {};
    }
    ColorRegistry.prototype.registerColor = function (id, defaults, description, needsTransparency, deprecationMessage) {
        if (needsTransparency === void 0) { needsTransparency = false; }
        var colorContribution = { id: id, description: description, defaults: defaults, needsTransparency: needsTransparency, deprecationMessage: deprecationMessage };
        this.colorsById[id] = colorContribution;
        var propertySchema = { type: 'string', description: description, format: 'color-hex', default: '#ff0000' };
        if (deprecationMessage) {
            propertySchema.deprecationMessage = deprecationMessage;
        }
        this.colorSchema.properties[id] = propertySchema;
        this.colorReferenceSchema.enum.push(id);
        this.colorReferenceSchema.enumDescriptions.push(description);
        this._onDidChangeSchema.fire();
        return id;
    };
    ColorRegistry.prototype.resolveDefaultColor = function (id, theme) {
        var colorDesc = this.colorsById[id];
        if (colorDesc && colorDesc.defaults) {
            var colorValue = colorDesc.defaults[theme.type];
            return resolveColorValue(colorValue, theme);
        }
        return undefined;
    };
    ColorRegistry.prototype.getColorSchema = function () {
        return this.colorSchema;
    };
    ColorRegistry.prototype.toString = function () {
        var _this = this;
        var sorter = function (a, b) {
            var cat1 = a.indexOf('.') === -1 ? 0 : 1;
            var cat2 = b.indexOf('.') === -1 ? 0 : 1;
            if (cat1 !== cat2) {
                return cat1 - cat2;
            }
            return a.localeCompare(b);
        };
        return Object.keys(this.colorsById).sort(sorter).map(function (k) { return "- `" + k + "`: " + _this.colorsById[k].description; }).join('\n');
    };
    return ColorRegistry;
}());
var colorRegistry = new ColorRegistry();
platform.Registry.add(Extensions.ColorContribution, colorRegistry);
export function registerColor(id, defaults, description, needsTransparency, deprecationMessage) {
    return colorRegistry.registerColor(id, defaults, description, needsTransparency, deprecationMessage);
}
// ----- base colors
export var foreground = registerColor('foreground', { dark: '#CCCCCC', light: '#616161', hc: '#FFFFFF' }, nls.localize('foreground', "Overall foreground color. This color is only used if not overridden by a component."));
export var errorForeground = registerColor('errorForeground', { dark: '#F48771', light: '#A1260D', hc: '#F48771' }, nls.localize('errorForeground', "Overall foreground color for error messages. This color is only used if not overridden by a component."));
export var focusBorder = registerColor('focusBorder', { dark: Color.fromHex('#0E639C').transparent(0.8), light: Color.fromHex('#007ACC').transparent(0.4), hc: '#F38518' }, nls.localize('focusBorder', "Overall border color for focused elements. This color is only used if not overridden by a component."));
export var contrastBorder = registerColor('contrastBorder', { light: null, dark: null, hc: '#6FC3DF' }, nls.localize('contrastBorder', "An extra border around elements to separate them from others for greater contrast."));
export var activeContrastBorder = registerColor('contrastActiveBorder', { light: null, dark: null, hc: focusBorder }, nls.localize('activeContrastBorder', "An extra border around active elements to separate them from others for greater contrast."));
export var textLinkForeground = registerColor('textLink.foreground', { light: '#006AB1', dark: '#3794FF', hc: '#3794FF' }, nls.localize('textLinkForeground', "Foreground color for links in text."));
export var textCodeBlockBackground = registerColor('textCodeBlock.background', { light: '#dcdcdc66', dark: '#0a0a0a66', hc: Color.black }, nls.localize('textCodeBlockBackground', "Background color for code blocks in text."));
// ----- widgets
export var widgetShadow = registerColor('widget.shadow', { dark: '#000000', light: '#A8A8A8', hc: null }, nls.localize('widgetShadow', 'Shadow color of widgets such as find/replace inside the editor.'));
export var inputBackground = registerColor('input.background', { dark: '#3C3C3C', light: Color.white, hc: Color.black }, nls.localize('inputBoxBackground', "Input box background."));
export var inputForeground = registerColor('input.foreground', { dark: foreground, light: foreground, hc: foreground }, nls.localize('inputBoxForeground', "Input box foreground."));
export var inputBorder = registerColor('input.border', { dark: null, light: null, hc: contrastBorder }, nls.localize('inputBoxBorder', "Input box border."));
export var inputActiveOptionBorder = registerColor('inputOption.activeBorder', { dark: '#007ACC00', light: '#007ACC00', hc: contrastBorder }, nls.localize('inputBoxActiveOptionBorder', "Border color of activated options in input fields."));
export var inputActiveOptionBackground = registerColor('inputOption.activeBackground', { dark: transparent(focusBorder, 0.5), light: transparent(focusBorder, 0.3), hc: null }, nls.localize('inputOption.activeBackground', "Background color of activated options in input fields."));
export var inputValidationInfoBackground = registerColor('inputValidation.infoBackground', { dark: '#063B49', light: '#D6ECF2', hc: Color.black }, nls.localize('inputValidationInfoBackground', "Input validation background color for information severity."));
export var inputValidationInfoForeground = registerColor('inputValidation.infoForeground', { dark: null, light: null, hc: null }, nls.localize('inputValidationInfoForeground', "Input validation foreground color for information severity."));
export var inputValidationInfoBorder = registerColor('inputValidation.infoBorder', { dark: '#007acc', light: '#007acc', hc: contrastBorder }, nls.localize('inputValidationInfoBorder', "Input validation border color for information severity."));
export var inputValidationWarningBackground = registerColor('inputValidation.warningBackground', { dark: '#352A05', light: '#F6F5D2', hc: Color.black }, nls.localize('inputValidationWarningBackground', "Input validation background color for warning severity."));
export var inputValidationWarningForeground = registerColor('inputValidation.warningForeground', { dark: null, light: null, hc: null }, nls.localize('inputValidationWarningForeground', "Input validation foreground color for warning severity."));
export var inputValidationWarningBorder = registerColor('inputValidation.warningBorder', { dark: '#B89500', light: '#B89500', hc: contrastBorder }, nls.localize('inputValidationWarningBorder', "Input validation border color for warning severity."));
export var inputValidationErrorBackground = registerColor('inputValidation.errorBackground', { dark: '#5A1D1D', light: '#F2DEDE', hc: Color.black }, nls.localize('inputValidationErrorBackground', "Input validation background color for error severity."));
export var inputValidationErrorForeground = registerColor('inputValidation.errorForeground', { dark: null, light: null, hc: null }, nls.localize('inputValidationErrorForeground', "Input validation foreground color for error severity."));
export var inputValidationErrorBorder = registerColor('inputValidation.errorBorder', { dark: '#BE1100', light: '#BE1100', hc: contrastBorder }, nls.localize('inputValidationErrorBorder', "Input validation border color for error severity."));
export var selectBackground = registerColor('dropdown.background', { dark: '#3C3C3C', light: Color.white, hc: Color.black }, nls.localize('dropdownBackground', "Dropdown background."));
export var selectForeground = registerColor('dropdown.foreground', { dark: '#F0F0F0', light: null, hc: Color.white }, nls.localize('dropdownForeground', "Dropdown foreground."));
export var listFocusBackground = registerColor('list.focusBackground', { dark: '#062F4A', light: '#D6EBFF', hc: null }, nls.localize('listFocusBackground', "List/Tree background color for the focused item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not."));
export var listFocusForeground = registerColor('list.focusForeground', { dark: null, light: null, hc: null }, nls.localize('listFocusForeground', "List/Tree foreground color for the focused item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not."));
export var listActiveSelectionBackground = registerColor('list.activeSelectionBackground', { dark: '#094771', light: '#0074E8', hc: null }, nls.localize('listActiveSelectionBackground', "List/Tree background color for the selected item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not."));
export var listActiveSelectionForeground = registerColor('list.activeSelectionForeground', { dark: Color.white, light: Color.white, hc: null }, nls.localize('listActiveSelectionForeground', "List/Tree foreground color for the selected item when the list/tree is active. An active list/tree has keyboard focus, an inactive does not."));
export var listInactiveSelectionBackground = registerColor('list.inactiveSelectionBackground', { dark: '#37373D', light: '#E4E6F1', hc: null }, nls.localize('listInactiveSelectionBackground', "List/Tree background color for the selected item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not."));
export var listInactiveSelectionForeground = registerColor('list.inactiveSelectionForeground', { dark: null, light: null, hc: null }, nls.localize('listInactiveSelectionForeground', "List/Tree foreground color for the selected item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not."));
export var listInactiveFocusBackground = registerColor('list.inactiveFocusBackground', { dark: null, light: null, hc: null }, nls.localize('listInactiveFocusBackground', "List/Tree background color for the focused item when the list/tree is inactive. An active list/tree has keyboard focus, an inactive does not."));
export var listHoverBackground = registerColor('list.hoverBackground', { dark: '#2A2D2E', light: '#F0F0F0', hc: null }, nls.localize('listHoverBackground', "List/Tree background when hovering over items using the mouse."));
export var listHoverForeground = registerColor('list.hoverForeground', { dark: null, light: null, hc: null }, nls.localize('listHoverForeground', "List/Tree foreground when hovering over items using the mouse."));
export var listDropBackground = registerColor('list.dropBackground', { dark: listFocusBackground, light: listFocusBackground, hc: null }, nls.localize('listDropBackground', "List/Tree drag and drop background when moving items around using the mouse."));
export var listHighlightForeground = registerColor('list.highlightForeground', { dark: '#0097fb', light: '#0066BF', hc: focusBorder }, nls.localize('highlight', 'List/Tree foreground color of the match highlights when searching inside the list/tree.'));
export var listFilterWidgetBackground = registerColor('listFilterWidget.background', { light: '#efc1ad', dark: '#653723', hc: Color.black }, nls.localize('listFilterWidgetBackground', 'Background color of the type filter widget in lists and trees.'));
export var listFilterWidgetOutline = registerColor('listFilterWidget.outline', { dark: Color.transparent, light: Color.transparent, hc: '#f38518' }, nls.localize('listFilterWidgetOutline', 'Outline color of the type filter widget in lists and trees.'));
export var listFilterWidgetNoMatchesOutline = registerColor('listFilterWidget.noMatchesOutline', { dark: '#BE1100', light: '#BE1100', hc: contrastBorder }, nls.localize('listFilterWidgetNoMatchesOutline', 'Outline color of the type filter widget in lists and trees, when there are no matches.'));
export var treeIndentGuidesStroke = registerColor('tree.indentGuidesStroke', { dark: '#585858', light: '#a9a9a9', hc: '#a9a9a9' }, nls.localize('treeIndentGuidesStroke', "Tree stroke color for the indentation guides."));
export var pickerGroupForeground = registerColor('pickerGroup.foreground', { dark: '#3794FF', light: '#0066BF', hc: Color.white }, nls.localize('pickerGroupForeground', "Quick picker color for grouping labels."));
export var pickerGroupBorder = registerColor('pickerGroup.border', { dark: '#3F3F46', light: '#CCCEDB', hc: Color.white }, nls.localize('pickerGroupBorder', "Quick picker color for grouping borders."));
export var badgeBackground = registerColor('badge.background', { dark: '#4D4D4D', light: '#C4C4C4', hc: Color.black }, nls.localize('badgeBackground', "Badge background color. Badges are small information labels, e.g. for search results count."));
export var badgeForeground = registerColor('badge.foreground', { dark: Color.white, light: '#333', hc: Color.white }, nls.localize('badgeForeground', "Badge foreground color. Badges are small information labels, e.g. for search results count."));
export var scrollbarShadow = registerColor('scrollbar.shadow', { dark: '#000000', light: '#DDDDDD', hc: null }, nls.localize('scrollbarShadow', "Scrollbar shadow to indicate that the view is scrolled."));
export var scrollbarSliderBackground = registerColor('scrollbarSlider.background', { dark: Color.fromHex('#797979').transparent(0.4), light: Color.fromHex('#646464').transparent(0.4), hc: transparent(contrastBorder, 0.6) }, nls.localize('scrollbarSliderBackground', "Scrollbar slider background color."));
export var scrollbarSliderHoverBackground = registerColor('scrollbarSlider.hoverBackground', { dark: Color.fromHex('#646464').transparent(0.7), light: Color.fromHex('#646464').transparent(0.7), hc: transparent(contrastBorder, 0.8) }, nls.localize('scrollbarSliderHoverBackground', "Scrollbar slider background color when hovering."));
export var scrollbarSliderActiveBackground = registerColor('scrollbarSlider.activeBackground', { dark: Color.fromHex('#BFBFBF').transparent(0.4), light: Color.fromHex('#000000').transparent(0.6), hc: contrastBorder }, nls.localize('scrollbarSliderActiveBackground', "Scrollbar slider background color when clicked on."));
export var progressBarBackground = registerColor('progressBar.background', { dark: Color.fromHex('#0E70C0'), light: Color.fromHex('#0E70C0'), hc: contrastBorder }, nls.localize('progressBarBackground', "Background color of the progress bar that can show for long running operations."));
export var menuBorder = registerColor('menu.border', { dark: null, light: null, hc: contrastBorder }, nls.localize('menuBorder', "Border color of menus."));
export var menuForeground = registerColor('menu.foreground', { dark: selectForeground, light: foreground, hc: selectForeground }, nls.localize('menuForeground', "Foreground color of menu items."));
export var menuBackground = registerColor('menu.background', { dark: selectBackground, light: selectBackground, hc: selectBackground }, nls.localize('menuBackground', "Background color of menu items."));
export var menuSelectionForeground = registerColor('menu.selectionForeground', { dark: listActiveSelectionForeground, light: listActiveSelectionForeground, hc: listActiveSelectionForeground }, nls.localize('menuSelectionForeground', "Foreground color of the selected menu item in menus."));
export var menuSelectionBackground = registerColor('menu.selectionBackground', { dark: listActiveSelectionBackground, light: listActiveSelectionBackground, hc: listActiveSelectionBackground }, nls.localize('menuSelectionBackground', "Background color of the selected menu item in menus."));
export var menuSelectionBorder = registerColor('menu.selectionBorder', { dark: null, light: null, hc: activeContrastBorder }, nls.localize('menuSelectionBorder', "Border color of the selected menu item in menus."));
export var menuSeparatorBackground = registerColor('menu.separatorBackground', { dark: '#BBBBBB', light: '#888888', hc: contrastBorder }, nls.localize('menuSeparatorBackground', "Color of a separator menu item in menus."));
export var editorErrorForeground = registerColor('editorError.foreground', { dark: '#F48771', light: '#E51400', hc: null }, nls.localize('editorError.foreground', 'Foreground color of error squigglies in the editor.'));
export var editorErrorBorder = registerColor('editorError.border', { dark: null, light: null, hc: Color.fromHex('#E47777').transparent(0.8) }, nls.localize('errorBorder', 'Border color of error boxes in the editor.'));
export var editorWarningForeground = registerColor('editorWarning.foreground', { dark: '#CCA700', light: '#E9A700', hc: null }, nls.localize('editorWarning.foreground', 'Foreground color of warning squigglies in the editor.'));
export var editorWarningBorder = registerColor('editorWarning.border', { dark: null, light: null, hc: Color.fromHex('#FFCC00').transparent(0.8) }, nls.localize('warningBorder', 'Border color of warning boxes in the editor.'));
export var editorInfoForeground = registerColor('editorInfo.foreground', { dark: '#75BEFF', light: '#75BEFF', hc: null }, nls.localize('editorInfo.foreground', 'Foreground color of info squigglies in the editor.'));
export var editorInfoBorder = registerColor('editorInfo.border', { dark: null, light: null, hc: Color.fromHex('#75BEFF').transparent(0.8) }, nls.localize('infoBorder', 'Border color of info boxes in the editor.'));
export var editorHintForeground = registerColor('editorHint.foreground', { dark: Color.fromHex('#eeeeee').transparent(0.7), light: '#6c6c6c', hc: null }, nls.localize('editorHint.foreground', 'Foreground color of hint squigglies in the editor.'));
export var editorHintBorder = registerColor('editorHint.border', { dark: null, light: null, hc: Color.fromHex('#eeeeee').transparent(0.8) }, nls.localize('hintBorder', 'Border color of hint boxes in the editor.'));
/**
 * Editor background color.
 * Because of bug https://monacotools.visualstudio.com/DefaultCollection/Monaco/_workitems/edit/13254
 * we are *not* using the color white (or #ffffff, rgba(255,255,255)) but something very close to white.
 */
export var editorBackground = registerColor('editor.background', { light: '#fffffe', dark: '#1E1E1E', hc: Color.black }, nls.localize('editorBackground', "Editor background color."));
/**
 * Editor foreground color.
 */
export var editorForeground = registerColor('editor.foreground', { light: '#333333', dark: '#BBBBBB', hc: Color.white }, nls.localize('editorForeground', "Editor default foreground color."));
/**
 * Editor widgets
 */
export var editorWidgetBackground = registerColor('editorWidget.background', { dark: '#252526', light: '#F3F3F3', hc: '#0C141F' }, nls.localize('editorWidgetBackground', 'Background color of editor widgets, such as find/replace.'));
export var editorWidgetForeground = registerColor('editorWidget.foreground', { dark: foreground, light: foreground, hc: foreground }, nls.localize('editorWidgetForeground', 'Foreground color of editor widgets, such as find/replace.'));
export var editorWidgetBorder = registerColor('editorWidget.border', { dark: '#454545', light: '#C8C8C8', hc: contrastBorder }, nls.localize('editorWidgetBorder', 'Border color of editor widgets. The color is only used if the widget chooses to have a border and if the color is not overridden by a widget.'));
export var editorWidgetResizeBorder = registerColor('editorWidget.resizeBorder', { light: null, dark: null, hc: null }, nls.localize('editorWidgetResizeBorder', "Border color of the resize bar of editor widgets. The color is only used if the widget chooses to have a resize border and if the color is not overridden by a widget."));
/**
 * Editor selection colors.
 */
export var editorSelectionBackground = registerColor('editor.selectionBackground', { light: '#ADD6FF', dark: '#264F78', hc: '#f3f518' }, nls.localize('editorSelectionBackground', "Color of the editor selection."));
export var editorSelectionForeground = registerColor('editor.selectionForeground', { light: null, dark: null, hc: '#000000' }, nls.localize('editorSelectionForeground', "Color of the selected text for high contrast."));
export var editorInactiveSelection = registerColor('editor.inactiveSelectionBackground', { light: transparent(editorSelectionBackground, 0.5), dark: transparent(editorSelectionBackground, 0.5), hc: transparent(editorSelectionBackground, 0.5) }, nls.localize('editorInactiveSelection', "Color of the selection in an inactive editor. The color must not be opaque so as not to hide underlying decorations."), true);
export var editorSelectionHighlight = registerColor('editor.selectionHighlightBackground', { light: lessProminent(editorSelectionBackground, editorBackground, 0.3, 0.6), dark: lessProminent(editorSelectionBackground, editorBackground, 0.3, 0.6), hc: null }, nls.localize('editorSelectionHighlight', 'Color for regions with the same content as the selection. The color must not be opaque so as not to hide underlying decorations.'), true);
export var editorSelectionHighlightBorder = registerColor('editor.selectionHighlightBorder', { light: null, dark: null, hc: activeContrastBorder }, nls.localize('editorSelectionHighlightBorder', "Border color for regions with the same content as the selection."));
/**
 * Editor find match colors.
 */
export var editorFindMatch = registerColor('editor.findMatchBackground', { light: '#A8AC94', dark: '#515C6A', hc: null }, nls.localize('editorFindMatch', "Color of the current search match."));
export var editorFindMatchHighlight = registerColor('editor.findMatchHighlightBackground', { light: '#EA5C0055', dark: '#EA5C0055', hc: null }, nls.localize('findMatchHighlight', "Color of the other search matches. The color must not be opaque so as not to hide underlying decorations."), true);
export var editorFindRangeHighlight = registerColor('editor.findRangeHighlightBackground', { dark: '#3a3d4166', light: '#b4b4b44d', hc: null }, nls.localize('findRangeHighlight', "Color of the range limiting the search. The color must not be opaque so as not to hide underlying decorations."), true);
export var editorFindMatchBorder = registerColor('editor.findMatchBorder', { light: null, dark: null, hc: activeContrastBorder }, nls.localize('editorFindMatchBorder', "Border color of the current search match."));
export var editorFindMatchHighlightBorder = registerColor('editor.findMatchHighlightBorder', { light: null, dark: null, hc: activeContrastBorder }, nls.localize('findMatchHighlightBorder', "Border color of the other search matches."));
export var editorFindRangeHighlightBorder = registerColor('editor.findRangeHighlightBorder', { dark: null, light: null, hc: transparent(activeContrastBorder, 0.4) }, nls.localize('findRangeHighlightBorder', "Border color of the range limiting the search. The color must not be opaque so as not to hide underlying decorations."), true);
/**
 * Editor hover
 */
export var editorHoverHighlight = registerColor('editor.hoverHighlightBackground', { light: '#ADD6FF26', dark: '#264f7840', hc: '#ADD6FF26' }, nls.localize('hoverHighlight', 'Highlight below the word for which a hover is shown. The color must not be opaque so as not to hide underlying decorations.'), true);
export var editorHoverBackground = registerColor('editorHoverWidget.background', { light: editorWidgetBackground, dark: editorWidgetBackground, hc: editorWidgetBackground }, nls.localize('hoverBackground', 'Background color of the editor hover.'));
export var editorHoverBorder = registerColor('editorHoverWidget.border', { light: editorWidgetBorder, dark: editorWidgetBorder, hc: editorWidgetBorder }, nls.localize('hoverBorder', 'Border color of the editor hover.'));
export var editorHoverStatusBarBackground = registerColor('editorHoverWidget.statusBarBackground', { dark: lighten(editorHoverBackground, 0.2), light: darken(editorHoverBackground, 0.05), hc: editorWidgetBackground }, nls.localize('statusBarBackground', "Background color of the editor hover status bar."));
/**
 * Editor link colors
 */
export var editorActiveLinkForeground = registerColor('editorLink.activeForeground', { dark: '#4E94CE', light: Color.blue, hc: Color.cyan }, nls.localize('activeLinkForeground', 'Color of active links.'));
/**
 * Diff Editor Colors
 */
export var defaultInsertColor = new Color(new RGBA(155, 185, 85, 0.2));
export var defaultRemoveColor = new Color(new RGBA(255, 0, 0, 0.2));
export var diffInserted = registerColor('diffEditor.insertedTextBackground', { dark: defaultInsertColor, light: defaultInsertColor, hc: null }, nls.localize('diffEditorInserted', 'Background color for text that got inserted. The color must not be opaque so as not to hide underlying decorations.'), true);
export var diffRemoved = registerColor('diffEditor.removedTextBackground', { dark: defaultRemoveColor, light: defaultRemoveColor, hc: null }, nls.localize('diffEditorRemoved', 'Background color for text that got removed. The color must not be opaque so as not to hide underlying decorations.'), true);
export var diffInsertedOutline = registerColor('diffEditor.insertedTextBorder', { dark: null, light: null, hc: '#33ff2eff' }, nls.localize('diffEditorInsertedOutline', 'Outline color for the text that got inserted.'));
export var diffRemovedOutline = registerColor('diffEditor.removedTextBorder', { dark: null, light: null, hc: '#FF008F' }, nls.localize('diffEditorRemovedOutline', 'Outline color for text that got removed.'));
export var diffBorder = registerColor('diffEditor.border', { dark: null, light: null, hc: contrastBorder }, nls.localize('diffEditorBorder', 'Border color between the two text editors.'));
/**
 * Snippet placeholder colors
 */
export var snippetTabstopHighlightBackground = registerColor('editor.snippetTabstopHighlightBackground', { dark: new Color(new RGBA(124, 124, 124, 0.3)), light: new Color(new RGBA(10, 50, 100, 0.2)), hc: new Color(new RGBA(124, 124, 124, 0.3)) }, nls.localize('snippetTabstopHighlightBackground', "Highlight background color of a snippet tabstop."));
export var snippetTabstopHighlightBorder = registerColor('editor.snippetTabstopHighlightBorder', { dark: null, light: null, hc: null }, nls.localize('snippetTabstopHighlightBorder', "Highlight border color of a snippet tabstop."));
export var snippetFinalTabstopHighlightBackground = registerColor('editor.snippetFinalTabstopHighlightBackground', { dark: null, light: null, hc: null }, nls.localize('snippetFinalTabstopHighlightBackground', "Highlight background color of the final tabstop of a snippet."));
export var snippetFinalTabstopHighlightBorder = registerColor('editor.snippetFinalTabstopHighlightBorder', { dark: '#525252', light: new Color(new RGBA(10, 50, 100, 0.5)), hc: '#525252' }, nls.localize('snippetFinalTabstopHighlightBorder', "Highlight border color of the final stabstop of a snippet."));
export var overviewRulerFindMatchForeground = registerColor('editorOverviewRuler.findMatchForeground', { dark: '#d186167e', light: '#d186167e', hc: '#AB5A00' }, nls.localize('overviewRulerFindMatchForeground', 'Overview ruler marker color for find matches. The color must not be opaque so as not to hide underlying decorations.'), true);
export var overviewRulerSelectionHighlightForeground = registerColor('editorOverviewRuler.selectionHighlightForeground', { dark: '#A0A0A0CC', light: '#A0A0A0CC', hc: '#A0A0A0CC' }, nls.localize('overviewRulerSelectionHighlightForeground', 'Overview ruler marker color for selection highlights. The color must not be opaque so as not to hide underlying decorations.'), true);
export var minimapFindMatch = registerColor('minimap.findMatchHighlight', { light: '#d18616', dark: '#d18616', hc: '#AB5A00' }, nls.localize('minimapFindMatchHighlight', 'Minimap marker color for find matches.'), true);
// ----- color functions
export function darken(colorValue, factor) {
    return function (theme) {
        var color = resolveColorValue(colorValue, theme);
        if (color) {
            return color.darken(factor);
        }
        return undefined;
    };
}
export function lighten(colorValue, factor) {
    return function (theme) {
        var color = resolveColorValue(colorValue, theme);
        if (color) {
            return color.lighten(factor);
        }
        return undefined;
    };
}
export function transparent(colorValue, factor) {
    return function (theme) {
        var color = resolveColorValue(colorValue, theme);
        if (color) {
            return color.transparent(factor);
        }
        return undefined;
    };
}
export function oneOf() {
    var colorValues = [];
    for (var _i = 0; _i < arguments.length; _i++) {
        colorValues[_i] = arguments[_i];
    }
    return function (theme) {
        for (var _i = 0, colorValues_1 = colorValues; _i < colorValues_1.length; _i++) {
            var colorValue = colorValues_1[_i];
            var color = resolveColorValue(colorValue, theme);
            if (color) {
                return color;
            }
        }
        return undefined;
    };
}
function lessProminent(colorValue, backgroundColorValue, factor, transparency) {
    return function (theme) {
        var from = resolveColorValue(colorValue, theme);
        if (from) {
            var backgroundColor = resolveColorValue(backgroundColorValue, theme);
            if (backgroundColor) {
                if (from.isDarkerThan(backgroundColor)) {
                    return Color.getLighterColor(from, backgroundColor, factor).transparent(transparency);
                }
                return Color.getDarkerColor(from, backgroundColor, factor).transparent(transparency);
            }
            return from.transparent(factor * transparency);
        }
        return undefined;
    };
}
// ----- implementation
/**
 * @param colorValue Resolve a color value in the context of a theme
 */
function resolveColorValue(colorValue, theme) {
    if (colorValue === null) {
        return undefined;
    }
    else if (typeof colorValue === 'string') {
        if (colorValue[0] === '#') {
            return Color.fromHex(colorValue);
        }
        return theme.getColor(colorValue);
    }
    else if (colorValue instanceof Color) {
        return colorValue;
    }
    else if (typeof colorValue === 'function') {
        return colorValue(theme);
    }
    return undefined;
}
export var workbenchColorsSchemaId = 'vscode://schemas/workbench-colors';
var schemaRegistry = platform.Registry.as(JSONExtensions.JSONContribution);
schemaRegistry.registerSchema(workbenchColorsSchemaId, colorRegistry.getColorSchema());
var delayer = new RunOnceScheduler(function () { return schemaRegistry.notifySchemaChanged(workbenchColorsSchemaId); }, 200);
colorRegistry.onDidChangeSchema(function () {
    if (!delayer.isScheduled()) {
        delayer.schedule();
    }
});
// setTimeout(_ => console.log(colorRegistry.toString()), 5000);
