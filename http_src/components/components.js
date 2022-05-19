import { do_pie } from './charts/pie-chart'

window.do_pie = do_pie

import { ChartWidget, WidgetUtils } from './widget/widgets'
import './sidebar/sidebar'
import { ntopChartApex } from "./ntopChartApex";

window.ChartWidget = ChartWidget;
window.WidgetUtils = WidgetUtils;
window.ntopChartApex = ntopChartApex;
