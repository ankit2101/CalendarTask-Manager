import type { Configuration } from 'webpack';
import path from 'path';

import { rules } from './webpack.rules';
import { plugins } from './webpack.plugins';

export const mainConfig: Configuration = {
  /**
   * This is the main entry point for your application, it's the first file
   * that runs in the main process.
   */
  entry: './src/index.ts',
  module: {
    rules,
  },
  plugins,
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css', '.json'],
    alias: {
      // Force jsbi to resolve to its CommonJS build.
      // Without this, webpack picks up the ESM entry (jsbi.mjs) and wraps
      // it with { default: JSBI } — but @js-temporal/polyfill does
      // require('jsbi') expecting the JSBI class directly, so
      // r.BigInt() fails because r is { default: JSBI } not JSBI.
      'jsbi': path.resolve(__dirname, 'node_modules/jsbi/dist/jsbi-cjs.js'),
    },
  },
  externals: {
    // keytar has native .node binaries — must stay external
    'keytar': 'commonjs keytar',
  },
};
