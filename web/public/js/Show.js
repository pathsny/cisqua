'use strict';

import React, { PropTypes } from 'react'

import {ShowPropType} from './proptypes.js'

const Show = ({anime}) => {
  return <li>{anime.name}</li>
}

Show.propTypes = {
  anime: ShowPropType.isRequired
}

export default Show 