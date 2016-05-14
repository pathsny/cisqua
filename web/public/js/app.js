'use strict';

import React from 'react';
import { Provider } from 'react-redux'
import {render} from 'react-dom';
import { createStore, applyMiddleware } from 'redux'
import createLogger from 'redux-logger';
import promiseMiddleware from 'redux-promise-middleware';
import { fetchShows } from './actions' 


import reducer from './reducers'
import NewShowComponent from './NewShowComponent'
import ShowListComponent from './ShowListComponent'


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

class App extends React.Component {
  render() {
    return (
      <div>
        <section id="showform">
          <NewShowComponent/>
          <ShowListComponent/>
        </section>
      </div>
    );  
  }
}

store.dispatch(fetchShows())

render(
  <Provider store={store}>
    <App/>
  </Provider> ,
  document.getElementById('app')
);  
