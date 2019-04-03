'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import {Card, CardActions, CardHeader, CardText} from '@material-ui/core/Card';
import Button from '@material-ui/core/Button';
import CircularProgress from '@material-ui/core/CircularProgress';
import FileCloudDownload from '@material-ui/icons/CloudDownload';
import ContentArchive from '@material-ui/icons/Archive';

import {grey500, green800} from '@material-ui/core/colors';

import {
  Table,
  TableBody,
  TableHeader,
  TableHeaderColumn,
  TableRow,
  TableRowColumn,
} from '@material-ui/core/Table';

import { connect } from 'react-redux'

import {ShowPropType, FeedItemPropType} from './proptypes.js'
import {
  checkFeed,
  removeShow,
  downloadFile,
  markDownloaded,
  unmarkDownloaded,
} from '../actions.js'

function getColors(theme, active) {
  const inactiveColor = theme.palette.accent3Color
  return {
    download: active ? green800 : inactiveColor,
    markDownloaded: active ? theme.palette.accent1Color : inactiveColor,
  }
}

class ShowPresentation extends Component {
  constructor(props) {
    super(props)
  }

  _avatarURL() {
    return `/anidb/thumb/${this.props.anime.id}.jpg`
  }

  _renderMarkDownloadedButton(feedItem, colors) {
    return feedItem.async.markDownloaded ?
      <CircularProgress
        size={0.25}
      /> :
    (
      <IconButton
        tooltip={feedItem.marked_predownloaded_at ? "Unmark Downloaded" : "Mark Downloaded"}
        tooltipPosition="top-right"
        onClick={() => (
          feedItem.marked_predownloaded_at ?
          this.props.onUnmarkDownloaded :
          this.props.onMarkDownloaded
        )(feedItem.id)}
      >
        <ContentArchive color={colors.markDownloaded}/>
      </IconButton>
    )
  }

  _renderDownloadButton(feedItem, colors) {
    return feedItem.async.download ?
      <CircularProgress
        size={0.25}
      /> :
    (
      <IconButton
        tooltip="Download"
        tooltipPosition="top-right"
        touch={true}
        onClick={() => this.props.onDownload(feedItem.id)}
      >
        <FileCloudDownload color={colors.download}/>
      </IconButton>
      )
  }

  _renderFeedItem(feedItem) {
    const colors = getColors(
      this.context.muiTheme,
      !feedItem.downloaded_at && !feedItem.marked_predownloaded_at,
    )
    return (
      <TableRow key={feedItem.id}>
        <TableRowColumn>{feedItem.title}</TableRowColumn>
        <TableRowColumn>
          {this._renderDownloadButton(feedItem, colors)}
        </TableRowColumn>
        <TableRowColumn>
          {this._renderMarkDownloadedButton(feedItem, colors)}
        </TableRowColumn>
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
         <Table fixedHeader={true} selectable={false}>
            <TableHeader
              adjustForCheckbox={false}
              displaySelectAll={false}>
              <TableRow>
                <TableHeaderColumn>Name</TableHeaderColumn>
                <TableHeaderColumn></TableHeaderColumn>
              </TableRow>
            </TableHeader>
            <TableBody displayRowCheckbox={false}>
              {this.props.feedItems.map((item) => this._renderFeedItem(item))}
            </TableBody>
          </Table>
        </CardText>
        <CardActions>
          <Button
            label="Remove Show"
            onClick={this.props.onRemoveShow}
            variant='outlined'
          />
        </CardActions>
      </Card>
    )
  }
}

ShowPresentation.contextTypes = {
  muiTheme: PropTypes.object.isRequired
}

ShowPresentation.propTypes = {
  anime: ShowPropType.isRequired,
  feedItems: PropTypes.arrayOf(FeedItemPropType.isRequired).isRequired,
  onCheckFeed: PropTypes.func.isRequired,
  onRemoveShow: PropTypes.func.isRequired,
  onDownload: PropTypes.func.isRequired,
  onMarkDownloaded: PropTypes.func.isRequired,
  onUnmarkDownloaded: PropTypes.func.isRequired,
}

const mapStateToProps = (state, ownProps) => ({
  feedItems: ownProps.anime.feed_items.map(
    id => Object.assign(
      {},
      state.app.feedItemsByID[id],
      {async: {
        markDownloaded: _.get(state.app.async.feedItemsByID[id], 'markDownloaded', false),
        download: _.get(state.app.async.feedItemsByID[id], 'download', false),
      }},
    ),
  )
});

const mapDispatchToProps = (dispatch, ownProps) => ({
  onCheckFeed: () => dispatch(checkFeed(ownProps.anime.id)),
  onRemoveShow: () => dispatch(removeShow(ownProps.anime.id)),
  onDownload: (id) => dispatch(downloadFile(ownProps.anime.id, id)),
  onMarkDownloaded: (id) => dispatch(markDownloaded(ownProps.anime.id, id)),
  onUnmarkDownloaded: (id) => dispatch(unmarkDownloaded(ownProps.anime.id, id)),
})

const Show = connect(
  mapStateToProps,
  mapDispatchToProps,
)(ShowPresentation)

export default Show
