'use strict';

import _ from 'lodash'

function sortFieldsEqual(oldShow, show) {
  return oldShow.created_at === show.created_at
}

export const ShowSorter = {
  sortShows: function(shows) {
    return _.orderBy(
      shows,
      [(s) => s.created_at],
      ['desc'], 
    );
  },
  mergeSorted: function(oldShows, oldShow, show) {
    if (oldShow && sortFieldsEqual(oldShow, show)) {
      return oldShows
    }
    return this.sortShows([
      ...(_.reject(oldShows, s => s.id === show.id)),
      show,
    ]);
  },  
}

export const FeedItemSorter = {
  sortFeedItems: function(feedItems) {
    return _.orderBy(
      feedItems,
      [(f) => f.published_at],
      ['desc'],
    )
  }
}