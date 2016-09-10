'use strict';

import { createAction } from 'redux-actions'
import ExtendableError from 'es6-error';
import xml from 'xml-to-json/xml.js'
import ReconnectingWebSocket from 'reconnectingwebsocket'

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

export const DOWNLOAD_FILE = 'DOWNLOAD_FILE'
export const TOGGLE_DOWNLOADED = 'TOGGLE_DOWNLOADED'

export const TAILING_LOGS_START = 'TAILING_LOGS_START'
export const TAILING_LOGS_STOP = 'TAILING_LOGS_STOP'
export const TAILING_LOGS_ERROR =  'TAILING_LOGS_ERROR'
export const TAILING_LOGS_LOG =  'TAILING_LOGS_LOG'

export const FETCH_SETTINGS = 'FETCH_SETTINGS'
export const SAVE_SETTINGS = 'SAVE_SETTINGS'

export const RUN_POST_PROCESSOR = 'RUN_POST_PROCESSOR'

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
    console.log("I got ", errorJSON, errorText);
    if (_.isError(errorJSON)) {
      console.log("branch 1");
      error = new GenericServerError(response.statusText, errorText)
    } else {
      console.log("branch 2");
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
    if (!getState().app.async.showList) {
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
    if (!getState().app.async.showsByID[id]) {
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
          _.has(state.autosuggest.async, hint) ||
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
  async function(id) {
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
      {method: 'POST'},
    );
    if (response.ok) {
      return id 
    }
    return await processResponseError(response)
  },
);

/*
 * FeedItem Actions
 */

export const downloadFile = createAsyncAction(
  DOWNLOAD_FILE,
  async function(showID, feedItemID) {
    const response = await fetch(
      `/shows/${showID}/feed_item/download?id=${encodeURIComponent(feedItemID)}`,
      {method: 'POST'},
    )
    return processJSONResponse(response)
  },
  _.identity,
  (showID, feedItemID) => ({showID, feedItemID}),
)


export const markDownloaded = createAsyncAction(
  TOGGLE_DOWNLOADED,
  async function(showID, feedItemID) {
    const response = await fetch(
      `/shows/${showID}/feed_item/mark_downloaded?id=${encodeURIComponent(feedItemID)}`,
      {method: 'POST'},
    )
    return processJSONResponse(response)
  },
  _.identity,
  (showID, feedItemID) => ({showID, feedItemID}),
)

export const unmarkDownloaded = createAsyncAction(
  TOGGLE_DOWNLOADED,
  async function(showID, feedItemID) {
    const response = await fetch(
      `/shows/${showID}/feed_item/unmark_downloaded?id=${encodeURIComponent(feedItemID)}`,
      {method: 'POST'},
    )
    return processJSONResponse(response)
  },
  _.identity,
  (showID, feedItemID) => ({showID, feedItemID}),
)

/*
 * Logs
 */

export const {startTailingLogs, stopTailingLogs} = (function() {
  let wsclient;
  const uri = `ws://${window.document.location.host}/log_tailer`

  const tailingLogsStart = createAction(TAILING_LOGS_START)
  const tailingLogsStop = createAction(TAILING_LOGS_STOP)
  const tailingLogsError = createAction(TAILING_LOGS_ERROR)
  const tailingLogsLog = createAction(TAILING_LOGS_LOG)

  return {
    startTailingLogs() {
      return dispatch => {
        wsclient && wsclient.close()
        wsclient = new ReconnectingWebSocket(uri)
        wsclient.onerror = () => dispatch(tailingLogsError())
        wsclient.onclose = () => dispatch(tailingLogsStop())
        wsclient.onmessage = (m) => {
          const logs = JSON.parse(m.data)
          if (_.isArray(logs)) {
            dispatch(tailingLogsStart(logs.map(l => JSON.parse(l))))
          } else {
            dispatch(tailingLogsLog(logs))
          }
        }
      }
    },
    stopTailingLogs() {
      wsclient && wsclient.close()
    },
  };
})()


/**
 * Settings
 */

export const fetchSettings = createAsyncAction(
  FETCH_SETTINGS,
  async function() {
    return await processJSONResponse(fetch(`/settings/values`))
  },
)

export const saveSettings = createAsyncAction(
  SAVE_SETTINGS,
  async function(name, values) {
    const formData = new FormData()
    _(values).toPairs().each(([k, v], i) => formData.append(k, v))
    const response = await fetch(`/settings/values/${name}`, {
      method: 'POST',
      body: formData,
    })
    if (!response.ok) {
      return await processResponseError(response)
    }
  },
)

/**
 * Tasks
 */

export const runPostProcessor = createAsyncAction(
  RUN_POST_PROCESSOR,
  async function() {
    const response = await fetch(`/tasks/postprocess`, {
      method: 'POST',
    })
    if (!response.ok) {
      return await processResponseError(response)
    }
  }
)