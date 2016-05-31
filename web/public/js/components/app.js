'use strict';

import React, { Component } from 'react';
import { Provider } from 'react-redux'
import getMuiTheme from 'material-ui/styles/getMuiTheme';
import MuiThemeProvider from 'material-ui/styles/MuiThemeProvider';
import {HotKeys} from 'react-hotkeys';

import Main from './main'
import ShowFetcher from './show_fetcher'
import store from '../store'

if (process.env.NODE_ENV === `development`) {
  require('../utils/debug_helper')
}

const keyEventsMap = {
  'addShow': 'n',
  'filterShows': 'f',
  'escape': 'escape',
};  

export default class App extends Component {
  render() {
    return (
      <Provider store={store}>
        <MuiThemeProvider muiTheme={getMuiTheme()}>
          <HotKeys keyMap={keyEventsMap} >
            <ShowFetcher />
            <Main autoFocus={true}/>
          </HotKeys>  
        </MuiThemeProvider> 
      </Provider>
    );
  }
}
