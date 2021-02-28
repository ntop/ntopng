/**
 * Repository: kurkle/chartjs-chart-matrix
 * License: MIT
 * URL: https://github.com/kurkle/chartjs-chart-matrix
 */

import { ChartDatasetProperties, DatasetController, UpdateMode } from 'chart.js';
import MatrixElement from './MatrixElement';

export class MatrixController extends DatasetController<MatrixElement> {

	static id: string = 'matrix';
	static defaults: any;

	/**
	 * Initializes the controller
	 */
	public initialize(): void {
		this.enableOptionSharing = true;
		super.initialize();
	}

	/**
	 * Update the elements in response to new data
	 * @param mode update mode, core calls this method using any of `'active'`, `'hide'`, `'reset'`, `'resize'`, `'show'` or `undefined`
	 */
	public update(mode: UpdateMode): void {
		const meta = this._cachedMeta;
		this.updateElements(meta.data, 0, meta.data.length, mode);
	}

	updateElements(rects, start: number, count: number, mode: UpdateMode) {
		
		const reset = mode === 'reset';
		const { xScale, yScale } = this._cachedMeta;
		const sharedOptions = this.getSharedOptions(mode);

		for (let i = start; i < start + count; i++) {
			const parsed = !reset && this.getParsed(i);
			const x = reset ? xScale.getBasePixel() : xScale.getPixelForValue(parsed.x, 0);
			const y = reset ? yScale.getBasePixel() : yScale.getPixelForValue(parsed.y, 0);
			const options = this.resolveDataElementOptions(i, mode);
			const { width, height, anchorX, anchorY } = options;
			const properties = {
				x: anchorX === 'left' ? x : x - width / (anchorX === 'right' ? 1 : 2),
				y: anchorY === 'top' ? y : y - height / (anchorY === 'bottom' ? 1 : 2),
				width,
				height,
				options
			};
			this.updateElement(rects[i], i, properties, mode);
		}

		this.updateSharedOptions(sharedOptions, mode, undefined);
	}

	/**
	 * Draw the representation of the dataset
	 */
	public draw(): void {

		const data = this.getMeta().data || [];
		let ilen = data.length;

		for (let i = 0; i < ilen; ++i) {
			data[i].draw(this.chart.ctx);
		}
	}
}

// define the defaults value for a Matrix Chart
MatrixController.defaults = {
	dataElementType: 'matrix',
	dataElementOptions: [
		'backgroundColor',
		'borderColor',
		'borderWidth',
		'anchorX',
		'anchorY',
		'width',
		'height'
	],
	datasets: {
		animation: {
			numbers: {
				type: 'number',
				properties: ['x', 'y', 'width', 'height']
			}
		},
		anchorX: 'center',
		anchorY: 'center'
	},
	interaction: {
		mode: 'nearest',
		intersect: true
	},
	scales: {
		x: {
			type: 'linear',
			offset: true
		},
		y: {
			type: 'linear',
			reverse: true
		}
	},
};
