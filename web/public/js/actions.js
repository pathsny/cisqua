'use strict';

import { createAction } from 'redux-actions'
import ExtendableError from 'es6-error';

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

const addShow = createAction(ADD_SHOW);

const addShowDialog = createAction(ADD_SHOW_DIALOG);

/*
 * action creators
 */

export { 
  fetchShowsSmart, 
  // fetchSuggestionsFromAnidbSmart, 
  addShow, 
  addShowDialog,
  addShowToServer,
}
