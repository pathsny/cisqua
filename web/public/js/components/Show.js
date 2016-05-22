'use strict';

import React, { PropTypes, Component } from 'react';
import {Card, CardActions, CardHeader, CardText} from 'material-ui/Card';
import {ShowPropType} from './proptypes.js'

class Show extends Component {
  constructor(props) {
    super(props)    
  }

  _avatarURL() {
    return `/anidb/thumb/${this.props.anime.id}.jpg`
  }

  render() {
    return (
      <Card>
        <CardHeader
          title={this.props.anime.name}
          // avatar={this._avatarURL()}
        >
        </CardHeader>
      </Card>
    )
  } 
}

Show.propTypes = {
  anime: ShowPropType.isRequired
}

export default Show 