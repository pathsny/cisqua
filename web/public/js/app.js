'use strict';

import React from 'react';
import { Provider } from 'react-redux'
import {render} from 'react-dom';
import { createStore, applyMiddleware } from 'redux'
import createLogger from 'redux-logger';
import promiseMiddleware from 'redux-promise-middleware';
import injectTapEventPlugin from 'react-tap-event-plugin';
import getMuiTheme from 'material-ui/styles/getMuiTheme';
import MuiThemeProvider from 'material-ui/styles/MuiThemeProvider';

import '../styles/main.css'

import { fetchShows } from './actions' 
import reducer from './reducers'
import Main from './components/main'

function prepareStore() {
  const middlewares = [promiseMiddleware()]
  const logger = createLogger();

  if (process.env.NODE_ENV === `development`) {
    const createLogger = require(`redux-logger`);
    const logger = createLogger();
    middlewares.push(logger);
  }

  const store = createStore(
    reducer,
    applyMiddleware(...middlewares)
  )
  store.dispatch(fetchShows())
  return store;
}

// Needed by Material UI
injectTapEventPlugin();
const store = prepareStore()

render(
  <Provider store={store}>
    <MuiThemeProvider muiTheme={getMuiTheme()}>
      <Main/>
    </MuiThemeProvider> 
  </Provider> ,
  document.getElementById('app')
);  
