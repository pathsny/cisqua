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

/*
 * Utilties
 */

export class JSONResponseCarryingError extends ExtendableError {
  constructor(message, json) {
    super(message)
    this.payload = json
  }
}

async function processJSONResponse(responsePromise) {
  const response = await responsePromise
  if (response.ok) {
    return await response.json()
  }
  let errorJSON;
  try {
    // if the bad response has json, throw the json. It contains useful info 
    errorJSON = await response.json();
  } catch (e) {
    throw new Error(response.statusText)  
  }
  throw new JSONResponseCarryingError(response.statusText, errorJSON) 
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

export const addShow = createAction(ADD_SHOW);

export async function addShowToServer(id, name, feed_url, auto_fetch) {
  const formData = new FormData()
  formData.append('id', id)
  formData.append('name', name)
  formData.append('feed_url', feed_url)
  formData.append('auto_fetch', auto_fetch)
  return await processJSONResponse(fetch('/shows/new', {
    method: 'POST',
    body: formData,
  }))
}

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
