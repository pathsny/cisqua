var webpack = require('webpack');
var WebpackDevServer = require('webpack-dev-server');
var config = require('./webpack.config');

new WebpackDevServer(webpack(config), {
  publicPath: config.output.publicPath,
  hot: true,
  historyApiFallback: true,
  proxy: {
    '/log_tailer': {
      target: "http://localhost:9393",
      ws: true,
    },
    '**': {
      target: "http://localhost:9393",
    },
  },
}).listen(9494, 'localhost', function (err, result) {
  if (err) {
    return console.log(err);
  }
  console.log('Listening at http://localhost:9494/');
});