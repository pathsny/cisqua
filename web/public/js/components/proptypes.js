'use strict';

import { PropTypes } from 'react'

export const ShowPropType = PropTypes.shape({
  id: PropTypes.number.isRequired,
  name: PropTypes.string.isRequired,
  feed_url: PropTypes.string.isRequired,
})