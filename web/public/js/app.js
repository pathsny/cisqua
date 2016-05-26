'use strict';

import React from 'react';
import { Provider } from 'react-redux'
import {render} from 'react-dom';
import injectTapEventPlugin from 'react-tap-event-plugin';
import getMuiTheme from 'material-ui/styles/getMuiTheme';
import MuiThemeProvider from 'material-ui/styles/MuiThemeProvider';

import { fetchShowsSmart } from './actions' 
import Main from './components/main'
import store from './store'

if (process.env.NODE_ENV === `development`) {
  require('./utils/debug_helper')
}  

// Needed by Material UI
injectTapEventPlugin();
store.dispatch(fetchShowsSmart());

render(
  <Provider store={store}>
    <MuiThemeProvider muiTheme={getMuiTheme()}>
      <Main/>
    </MuiThemeProvider> 
  </Provider> ,
  document.getElementById('app')
);  
