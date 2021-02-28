/**
 * (C) 2021 - ntop.org
*/

import { ChartTypeRegistry } from 'chart.js'

/**
 * Extend ChartTypeRegistry with the matrix type
 */
declare module 'chart.js' {
    interface ChartTypeRegistry {
        matrix: ChartTypeRegistry['bar']
    }
}