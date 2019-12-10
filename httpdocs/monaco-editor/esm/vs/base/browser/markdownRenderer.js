/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as DOM from './dom.js';
import { createElement } from './formattedTextRenderer.js';
import { onUnexpectedError } from '../common/errors.js';
import { parseHrefAndDimensions, removeMarkdownEscapes } from '../common/htmlContent.js';
import { defaultGenerator } from '../common/idGenerator.js';
import * as marked from '../common/marked/marked.js';
import { insane } from '../common/insane/insane.js';
import { parse } from '../common/marshalling.js';
import { cloneAndChange } from '../common/objects.js';
import { escape } from '../common/strings.js';
import { URI } from '../common/uri.js';
/**
 * Create html nodes for the given content element.
 */
export function renderMarkdown(markdown, options) {
    if (options === void 0) { options = {}; }
    var element = createElement(options);
    var _uriMassage = function (part) {
        var data;
        try {
            data = parse(decodeURIComponent(part));
        }
        catch (e) {
            // ignore
        }
        if (!data) {
            return part;
        }
        data = cloneAndChange(data, function (value) {
            if (markdown.uris && markdown.uris[value]) {
                return URI.revive(markdown.uris[value]);
            }
            else {
                return undefined;
            }
        });
        return encodeURIComponent(JSON.stringify(data));
    };
    var _href = function (href, isDomUri) {
        var data = markdown.uris && markdown.uris[href];
        if (!data) {
            return href;
        }
        var uri = URI.revive(data);
        if (isDomUri) {
            uri = DOM.asDomUri(uri);
        }
        if (uri.query) {
            uri = uri.with({ query: _uriMassage(uri.query) });
        }
        if (data) {
            href = uri.toString(true);
        }
        return href;
    };
    // signal to code-block render that the
    // element has been created
    var signalInnerHTML;
    var withInnerHTML = new Promise(function (c) { return signalInnerHTML = c; });
    var renderer = new marked.Renderer();
    renderer.image = function (href, title, text) {
        var _a;
        var dimensions = [];
        var attributes = [];
        if (href) {
            (_a = parseHrefAndDimensions(href), href = _a.href, dimensions = _a.dimensions);
            href = _href(href, true);
            attributes.push("src=\"" + href + "\"");
        }
        if (text) {
            attributes.push("alt=\"" + text + "\"");
        }
        if (title) {
            attributes.push("title=\"" + title + "\"");
        }
        if (dimensions.length) {
            attributes = attributes.concat(dimensions);
        }
        return '<img ' + attributes.join(' ') + '>';
    };
    renderer.link = function (href, title, text) {
        // Remove markdown escapes. Workaround for https://github.com/chjj/marked/issues/829
        if (href === text) { // raw link case
            text = removeMarkdownEscapes(text);
        }
        href = _href(href, false);
        title = removeMarkdownEscapes(title);
        href = removeMarkdownEscapes(href);
        if (!href
            || href.match(/^data:|javascript:/i)
            || (href.match(/^command:/i) && !markdown.isTrusted)
            || href.match(/^command:(\/\/\/)?_workbench\.downloadResource/i)) {
            // drop the link
            return text;
        }
        else {
            // HTML Encode href
            href = href.replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;');
            return "<a href=\"#\" data-href=\"" + href + "\" title=\"" + (title || href) + "\">" + text + "</a>";
        }
    };
    renderer.paragraph = function (text) {
        return "<p>" + text + "</p>";
    };
    if (options.codeBlockRenderer) {
        renderer.code = function (code, lang) {
            var value = options.codeBlockRenderer(lang, code);
            // when code-block rendering is async we return sync
            // but update the node with the real result later.
            var id = defaultGenerator.nextId();
            var promise = Promise.all([value, withInnerHTML]).then(function (values) {
                var strValue = values[0];
                var span = element.querySelector("div[data-code=\"" + id + "\"]");
                if (span) {
                    span.innerHTML = strValue;
                }
            }).catch(function (err) {
                // ignore
            });
            if (options.codeBlockRenderCallback) {
                promise.then(options.codeBlockRenderCallback);
            }
            return "<div class=\"code\" data-code=\"" + id + "\">" + escape(code) + "</div>";
        };
    }
    var actionHandler = options.actionHandler;
    if (actionHandler) {
        actionHandler.disposeables.add(DOM.addStandardDisposableListener(element, 'click', function (event) {
            var target = event.target;
            if (target.tagName !== 'A') {
                target = target.parentElement;
                if (!target || target.tagName !== 'A') {
                    return;
                }
            }
            try {
                var href = target.dataset['href'];
                if (href) {
                    actionHandler.callback(href, event);
                }
            }
            catch (err) {
                onUnexpectedError(err);
            }
            finally {
                event.preventDefault();
            }
        }));
    }
    var markedOptions = {
        sanitize: true,
        renderer: renderer
    };
    var allowedSchemes = ['http', 'https', 'mailto', 'data'];
    if (markdown.isTrusted) {
        allowedSchemes.push('command');
    }
    var renderedMarkdown = marked.parse(markdown.value, markedOptions);
    element.innerHTML = insane(renderedMarkdown, {
        allowedSchemes: allowedSchemes,
        allowedAttributes: {
            'a': ['href', 'name', 'target', 'data-href'],
            'iframe': ['allowfullscreen', 'frameborder', 'src'],
            'img': ['src', 'title', 'alt', 'width', 'height'],
            'div': ['class', 'data-code']
        }
    });
    signalInnerHTML();
    return element;
}
