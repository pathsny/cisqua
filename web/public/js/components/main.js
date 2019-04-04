'use strict';

import React, { Component } from 'react';
import { Provider, connect } from 'react-redux'
import { Switch, Route, BrowserRouter as Router } from 'react-router-dom'
import { hot } from 'react-hot-loader/root'
import {HotKeys} from 'react-hotkeys';

import App from './app'
import Logs from './logs'
import Settings from './settings'
import Home from './home'
import store from '../store'

if (process.env.NODE_ENV === `development`) {
  require('../utils/debug_helper')
}

const MainContent = () => (
  <Router>
    <App>
      <Switch>
        <Route exact path="/" component={Home} />
        <Route path="/logs" component={Logs} />
        <Route path="/settings" component={Settings} />
      </Switch>
    </App>
  </Router>
);

const MainConnected = connect((state) => state.settings)(MainContent)

class Main extends Component {
  render() {
    return (
      <Provider store={store}>
        <MainConnected/>
      </Provider>
    );
  }
}

export default hot(Main)
