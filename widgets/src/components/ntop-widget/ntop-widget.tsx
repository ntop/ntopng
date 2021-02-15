/**
 * (C) 2021 - ntop.org
*/

import { Component, Host, Element, h, State, Prop, Method, Watch, Listen } from '@stencil/core';
import { Formatter } from '../../types/Formatter';
import { DisplayFormatter } from "../../types/DisplayFormatter";
import { WidgetRestResponse } from '../../types/WidgetRestResponse';
import { FormatterMap } from '../../formatters/FormatterMap';
import { RestCode } from '../../types/RestCode';
import { WidgetRestRequest } from '../../types/WidgetRestRequest';
import { Datasource } from '../../types/Datasource';
import { NtopDatasource } from './ntop-datasource';

declare global {

    // extend the Window interface
    interface Window {
        __NTOPNG_ORIGIN__: string;
    }
}

@Component({
    tag: 'ntop-widget',
    styleUrl: 'ntop-widget.css',
    shadow: true,
})
export abstract class NtopWidget {

    private NTOPNG_ENDPOINT: string = "/lua/rest/v1/get/widget/data.lua";

    /**
     * The refresh time for the widge,
     */
    @Prop() update: number = 1000;
    @Prop() type: string;

    @Prop() width!: string;
    @Prop() height!: string;
    
    @Prop({attribute: 'display'}) displayFormatter: DisplayFormatter = DisplayFormatter.PERCENTAGE;

    @Element() host: HTMLNtopWidgetElement;
    @State() _fetchedData: WidgetRestResponse;

    _containedDatasources: Array<NtopDatasource> = [];

    /**
     * The selected formatter to style the widget.
     */
    private _selectedFormatter: Formatter;
    /**
     * A flag indicating if the viewer has been initialized by the widget.
     */
    private _viewerInitialized: boolean = false;
    /**
     * An interval ID used to manage the internal Interval Timer.
     */
    private _intervalId: NodeJS.Timeout;

    private _mutationObserver: MutationObserver;

    componentDidRender() {
        
        if (this._fetchedData !== undefined && !this._viewerInitialized) {

            if (this._fetchedData.rc < RestCode.SUCCESS) return;

            this._selectedFormatter.init(this.host.shadowRoot);
            this._viewerInitialized = true;
        }
        else if (this._fetchedData !== undefined && this._viewerInitialized) {
            this._selectedFormatter.update();
        }
    }

    async componentWillLoad() {

        let constructor = FormatterMap.MIXED;

        if (this.type !== undefined) {
            constructor = FormatterMap[this.type.toUpperCase()];
        }

        if (constructor !== undefined) {
            this._selectedFormatter = new constructor(this);
        }

        this._mutationObserver = new MutationObserver((mutations) => {
            mutations.forEach(async mutation => {
                if (mutation.type === 'childList') {
                    await this.datasourceChanged();
                }
            })
        });
        this._mutationObserver.observe(this.host, { attributes: false, childList: true });

        await this.updateWidget();

        // start the timer if the update time is greater than zero
        if (this.update > 0 && this._fetchedData.rc === RestCode.SUCCESS) {
            // update the chart
            this._intervalId = setInterval(async () => { await this.updateWidget(); }, this.update);
        }
    } 

    @Listen('srcChanged')
    async datasourceChanged() {
        
        // if there is an active interval timer stop it
        if (this.update > 0 && this._intervalId) {
            clearInterval(this._intervalId);
        }

        await this.updateWidget();

        // start the timer if the update time is greater than zero
        if (this.update > 0 && this._fetchedData.rc === RestCode.SUCCESS) {
            // update the chart
            this._intervalId = setInterval(async () => { await this.updateWidget(); }, this.update);
        }

    }

    private async updateWidget() {
        
        // if a user changed the updating time then stop the interval timer
        if (this.update <= 0) {
            clearInterval(this._intervalId);
        }
        
        this._fetchedData = await this.getWidgetData() as WidgetRestResponse;
    }

    /**
     * Serialize the contained <ntop-datasource> into an array of Datasources
     * to be send to the ntopng instance.
     */
    private serializeDatasources(): Array<Datasource> {
    
        const datasources = new Array<Datasource>();
        this._containedDatasources = new Array();

        this.host.querySelectorAll('ntop-datasource').forEach((ntopDatasource) => {
       
            const params = {};
            this._containedDatasources.push({
                src: ntopDatasource.src, 
                styles: JSON.parse(ntopDatasource.styles || "{}"), 
                type: ntopDatasource.type,
            });

            const [src, query] = ntopDatasource.src.split('?');
            const searchParams = new URLSearchParams('?' + query);
            searchParams.forEach((value, key) => { params[key] = value });

            const datasource: Datasource = {params: params, ds_type: src};
            datasources.push(datasource);
        });

        return datasources;
    }

    private async getWidgetData() {

        // use global origin or current origin
        const origin: string = window.__NTOPNG_ORIGIN__ || location.origin;
        const endpoint: URL = new URL(this.NTOPNG_ENDPOINT, origin);

        const headers = {'Content-Type': 'application/json; charset=utf-8'};
        const transformation = (['pie', 'donut'].includes(this.type)) ? 'aggregate' : 'none'; 
        const request: WidgetRestRequest = {datasources: this.serializeDatasources(), transformation: transformation};

        try {
            const response = await fetch(endpoint.toString(), {method: 'POST', body: JSON.stringify(request), headers: headers});
            return await response.json();
        }
        catch (e) {
            console.error(`[ntop-widget][error] :: ${e}`);
            return undefined;
        }
    }

    /**
     * Render a loading screen for the widget when is fetching the data.
     */
    private renderLoading() {  
        return <div class='loading shine'></div>
    } 

    private renderErrorScreen() {

        // const errorCode: RestCode = this.fetchedData.rc;
        const message = `[Error][${this._fetchedData.rc}] :: ${this._fetchedData.rc_str_hr || 'Something went wrong...'}`;
        return <div class='error'>{message}</div>
    }

    render() {

        const view = (this._fetchedData === undefined) ? 
            this.renderLoading() : (this._fetchedData.rc < RestCode.SUCCESS) ? 
                this.renderErrorScreen() : this._selectedFormatter.staticRender();

        return (
            <Host>
                <div class='ntop-widget-container transparent'>
                    <slot name='header'></slot>
                    {view}
                    <slot name='footer'></slot>
                </div>
            </Host>
        );
    }

}
