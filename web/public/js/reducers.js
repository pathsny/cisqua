'use strict';

import {
  ADD_SHOW, 
  FETCH_SHOWS, 
  ADD_SHOW_DIALOG, 
  FETCH_SUGGESTIONS,
  DISMISS_SNACKBAR, 
  JSONResponseCarryingError
} from './actions'

import ExtendableError from 'es6-error';
import update from 'react-addons-update'
import typeToReducer from 'type-to-reducer'
import { combineReducers } from 'redux'
import {reducer as form} from 'redux-form';
import invariant from 'invariant'
import _ from 'lodash'

import {getAnidbTitle} from './utils/anidb_utils'

const initialAppState = {
  fetching: {
    list: false,
  },
  dialogsOpen: {
    addShow: false,
  },
  showsByID: {},
  showList: [],
  itemsByID: {},
}

const app = typeToReducer({
  [ADD_SHOW]: {
    FULFILLED: (state, action) => update(state, {
      showList: {$unshift: [action.payload.id]},
      showsByID: {$merge: {[action.payload.id]: action.payload}},
      dialogsOpen: {addShow: {$set: false}}
    }),
  },
  [ADD_SHOW_DIALOG]: (state, action) => update(state, {
    dialogsOpen: {addShow: {$set: action.payload}}
  }),
  [FETCH_SHOWS]: {
    PENDING: (state, action) => update(state, {
      fetching: {$merge: {list: true}},
    }),
    REJECTED: (state, action) => update(state, {
      fetching: {$merge: {list: false}},
    }),
    FULFILLED: (state, action) => {
      const shows = _.orderBy(
        action.payload, 
        [(s) => new Date(s.created_at)],
        ['desc'],
      );
      return update(state, {
        showList: {$set: shows.map(show => show.id)},
        showsByID: {$set: _.keyBy(shows, show => show.id)},
        fetching: {$merge: {list: false}},
      });
    },
  },
}, initialAppState)

const initialAutosuggestState = {
  fetching: {},
  suggestions: {},
}

const autosuggest = typeToReducer({
  [FETCH_SUGGESTIONS]: {
    PENDING: (state, action) => {
      const hint = action.meta.hint
      return update(state, {
        fetching: {$merge: {[hint]: hint}}
      });
    },
    REJECTED: (state, action) => {
      const hint = action.meta.hint
      return update(state, {
        fetching: {$set: _.omit(state.fetching, [hint])}
      })
    },
    FULFILLED: (state, action) => {
      const hint = action.meta.hint
      const suggestions = _.take(action.payload, 10).map(
        s => update(s, {$merge: {name: getAnidbTitle(s)}}) 
      );
      return update(state, {
        fetching: {$set: _.omit(state.fetching, [hint])},
        suggestions: {$merge: {[hint]: suggestions}}
      })
      return state;
    },  
  }
}, initialAutosuggestState)

const rejectedActionRegex = /(.*)_REJECTED/

function snackbarPayloads(state = [], action) {
  if (action.type === DISMISS_SNACKBAR) {
    return _.tail(state)
  }
  const match = action.type.match(rejectedActionRegex)
  if (!match || action.payload instanceof JSONResponseCarryingError) {
    return state;
  }
  const message = `Error attempting ${match[1]}. ${action.payload.message}`;  
  const lastPayload = _.last(state)
  if (!lastPayload || lastPayload.message !== message) {
    return _.concat(state, [{message}])
  }
  return state
}

export default combineReducers({app, form, autosuggest, snackbarPayloads})
