'use strict';

import { createAction } from 'redux-actions'
import ExtendableError from 'es6-error';
import xml from 'xml-to-json/xml.js'

import {asArray} from './utils/anidb_utils.js'

/*
 * action types
 */

export const ADD_SHOW = 'ADD_SHOW'
export const FETCH_SHOWS = 'FETCH_SHOWS'
export const FETCH_SHOW = 'FETCH_SHOW'
export const REMOVE_SHOW = 'REMOVE_SHOW'
export const ADD_SHOW_DIALOG = 'ADD_SHOW_DIALOG'
export const FETCH_SUGGESTIONS = 'FETCH_SUGGESTIONS'
export const DISMISS_SNACKBAR = 'DISMISS_SNACKBAR'
export const CHECK_ALL_FEEDS = 'CHECK_ALL_FEEDS'
export const CHECK_FEED = 'CHECK_FEED'

/*
 * Utilties
 */

export class JSONResponseCarryingError extends ExtendableError {
  constructor(message, json) {
    super(message)
    this.payload = json
  }
}

class GenericServerError extends ExtendableError {
  constructor(statusText, details) {
    super(statusText)
    this.payload = details
  }
}

async function processResponseError(response) {
  let error;
  try {
    const errorText = await response.text();
    const errorJSON = _.attempt(t => JSON.parse(t), errorText)
    if (_.isError(errorJSON)) {
      error = new GenericServerError(response.statusText, errorText)
    } else {
      error = new JSONResponseCarryingError(response.statusText, errorJSON)   
    }
  } catch (e) {
    error = new GenericServerError(response.statusText)
  }
  throw error
}

async function processJSONResponse(responsePromise) {
  const response = await responsePromise
  if (response.ok) {
    return await response.json()
  }
  await processResponseError(response)
}

function thunkCreationUtil(fn) {
  return (actionCreator) => ((...args) => (
    (dispatch, getState) => fn(actionCreator, dispatch, getState, ...args)
  ));
}


function createAsyncAction(
  actionName,
  asyncFn,
  thunkFn = _.identity,
  metadataFn,
) {
  const actionCreator = createAction(
    actionName,
    (...args) => ({promise: asyncFn(...args)}),
    metadataFn,
  );
  return thunkFn(actionCreator);
}

/*
 * sync operations
 */

export const addShowDialog = createAction(ADD_SHOW_DIALOG);
export const dismissSnackbar = createAction(DISMISS_SNACKBAR)

/*
 * async operations
 */

/*
 * Shows or Show
 */

export const fetchShows = createAsyncAction(
  FETCH_SHOWS,
  async function() {
    return await processJSONResponse(fetch('/shows/with_feed_items')) 
  },
  thunkCreationUtil((actionCreator, dispatch, getState) => {
    if (!getState().app.fetching.list) {
      dispatch(actionCreator());
    }
  }),  
);


export const fetchShow = createAsyncAction(
  FETCH_SHOW,
  async function(id) {
    return await processJSONResponse(fetch(`shows/${id}/with_feed_items`))
  },
  thunkCreationUtil((actionCreator, dispatch, getState, id) => {
    if (!getState().app.fetching.shows[id]) {
      dispatch(actionCreator(id));
    }
  }),
  (id) => ({id}),  
)

export const addShow = createAsyncAction(
  ADD_SHOW,
  async function(id, name, feed_url, auto_fetch) {
    const formData = new FormData()
    formData.append('id', id)
    formData.append('name', name)
    formData.append('feed_url', feed_url)
    formData.append('auto_fetch', auto_fetch)
    return await processJSONResponse(fetch('/shows/new/with_feed_items', {
      method: 'POST',
      body: formData,
    }))
  },
)

export const removeShow = createAsyncAction(
  REMOVE_SHOW,
  async function(id) {
    const formData = new FormData()
    formData.append('id', id)
    const response = await fetch(`/shows/${id}`, {
      method: 'DELETE', 
      body: formData,
    })
    if (!response.ok) {
      return await processResponseError(response)
    }
  },
  _.identity,
  (id) => ({id}), 
)

/*
 * Fetch Suggestions for Autosuggest
 */


export const fetchSuggestionsFromAnidb = createAsyncAction(
  FETCH_SUGGESTIONS,
  async function(hint) {
    const query = hint.trim().replace(/[\s]+/g, ' ').split(' ').
      map(w => `%2B${w}*`).join(' ');
    const url = 'http://anisearch.outrance.pl/?task=search&query=' + query;
    const response = await fetch(url)
    const text = await response.text();
    const xmlData = xml.xmlToJSON(text);
    return asArray(xmlData.animetitles.anime);
  },
  (actionCreator) => {
    const debouncedActionCreator = _.debounce(
      (dispatch, hint) => dispatch(actionCreator(hint)),
      300,
    );
    return (hint) => {
      return (dispatch, getState) => {
        const state = getState();
        if (!(
          _.has(state.autosuggest.fetching, hint) ||
          _.has(state.autosuggest.suggestions, hint)
        )) {
          debouncedActionCreator(dispatch, hint)
        }
      }  
    };
  },
  (hint) => ({hint}),
);  

/*
 * Check Feeds
 */

export const checkAllFeeds = createAsyncAction(
  CHECK_ALL_FEEDS,
  async function (id) {
    const response = await fetch(
      '/force/check_feeds', 
      {method: 'POST'},
    )
    if (response.ok) {
      return id 
    }
    return await processResponseError(response)
  },
);

export const checkFeed = createAsyncAction(
  CHECK_FEED,
  async function(id) {
    const response = await fetch(
      `/force/check_feed/${id}`, 
      {method: 'POST'}
    );
    if (response.ok) {
      return id 
    }
    return await processResponseError(response)
  },
);

