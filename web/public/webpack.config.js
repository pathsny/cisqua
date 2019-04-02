var webpack = require('webpack');
var path = require('path');

var BUILD_DIR = path.resolve(__dirname, 'build');
var APP_DIR = path.resolve(__dirname, 'js');

var config = {
  entry: [
    APP_DIR + '/index.js'
  ],
  output: {
    path: BUILD_DIR,
    publicPath: "/build/",
    filename: 'bundle.js'
  },
  module : {
    rules : [
      {
        test : /\.jsx?/,
        include : APP_DIR,
        use: [
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
  ],
  devServer: {
    port: 9494,
    host: 'localhost',
    hot: true,
    index: '',
    headers: {
      'Access-Control-Allow-Origin': '*'
	  },
    proxy: {
      context: () => true,
      target: 'http://localhost:9393'
    }
  }
};

module.exports = config;
