import {QueryCtrl} from 'app/plugins/sdk';
import './css/query-editor.css!'

export class GenericDatasourceQueryCtrl extends QueryCtrl {

  constructor($scope, $injector)  {
    super($scope, $injector);

    this.scope = $scope;
    this.target.target = this.target.target || 'select metric';
    this.target.type = this.target.type || 'timeserie';
  }

  getOptions(query) {
    return this.datasource.metricFindQuery(query || '');
  }

  toggleEditorMode() {
    this.target.rawQuery = !this.target.rawQuery;
  }

  onChangeInternal() {
    this.panelCtrl.refresh(); // Asks the panel to refresh data.
  }
}

GenericDatasourceQueryCtrl.templateUrl = 'partials/query.editor.html';

