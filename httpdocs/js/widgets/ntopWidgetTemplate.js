;
export default class NtopWidgetTemplate {
    render(data) {
        const container = document.createElement('div');
        container.setAttribute('class', 'ntop-widget-container');
        return container;
    }
}
