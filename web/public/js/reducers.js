'use strict';

import {
  ADD_SHOW, 
  FETCH_SHOWS,
  FETCH_SHOW,
  REMOVE_SHOW, 
  ADD_SHOW_DIALOG, 
  FETCH_SUGGESTIONS,
  DISMISS_SNACKBAR,
  CHECK_ALL_FEEDS, 
  CHECK_FEED,

  TAILING_LOGS_START,
  TAILING_LOGS_STOP, 
  TAILING_LOGS_ERROR,
  TAILING_LOGS_LOG,
  JSONResponseCarryingError,
} from './actions'

import ExtendableError from 'es6-error';
import update from 'react-addons-update'
import typeToReducer from 'type-to-reducer'
import { combineReducers } from 'redux'
import {reducer as form} from 'redux-form';
import invariant from 'invariant'
import _ from 'lodash'

import {getAnidbTitle} from './utils/anidb_utils'
import {ShowSorter, FeedItemSorter} from './utils/sorters'

function maybeDate(d) {
  return d ? new Date(d) : d
}

function mapFeedItem({published_at, downloaded_at, hidden_at, marked_predownloaded_at, ...feedItemProps}) {
  return {
    published_at: new Date(published_at),
    downloaded_at: maybeDate(downloaded_at),
    hidden_at: maybeDate(hidden_at),
    marked_predownloaded_at: maybeDate(marked_predownloaded_at),
    ...feedItemProps,
  }
}

function mapShowAndFeedItems({
  feed_items, 
  created_at,
  last_checked_at, 
  latest_feed_item_added_at,
  ...showProps
}) {
  return {
    feedItemsByID: _.keyBy(feed_items.map(mapFeedItem), f => f.id),
    show: {
      feed_items: FeedItemSorter.sortFeedItems(feed_items).map(f => f.id),
      created_at: new Date(created_at),
      last_checked_at: maybeDate(last_checked_at),
      latest_feed_item_added_at: maybeDate(latest_feed_item_added_at),
      ...showProps,
    }
  }
}

function updateForShow(state, showPayload) {
  const {feedItemsByID, show} = mapShowAndFeedItems(showPayload)
  const shows = ShowSorter.mergeSorted(
    state.showList.map(id => state.showsByID[id]),
    state.showsByID[show.id],
    show,
  );
  return {
    showList: {$set: shows.map(show => show.id)},
    showsByID: {$merge: {[show.id]: show}},
    feedItemsByID: {$merge: feedItemsByID}
  };
}

const initialAppState = {
  fetching: {
    list: false,
    shows: {},
  },
  dialogsOpen: {
    addShow: false,
  },
  showsByID: {},
  showList: [],
  isUpdatingFeedItemsForAllShows: false,
  feedItemsByID: {},
}

const app = typeToReducer({
  [ADD_SHOW]: {
    FULFILLED: (state, action) => update(state, _.merge(
      updateForShow(state, _.merge(
        action.payload, 
        {is_updating_feed_items: true}
      )),
      {dialogsOpen: {addShow: {$set: false}}}
    )),
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
      const showsAndFeedItems = action.payload.shows.map(mapShowAndFeedItems)
      const feedItemsByID = Object.assign({}, ..._.map(showsAndFeedItems, 'feedItemsByID'))
      const shows = ShowSorter.sortShows(_.map(showsAndFeedItems, 'show'))
      return update(state, {
        showList: {$set: shows.map(show => show.id)},
        showsByID: {$set: _.keyBy(shows, show => show.id)},
        feedItemsByID: {$set: feedItemsByID},
        fetching: {$merge: {list: false}},
        isUpdatingFeedItemsForAllShows: {$set: action.payload.is_updating_feed_items},
      });
    },
  },
  [FETCH_SHOW]: {
    PENDING: (state, action) => update(state, {
      fetching: {shows: {$merge: {[action.meta.id]: true}}},
    }),
    REJECTED: (state, action) => update(state, {
      fetching: {shows: {$set: _.omit(state.fetching.shows, action.meta.id)}},
    }),
    FULFILLED: (state, action) => update(state, _.merge(
      updateForShow(state, action.payload),
      {fetching: {shows: {$set: _.omit(state.fetching.shows, action.meta.id)}}},
    )),
  },
  [REMOVE_SHOW]: {
    FULFILLED: (state, action) => update(state, {
      showList: {$set: _.without(state.showList, action.meta.id)},
      showsByID: {$set: _.omit(state.showsByID, [action.meta.id])},
    }),
  },
  [CHECK_FEED]: {
    FULFILLED: (state, action) => update(state, {
      showsByID: {[action.payload]: {
        is_updating_feed_items: {$set: true},
      }},
    }),
  },
  [CHECK_ALL_FEEDS]: {
    FULFILLED: (state, action) => {
      const show_updates = _.times(state.showList.length, _.constant(
        {is_updating_feed_items: {$set: true}}
      ));
      return update(state, {
        isUpdatingFeedItemsForAllShows: {$set: true},
        showsByID: _.zipObject(state.showList, show_updates),
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

const rejectedActionRegex = /(.*)_REJECTED|(TAILING_LOGS)_ERROR/

function snackbarPayloads(state = [], action) {
  if (action.type === DISMISS_SNACKBAR) {
    return _.tail(state)
  }
  const match = action.type.match(rejectedActionRegex)
  if (!match || action.payload instanceof JSONResponseCarryingError) {
    return state;
  }
  const failedAction = match[1] || match[2]
  const failedReason = _.get(action, 'payload.message', '')
  const message = `Error attempting ${failedAction}. ${failedReason}`;  
  const lastPayload = _.last(state)
  if (!lastPayload || lastPayload.message !== message) {
    return _.concat(state, [{message}])
  }
  return state
}

const MAX_LOGS = 1000

const logs = typeToReducer({
  [TAILING_LOGS_START]: (state, action) => action.payload,
  [TAILING_LOGS_LOG]: (state, action) => {
    return _.concat(_.takeRight(state, MAX_LOGS), action.payload)
  } 
}, [])

export default combineReducers({
  app, 
  form, 
  autosuggest, 
  snackbarPayloads,
  logs,
})
