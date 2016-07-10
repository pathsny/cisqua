'use strict';

import React, { Component } from 'react';
import { Provider, connect } from 'react-redux'
import { Router, Route, browserHistory, IndexRoute } from 'react-router'
import {HotKeys} from 'react-hotkeys';

import App from './app'
import Logs from './logs'
import Settings from './settings'
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
      <Route path="/settings" component={Settings} />
    </Route>
  </Router>    
)

// const MainContent = ({all_valid}) => all_valid ? 
//   Routes : 
//   (<App><Settings/></App>)

const MainContent = ({all_valid}) => Routes;
const MainConnected = connect((state) => state.settings)(MainContent)

export default class Main extends Component {
  render() {
    return (
      <Provider store={store}>
        <MainConnected/>
      </Provider>
    );
  }
}
