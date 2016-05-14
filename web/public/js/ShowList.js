'use strict';

import React, { PropTypes } from 'react'

import Show from './Show'
import {ShowPropType} from './proptypes'

const ShowList = ({ shows }) => (
  <ul>
    {shows.map(show =>
      <Show
        key={show.id}
        anime={show}
      />
    )}
  </ul>
)

ShowList.propTypes = {
  shows: PropTypes.arrayOf(ShowPropType.isRequired).isRequired,
}

export default ShowList