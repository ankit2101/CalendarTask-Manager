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
  module: {
    rules,
  },
  plugins,
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css', '.json'],
  },
  externals: {
    // keytar has native .node binaries — must stay external
    'keytar': 'commonjs keytar',
  },
  optimization: {
    // Disable scope hoisting (module concatenation). temporal-polyfill
    // (a node-ical dependency) calls BigInt() as a global. Webpack's
    // ModuleConcatenationPlugin inlines modules into a shared scope where
    // the global reference gets broken — producing "r.BigInt is not a function".
    concatenateModules: false,
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          compress: {
            // Don't collapse variables that reference globals
            toplevel: false,
          },
        },
      }),
    ],
  },
};
