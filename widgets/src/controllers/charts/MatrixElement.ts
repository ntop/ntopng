/**
 * Repository: kurkle/chartjs-chart-matrix
 * License: MIT
 * URL: https://github.com/kurkle/chartjs-chart-matrix
 */

import { BarOptions, BarProps, Element } from 'chart.js';
import { isObject } from 'chart.js/helpers';
import { MatrixOptions, MatrixProps } from '../../types/Matrix';

/**
 * Helper function to get the bounds of the rect
 * @param {MatrixElement} rect the rect
 * @param {boolean} [useFinalPosition]
 * @return {object} bounds of the rect
 * @private
 */
function getBounds(rect: MatrixElement, useFinalPosition: boolean) {
	const { x, y, width, height } = rect.getProps(['x', 'y', 'width', 'height'], useFinalPosition);
	return { left: x, top: y, right: x + width, bottom: y + height };
}

function limit(value: number, min: number, max: number) {
	return Math.max(Math.min(value, max), min);
}

function parseBorderWidth(rect: MatrixElement, maxW: number, maxH: number) {

	const value = rect.options.borderWidth;
	let top, right, bottom, left = +value || 0;

	if (isObject(value)) {
		top = +value.top || 0;
		right = +value.right || 0;
		bottom = +value.bottom || 0;
		left = +value.left || 0;
	} else {
		top = right = bottom = left = +value || 0;
	}

	return {
		t: limit(top, 0, maxH),
		r: limit(right, 0, maxW),
		b: limit(bottom, 0, maxH),
		l: limit(left, 0, maxW)
	};
}

function boundingRects(rect: MatrixElement) {
	const bounds = getBounds(rect, false);
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

function inRange(rect, x: number, y: number, useFinalPosition: boolean) {
	const skipX = x === null;
	const skipY = y === null;
	const bounds = !rect || (skipX && skipY) ? false : getBounds(rect, useFinalPosition);

	return bounds
		&& (skipX || x >= bounds.left && x <= bounds.right)
		&& (skipY || y >= bounds.top && y <= bounds.bottom);
}

export default class MatrixElement extends Element<MatrixProps, MatrixOptions> {

	static id: string = 'matrix';
	static defaults: { width: number, height: number } = { width: 20, height: 20 };

	private _width: number = MatrixElement.defaults.width;
	private _height: number = MatrixElement.defaults.height;

	constructor(configuration: any) {
		super();
		if (configuration) {
			Object.assign(this, configuration);
		}
	}

	public draw(ctx: CanvasRenderingContext2D): void {
		const options = this.options;
		const { inner, outer } = boundingRects(this);

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

	public inRange(mouseX, mouseY, useFinalPosition) {
		return inRange(this, mouseX, mouseY, useFinalPosition);
	}

	public inXRange(mouseX, useFinalPosition) {
		return inRange(this, mouseX, null, useFinalPosition);
	}

	public inYRange(mouseY, useFinalPosition) {
		return inRange(this, null, mouseY, useFinalPosition);
	}

	public getCenterPoint(useFinalPosition: boolean = false) {

		const { x, y, width, height } = this.getProps(['x', 'y', 'width', 'height'], useFinalPosition);

		return {
			x: x + width / 2,
			y: y + height / 2
		};
	}

	public tooltipPosition() {
		return this.getCenterPoint();
	}

	public getRange(axis: string) {
		return axis === 'x' ? this._width / 2 : this._height / 2;
	}
}

