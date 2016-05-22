'use strict';

import { ADD_SHOW, FETCH_SHOWS } from './actions'
import update from 'react-addons-update'
import typeToReducer from 'type-to-reducer'
import invariant from 'invariant'
import _ from 'lodash'

const initialState = {
  fetching: {
    list: false,
  },
  showsByID: {},
  showList: [],
  itemsByID: {},
  addingShows: {},
}

const reducer = typeToReducer({
  [ADD_SHOW]: {
    PENDING: (state, action) => update(state, {
      addingShows: {$merge: {[action.payload.id]: action.payload.id}}
    }),
    FULFILLED: (state, action) => update(state, {
      showList: {$push: [action.payload.id]},
      showsByID: {$merge: {[action.payload.id]: action.payload}},
      addingShows: {$set: _.omit(state.addingShows, [action.payload.id])},
    }),
  },
  [FETCH_SHOWS]: {
    PENDING: (state, action) => update(state, {
      fetching: {$merge: {list: true}},
    }),
    REJECTED: (state, action) => update(state, {
      fetching: {$merge: {list: false}},
    }),
    FULFILLED: (state, action) => update(state, {
      showList: {$set: action.payload.map(show => show.id)},
      showsByID: {$set: _.keyBy(action.payload, show => show.id)},
      fetching: {$merge: {list: false}},
    }),
  }
}, initialState)

export default reducer