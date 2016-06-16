'use strict';

import React, { Component } from 'react';
import { Provider } from 'react-redux'
import { Router, Route, browserHistory, IndexRoute } from 'react-router'
import {HotKeys} from 'react-hotkeys';

import App from './app'
import Logs from './logs'
import Home from './home'
import store from '../store'

if (process.env.NODE_ENV === `development`) {
  require('../utils/debug_helper')
}

const Routes = (
  <Router history={browserHistory}>
    <Route path="/" component={App}>
      <IndexRoute component={Home} />
      <Route path="/logs" component={Logs} />
    </Route>
  </Router>    
)

export default class Main extends Component {
  render() {
    return (
      <Provider store={store}>
        {Routes}
      </Provider>
    );
  }
}
