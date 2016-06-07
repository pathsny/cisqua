'use strict';

import React, { Component } from 'react';
import { Provider } from 'react-redux'
import getMuiTheme from 'material-ui/styles/getMuiTheme';
import MuiThemeProvider from 'material-ui/styles/MuiThemeProvider';

import Main from './main'
import { fetchShows } from '../actions' 
import store from '../store'

if (process.env.NODE_ENV === `development`) {
  require('../utils/debug_helper')
}

store.dispatch(fetchShows());

export default class App extends Component {
  render() {
    return (
      <Provider store={store}>
        <MuiThemeProvider muiTheme={getMuiTheme()}>
          <Main/>
        </MuiThemeProvider> 
      </Provider>
    );
  }
}
