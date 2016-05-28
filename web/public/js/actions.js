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

/*
 * async operations
 */

/*
 * fetch Show List
 */

async function fetchShowsFromServer() {
  return await processJSONResponse(fetch('/shows'))
}

const fetchShowsAction = createAction(
  FETCH_SHOWS,
  () => ({promise: fetchShowsFromServer()}),
)

function fetchShowsSmart() {
  return (dispatch, getState) => {
    const state = getState();
    if (!state.app.fetching.list) {
      dispatch(fetchShowsAction());
    }
  }
}

/*
 * Add new Show
 */

const addShow = createAction(ADD_SHOW);

async function addShowToServer(id, name, feed, auto_fetch) {
  const formData = new FormData()
  formData.append('id', id)
  formData.append('name', name)
  formData.append('feed', feed)
  formData.append('auto_fetch', auto_fetch)
  return await processJSONResponse(fetch('/shows/new', {
    method: 'POST',
    body: formData,
  }))
}

const addShowDialog = createAction(ADD_SHOW_DIALOG);

/*
 * Fetch Suggestions for Autosuggest
 */

async function fetchSuggestionsFromAnidb(hint) {
  const query = hint.trim().replace(/[\s]+/g, ' ').split(' ').
    map(w => `%2B${w}*`).join(' ');
  const url = 'http://anisearch.outrance.pl/?task=search&query=' + query;
  const response = await fetch(url)
  const text = await response.text();
  const xmlData = xml.xmlToJSON(text);
  return asArray(xmlData.animetitles.anime);
}

const fetchSuggestionsAction = createAction(
  FETCH_SUGGESTIONS,
  (hint) => ({promise: fetchSuggestionsFromAnidb(hint)}),
  (hint) => ({hint: hint}),
)

const debouncedFetchSuggestions = _.debounce(
  (dispatch, hint)  => dispatch(fetchSuggestionsAction(hint)),
  300,
);

function fetchSuggestionsFromAnidbSmart(hint) {
  return (dispatch, getState) => {
    const state = getState();
    if (!(
      _.has(state.autosuggest.fetching, hint) ||
      _.has(state.autosuggest.suggestions, hint)
    )) {
      debouncedFetchSuggestions(dispatch, hint)
    }
  }
}

/*
 * exported action creators
 */

export { 
  fetchShowsSmart, 
  fetchSuggestionsFromAnidbSmart, 
  addShowDialog,
  addShowToServer,
  addShow,
}
