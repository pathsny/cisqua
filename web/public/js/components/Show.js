'use strict';

import React, { PropTypes, Component } from 'react';
import {Card, CardActions, CardHeader, CardText} from 'material-ui/Card';
import RaisedButton from 'material-ui/RaisedButton';
import FlatButton from 'material-ui/FlatButton';
import {
  Table, 
  TableBody, 
  TableHeader, 
  TableHeaderColumn, 
  TableRow, 
  TableRowColumn,
} from 'material-ui/Table';

import { connect } from 'react-redux'

import {ShowPropType, FeedItemPropType} from './proptypes.js'
import {checkFeed, removeShow } from '../actions.js'

class ShowPresentation extends Component {
  constructor(props) {
    super(props)    
  }

  _avatarURL() {
    return `/anidb/thumb/${this.props.anime.id}.jpg`
  }

  _renderFeedItem(feedItem) {
    return (
      <TableRow key={feedItem.id}>
        <TableRowColumn>{feedItem.title}</TableRowColumn>
      </TableRow>
    );
  }

  render() {
    return (
      <Card>
        <CardHeader
          title={this.props.anime.name}
          avatar={this._avatarURL()}
          actAsExpander={true}
        >
        </CardHeader>
        <CardText expandable={false}>
         <Table fixedHeader={true}>
            <TableHeader 
              adjustForCheckbox={false}
              displaySelectAll={false}>
              <TableRow>
                <TableHeaderColumn>Name</TableHeaderColumn>
                <TableHeaderColumn></TableHeaderColumn>
              </TableRow>
            </TableHeader>
            <TableBody displayRowCheckbox={false}>
              {this.props.feedItems.map(this._renderFeedItem)}
            </TableBody>
          </Table>
        </CardText>
        <CardActions>
          <FlatButton label="Remove Show" onTouchTap={this.props.onRemoveShow}/>
        </CardActions>
      </Card>
    )
  } 
}

ShowPresentation.propTypes = {
  anime: ShowPropType.isRequired,
  feedItems: PropTypes.arrayOf(FeedItemPropType.isRequired).isRequired,
}

const mapStateToProps = (state, ownProps) => ({
  feedItems: ownProps.anime.feed_items.map(id => state.app.feedItemsByID[id]),
});

const mapDispatchToProps = (dispatch, ownProps) => ({
  onCheckFeed: () => dispatch(checkFeed(ownProps.anime.id)),
  onRemoveShow: () => dispatch(removeShow(ownProps.anime.id)),
})

const Show = connect(
  mapStateToProps,
  mapDispatchToProps,
)(ShowPresentation)

export default Show