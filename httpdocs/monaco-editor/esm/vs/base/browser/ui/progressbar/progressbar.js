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
import './progressbar.css';
import { Disposable } from '../../../common/lifecycle.js';
import { Color } from '../../../common/color.js';
import { mixin } from '../../../common/objects.js';
import { removeClasses, addClass, hasClass, hide, show } from '../../dom.js';
import { RunOnceScheduler } from '../../../common/async.js';
var css_done = 'done';
var css_active = 'active';
var css_infinite = 'infinite';
var css_discrete = 'discrete';
var css_progress_container = 'monaco-progress-container';
var css_progress_bit = 'progress-bit';
var defaultOpts = {
    progressBarBackground: Color.fromHex('#0E70C0')
};
/**
 * A progress bar with support for infinite or discrete progress.
 */
var ProgressBar = /** @class */ (function (_super) {
    __extends(ProgressBar, _super);
    function ProgressBar(container, options) {
        var _this = _super.call(this) || this;
        _this.options = options || Object.create(null);
        mixin(_this.options, defaultOpts, false);
        _this.workedVal = 0;
        _this.progressBarBackground = _this.options.progressBarBackground;
        _this._register(_this.showDelayedScheduler = new RunOnceScheduler(function () { return show(_this.element); }, 0));
        _this.create(container);
        return _this;
    }
    ProgressBar.prototype.create = function (container) {
        this.element = document.createElement('div');
        addClass(this.element, css_progress_container);
        container.appendChild(this.element);
        this.bit = document.createElement('div');
        addClass(this.bit, css_progress_bit);
        this.element.appendChild(this.bit);
        this.applyStyles();
    };
    ProgressBar.prototype.off = function () {
        this.bit.style.width = 'inherit';
        this.bit.style.opacity = '1';
        removeClasses(this.element, css_active, css_infinite, css_discrete);
        this.workedVal = 0;
        this.totalWork = undefined;
    };
    /**
     * Stops the progressbar from showing any progress instantly without fading out.
     */
    ProgressBar.prototype.stop = function () {
        return this.doDone(false);
    };
    ProgressBar.prototype.doDone = function (delayed) {
        var _this = this;
        addClass(this.element, css_done);
        // let it grow to 100% width and hide afterwards
        if (!hasClass(this.element, css_infinite)) {
            this.bit.style.width = 'inherit';
            if (delayed) {
                setTimeout(function () { return _this.off(); }, 200);
            }
            else {
                this.off();
            }
        }
        // let it fade out and hide afterwards
        else {
            this.bit.style.opacity = '0';
            if (delayed) {
                setTimeout(function () { return _this.off(); }, 200);
            }
            else {
                this.off();
            }
        }
        return this;
    };
    ProgressBar.prototype.hide = function () {
        hide(this.element);
        this.showDelayedScheduler.cancel();
    };
    ProgressBar.prototype.style = function (styles) {
        this.progressBarBackground = styles.progressBarBackground;
        this.applyStyles();
    };
    ProgressBar.prototype.applyStyles = function () {
        if (this.bit) {
            var background = this.progressBarBackground ? this.progressBarBackground.toString() : null;
            this.bit.style.backgroundColor = background;
        }
    };
    return ProgressBar;
}(Disposable));
export { ProgressBar };
