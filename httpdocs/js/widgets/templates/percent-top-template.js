import WidgetTemplate from "./default-template.js";

export default class PercentCardTemplate extends WidgetTemplate {

    constructor(params) {
        super(params);
    }

    render() {

        const percentContainer = document.createElement('div');
        percentContainer.classList = 'card';
        const cardBody = document.createElement('div');
        cardBody.classList = 'card-body';
        const cardTitle = document.createElement('h5');
        cardTitle.classList = 'card-title';
        cardTitle.innerHTML = `${this._data.title}`;
        const cardBigText = document.createElement('span');
        cardBigText.innerHTML = `<b style='font-size: 2rem'>${this._data.percent}%</b>`;

        if (this._defaultOptions.widget.intervalTime) {

            const self = this;
            this._intervalId = setInterval(async function() {
                self._data = await self._updateData();
                // TODO: update
            }, this._defaultOptions.widget.intervalTime);
        }

        percentContainer.appendChild(
            cardBody.appendChild(
                cardTitle
            )
        );
        cardBody.appendChild(cardBigText);

        return super.render().appendChild(percentContainer);
    }
}