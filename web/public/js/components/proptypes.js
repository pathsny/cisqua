'use strict';

import { PropTypes } from 'react'

export const ShowPropType = PropTypes.shape({
  id: PropTypes.string.isRequired,
  name: PropTypes.string.isRequired,
  feed_url: PropTypes.string.isRequired,
  auto_fetch: PropTypes.bool.isRequired,
  feed_items: PropTypes.arrayOf(PropTypes.string.isRequired).isRequired,
  is_updating_feed_items: PropTypes.bool.isRequired,
  last_checked_at: PropTypes.object,
  latest_feed_item_added_at: PropTypes.object,
})

export const FeedItemPropType = PropTypes.shape({
  id: PropTypes.string.isRequired,
  url: PropTypes.string.isRequired,
  title: PropTypes.string.isRequired,
  published_at: PropTypes.object.isRequired,
  summary: PropTypes.string.isRequired,
  downloaded_at: PropTypes.object,
  hidden_at: PropTypes.object,
  marked_predownloaded_at: PropTypes.object,
})