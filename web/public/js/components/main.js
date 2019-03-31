'use strict';

import React, { Component } from 'react';
import { Provider, connect } from 'react-redux'
import { Route, Link, BrowserRouter as Router } from 'react-router-dom'
import {HotKeys} from 'react-hotkeys';

import App from './app'
import Logs from './logs'
import Settings from './settings'
import Home from './home'
import store from '../store'

if (process.env.NODE_ENV === `development`) {
  require('../utils/debug_helper')
}

{/* <Route path="/" component={App}> */}


const Routes = (
  <Router>
    <Route exact path="/" component={Home} />
    <Route path="/logs" component={Logs} />
    <Route path="/settings" component={Settings} />
  </Router>
)

// const MainContent = ({all_valid}) => all_valid ?
//   Routes :
//   (<App><Settings/></App>)

const MainContent = () => Routes

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
