'use strict';

import { createStore, applyMiddleware, compose } from 'redux'
import { createLogger } from 'redux-logger';
import promise from 'redux-promise-middleware'
import thunk from 'redux-thunk';

import reducer from './reducers'

function prepareStore() {
  const middlewares = [thunk, promise]

  // if (process.env.NODE_ENV === `development`) {
  //   const logger = createLogger();
  //   middlewares.push(logger);
  // }

  const store = createStore(
    reducer,
    compose(
      applyMiddleware(...middlewares),
      window.devToolsExtension ? window.devToolsExtension() : f => f,
    ),
  )

  if (module.hot) {
    module.hot.accept('./reducers', () => {
      store.replaceReducer(require('./reducers').default);
    });
  }

  return store;
}

export default prepareStore();
