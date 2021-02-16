/**
 * (C) 2021 - ntop.org
*/

import { Config } from '@stencil/core';

// https://stackoverflow.com/questions/60633526/how-to-use-an-external-third-party-library-in-stencil-js

export const config: Config = {
  namespace: 'ntop-widgets',
  globalScript: './src/index.ts',
  outputTargets: [
    {
      type: 'dist',
      esmLoaderPath: '../loader',
    },
    {
      type: 'dist-custom-elements-bundle',
    },
    {
      type: 'docs-readme',
    },
  ],
};
