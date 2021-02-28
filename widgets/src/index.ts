/**
 * (C) 2021 - ntop.org
 * Entry point to register charts used by Chart.js. This scripts
 * is necessary as stated by the Chart.js documentation: https://www.chartjs.org/docs/next/getting-started/v3-migration#setup-and-installation
*/

export { Components, JSX } from './components';
import { Chart, LineController, LineElement, PointElement, LinearScale, Title, PieController, BarController, DoughnutController, CategoryScale, ScatterController, BarElement, ArcElement, RadarController, RadialLinearScale, BubbleController, Tooltip, Legend, Filler } from 'chart.js';
import { MatrixController } from './controllers/charts/MatrixController.js';
import { MatrixElement } from './controllers/charts/MatrixElement.js';
import { log } from './utils/utils';
import { VERSION } from './version';

log(`🔄 Loading ntop-widget version: ${VERSION}...`)

log("🔄 Registering Chart Controllers...");
Chart.register(
    // Controllers
    LineController, BarController, PieController, DoughnutController, ScatterController, RadarController, BubbleController, MatrixController,
    // Elements
    LineElement, PointElement, BarElement, ArcElement, MatrixElement,
    // Scales
    LinearScale, CategoryScale, RadialLinearScale,
    // Components
    Tooltip, Legend, Filler
);
log("✅ Chart Controllers registered!");
log("✅ Loading completed!");
