var webpack = require('webpack');
var path = require('path');

var BUILD_DIR = path.resolve(__dirname, 'build');
var APP_DIR = path.resolve(__dirname, 'js');

var config = {
  entry: [
    APP_DIR + '/index.js'
  ],
  // entry: [
  //   'webpack-dev-server/client?http://0.0.0.0:9494',
  //   'webpack/hot/only-dev-server',
  //   'babel-polyfill',
  //   APP_DIR + '/index.js'
  // ],
  output: {
    path: BUILD_DIR,
    publicPath: "http://0.0.0.0:9494/build/",
    filename: 'bundle.js'
  },
  module : {
    rules : [
      {
        test : /\.jsx?/,
        include : APP_DIR,
        use: [
          // {loader: 'react-hot-loader'},
          {loader: 'babel-loader'},
        ]
      },
      {
        test: /\.css$/,
         use: [{ loader: 'style-loader' }, { loader: 'css-loader' }],
      }
    ]
  },
  plugins: [
    new webpack.HotModuleReplacementPlugin(),
    new webpack.ProvidePlugin({
      Promise: 'imports-loader?this=>global!exports-loader?global.Promise!es6-promise',
      fetch: 'exports-loader?self.fetch!whatwg-fetch/dist/fetch.umd',
    }),
    new webpack.EnvironmentPlugin([
      "NODE_ENV"
    ]),
  ]
};

module.exports = config;
