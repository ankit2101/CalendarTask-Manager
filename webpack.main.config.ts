import type { Configuration } from 'webpack';
import TerserPlugin from 'terser-webpack-plugin';

import { rules } from './webpack.rules';
import { plugins } from './webpack.plugins';

export const mainConfig: Configuration = {
  /**
   * This is the main entry point for your application, it's the first file
   * that runs in the main process.
   */
  entry: './src/index.ts',
  // Put your normal webpack config below here
  module: {
    rules,
  },
  plugins,
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css', '.json'],
  },
  externals: {
    // keytar has native .node binaries — must stay external and be unpacked from asar
    'keytar': 'commonjs keytar',
  },
  optimization: {
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          mangle: {
            // luxon (used by node-ical) calls BigInt() at runtime;
            // terser must not rename/mangle it or the app crashes.
            reserved: ['BigInt'],
          },
        },
      }),
    ],
  },
};
