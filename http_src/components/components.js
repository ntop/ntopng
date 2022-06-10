import { do_pie } from './charts/pie-chart'

window.do_pie = do_pie

import { ChartWidget, WidgetUtils } from './widget/widgets'
import './sidebar/sidebar'
import { ntopChartApex } from "./ntopChartApex";

/* datatables.net extensions */
import { DataTableFiltersMenu, DataTableUtils, DataTableRenders } from '../utilities/datatable/sprymedia-datatable-utils.js'

window.DataTableUtils = DataTableUtils
window.DataTableFiltersMenu = DataTableFiltersMenu
window.DataTableRenders = DataTableRenders

window.ChartWidget = ChartWidget;
window.WidgetUtils = WidgetUtils;
window.ntopChartApex = ntopChartApex;
