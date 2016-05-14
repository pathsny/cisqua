'use strict';

import { createAction } from 'redux-actions'

/*
 * action types
 */

export const ADD_SHOW = 'ADD_SHOW'
export const FETCH_SHOWS = 'FETCH_SHOWS'

/*
 * async operations
 */


async function fetchShowsFromServer() {
  const response = await fetch('/shows')
  if (!response.ok) {
    throw new Error(response.statusText)
  }
  return await response.json()
}

async function addShowToServer(id, name, feed) {
  const formData = new FormData()
  formData.append('id', id)
  formData.append('name', name)
  formData.append('feed', feed)
  const response = await fetch('/shows/new', {
    method: 'POST',
    body: formData,
  })
  if (!response.ok) {
    throw new Error(response.statusText)
  }
  return await response.json() 
}

/*
 * action creators
 */

export const addShow = createAction(
  ADD_SHOW, 
  (id, ...args) => ({
    promise: addShowToServer(id, ...args),
    data: {id},
  })
);

export const fetchShows = createAction(
  FETCH_SHOWS,
  () => ({
    promise: fetchShowsFromServer(),
  }),
)