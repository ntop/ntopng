import { do_pie } from './charts/pie-chart'

global.do_pie = do_pie

import './components.scss'

import { ChartWidget, WidgetUtils } from './widget/widgets'
import './sidebar/sidebar'

window.ChartWidget = ChartWidget
window.WidgetUtils = WidgetUtils
