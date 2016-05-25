'use strict';

import { ADD_SHOW, FETCH_SHOWS, ADD_SHOW_DIALOG, FETCH_SUGGESTIONS } from './actions'

import update from 'react-addons-update'
import typeToReducer from 'type-to-reducer'
import { combineReducers } from 'redux'
import {reducer as formReducer} from 'redux-form';
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

const appReducer = typeToReducer({
  [ADD_SHOW]: (state, action) => update(state, {
    showList: {$unshift: [action.payload.id]},
    showsByID: {$merge: {[action.payload.id]: action.payload}},
    dialogsOpen: {addShow: {$set: false}}
  }),
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
  }
}, initialAppState)

const initialAutosuggestState = {
  fetching: {},
  suggestions: {},
}

const autosuggestReducer = typeToReducer({
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


export default combineReducers({
  app: appReducer,
  form: formReducer,
  autosuggest: autosuggestReducer,
})
