/**
 * (C) 2021 - ntop.org
*/

import { Component, EventEmitter, Prop, Watch} from '@stencil/core';
import { Event } from '@stencil/core';

@Component({
  tag: 'ntop-datasource'
})
export class NtopDatasource {
  
  @Prop({attribute: 'src'}) src!: any;
  @Prop({attribute: 'styling'}) styles?: string;
  @Prop({}) name?: string;
  @Prop({}) type?: string;

  @Event({
    eventName: 'srcChanged',
    cancelable: false,
    composed: false,
    bubbles: true
  }) srcChanged?: EventEmitter<string>;

  @Watch('src')
  srcHandler?(newValue: string) {
    this.srcChanged.emit(newValue);
  }

}