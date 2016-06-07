var webpack = require('webpack');
var path = require('path');

var BUILD_DIR = path.resolve(__dirname, 'build');
var APP_DIR = path.resolve(__dirname, 'js');

var config = {
  entry: [
    'webpack-dev-server/client?http://0.0.0.0:9494',
    'webpack/hot/only-dev-server', 
    'babel-polyfill', 
    APP_DIR + '/index.js'
  ],
  output: {
    path: BUILD_DIR,
    publicPath: "http://0.0.0.0:9494/build/",
    filename: 'bundle.js'
  },
  module : {
    loaders : [
      {
        test : /\.jsx?/,
        include : APP_DIR,
        loaders : ['react-hot', 'babel']
      },
      { 
        test: /\.css$/, 
        loader: 'style!css-loader?modules&importLoaders=1&localIdentName=[name]__[local]___[hash:base64:5]'
      }
    ]
  },
  plugins: [
    new webpack.HotModuleReplacementPlugin(),  
    new webpack.ProvidePlugin({
      Promise: 'imports?this=>global!exports?global.Promise!es6-promise',
      fetch: 'imports?this=>global!exports?global.fetch!whatwg-fetch'
    }),
    new webpack.EnvironmentPlugin([
      "NODE_ENV"
    ]),  
  ]
};

module.exports = config;