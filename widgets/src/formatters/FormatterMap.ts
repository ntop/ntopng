/**
 * (C) 2021 - ntop.org
*/

import StackedBarWidgetFormatter from "./charts/StackedBarWidgetFormatter";
import DonutWidgetFormatter from "./charts/DonutWidgetFormatter";
import PieWidgetFormatter from "./charts/PieWidgetFormatter";
import MixedChartWidgetFormatter from "./charts/MixedChartWidgetFormatter";
import RadarChartWidgetFormatter from "./charts/RadarWidgetFormatter";
import MatrixWidgetFormatter from "./charts/MatrixWidgetFormatter";

/**
 * The FormatterMap contains a list of constructor
 * of the available formatters.
 */
export const FormatterMap = {
    PIE: PieWidgetFormatter,
    DONUT: DonutWidgetFormatter,
    STACKEDBAR: StackedBarWidgetFormatter,
    MIXED: MixedChartWidgetFormatter,
    RADAR: RadarChartWidgetFormatter,
    MATRIX: MatrixWidgetFormatter
}