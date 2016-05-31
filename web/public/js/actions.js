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
export const ADD_SHOW_DIALOG = 'ADD_SHOW_DIALOG'
export const FETCH_SUGGESTIONS = 'FETCH_SUGGESTIONS'
export const DISMISS_SNACKBAR = 'DISMISS_SNACKBAR'

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
 * fetch Show List
 */

export const fetchShows = createAsyncAction(
  FETCH_SHOWS,
  async function() {
    return await processJSONResponse(fetch('/shows')) 
  },
  thunkCreationUtil((actionCreator, dispatch, getState) => {
    if (!getState().app.fetching.list) {
      dispatch(actionCreator());
    }
  }),  
);

/*
 * Add new Show
 */

export const addShow = createAsyncAction(
  ADD_SHOW,
  async function(id, name, feed_url, auto_fetch) {
    const formData = new FormData()
    formData.append('id', id)
    formData.append('name', name)
    formData.append('feed_url', feed_url)
    formData.append('auto_fetch', auto_fetch)
    return await processJSONResponse(fetch('/shows/new', {
      method: 'POST',
      body: formData,
    }))
  },
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
  (hint) => ({hint: hint}),
);  
