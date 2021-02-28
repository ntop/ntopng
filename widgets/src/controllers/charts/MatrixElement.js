/**
 * Repository: kurkle/chartjs-chart-matrix
 * License: MIT
 * URL: https://github.com/kurkle/chartjs-chart-matrix
 */

import {Element} from 'chart.js';
import {isObject} from 'chart.js/helpers';

/**
 * Helper function to get the bounds of the rect
 * @param {Matrix} rect the rect
 * @param {boolean} [useFinalPosition]
 * @return {object} bounds of the rect
 * @private
 */
function getBounds(rect, useFinalPosition) {
	const {x, y, width, height} = rect.getProps(['x', 'y', 'width', 'height'], useFinalPosition);
	return {left: x, top: y, right: x + width, bottom: y + height};
}

function limit(value, min, max) {
	return Math.max(Math.min(value, max), min);
}

function parseBorderWidth(rect, maxW, maxH) {
	const value = rect.options.borderWidth;
	let t, r, b, l;

	if (isObject(value)) {
		t = +value.top || 0;
		r = +value.right || 0;
		b = +value.bottom || 0;
		l = +value.left || 0;
	} else {
		t = r = b = l = +value || 0;
	}

	return {
		t: limit(t, 0, maxH),
		r: limit(r, 0, maxW),
		b: limit(b, 0, maxH),
		l: limit(l, 0, maxW)
	};
}

function boundingRects(rect) {
	const bounds = getBounds(rect);
	const width = bounds.right - bounds.left;
	const height = bounds.bottom - bounds.top;
	const border = parseBorderWidth(rect, width / 2, height / 2);

	return {
		outer: {
			x: bounds.left,
			y: bounds.top,
			w: width,
			h: height
		},
		inner: {
			x: bounds.left + border.l,
			y: bounds.top + border.t,
			w: width - border.l - border.r,
			h: height - border.t - border.b
		}
	};
}

function inRange(rect, x, y, useFinalPosition) {
	const skipX = x === null;
	const skipY = y === null;
	const bounds = !rect || (skipX && skipY) ? false : getBounds(rect, useFinalPosition);

	return bounds
		&& (skipX || x >= bounds.left && x <= bounds.right)
		&& (skipY || y >= bounds.top && y <= bounds.bottom);
}

export class MatrixElement extends Element {
	constructor(cfg) {
		super();

		this.options = undefined;
		this.width = undefined;
		this.height = undefined;

		if (cfg) {
			Object.assign(this, cfg);
		}
	}

	draw(ctx) {
		const options = this.options;
		const {inner, outer} = boundingRects(this);

		ctx.save();

		if (outer.w !== inner.w || outer.h !== inner.h) {
			ctx.beginPath();
			ctx.rect(outer.x, outer.y, outer.w, outer.h);
			ctx.clip();
			ctx.rect(inner.x, inner.y, inner.w, inner.h);
			ctx.fillStyle = options.backgroundColor;
			ctx.fill();
			ctx.fillStyle = options.borderColor;
			ctx.fill('evenodd');
		} else {
			ctx.fillStyle = options.backgroundColor;
			ctx.fillRect(inner.x, inner.y, inner.w, inner.h);
		}

		ctx.restore();
	}

	inRange(mouseX, mouseY, useFinalPosition) {
		return inRange(this, mouseX, mouseY, useFinalPosition);
	}

	inXRange(mouseX, useFinalPosition) {
		return inRange(this, mouseX, null, useFinalPosition);
	}

	inYRange(mouseY, useFinalPosition) {
		return inRange(this, null, mouseY, useFinalPosition);
	}

	getCenterPoint(useFinalPosition) {
		const {x, y, width, height} = this.getProps(['x', 'y', 'width', 'height'], useFinalPosition);
		return {
			x: x + width / 2,
			y: y + height / 2
		};
	}

	tooltipPosition() {
		return this.getCenterPoint();
	}

	getRange(axis) {
		return axis === 'x' ? this.width / 2 : this.height / 2;
	}
}

MatrixElement.id = 'matrix';
MatrixElement.defaults = { width: 20, height: 20 };