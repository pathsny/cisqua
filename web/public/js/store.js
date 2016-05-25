'use strict';

import { createStore, applyMiddleware, compose } from 'redux'
import createLogger from 'redux-logger';
import promiseMiddleware from 'redux-promise-middleware';
import thunk from 'redux-thunk';

import reducer from './reducers'

function prepareStore() {
  const middlewares = [thunk, promiseMiddleware()]
  const logger = createLogger();

  if (process.env.NODE_ENV === `development`) {
    const createLogger = require(`redux-logger`);
    const logger = createLogger();
    middlewares.push(logger);
  }

  const store = createStore(
    reducer,
    compose(
      applyMiddleware(...middlewares),
      window.devToolsExtension ? window.devToolsExtension() : f => f,
    ),
  )
  return store;
}

export default prepareStore();