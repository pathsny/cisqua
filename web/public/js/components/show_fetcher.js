'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import { connect } from 'react-redux'
import _ from 'lodash'

import { fetchShows, fetchShow } from '../actions'

const SlowRefreshTime = 5*60*1000;
const FastRefreshTime = 10*1000;
const ShowRefreshTime = 2000;

const InitialState = {
  listTimer: null,
  showTimers: {},
}

class ShowFetcherPresentation extends Component {
  constructor(props) {
    super(props)
    this.state = InitialState
  }

  componentWillMount() {
    this.props.onFetchShows();
  }

  componentWillUnmount() {
    this._clearAllTimers();
    this.setState(InitialState);
  }

  componentWillReceiveProps(nextProps) {
    if (nextProps.fetchingList) {
      // everything is updating anyway
      this._clearAllTimers();
      this.setState(InitialState);
      return
    }
    if (nextProps.isUpdatingFeedItemsForAllShows) {
      // no point updating each show, fetch list aggressively
      this._clearAllTimers();
      this.setState({listTimer: this._setListTimer(FastRefreshTime)});  
      return
    }
    // Set ListTimer to slow and custom rates for updating shows
    const listTimer = !_.isNull(this.state.listTimer) || this._setListTimer(SlowRefreshTime);
    const showTimers = this._updateShowTimers(nextProps);
    this.setState({listTimer, showTimers});
  }

  _showIDsToFetch(nextProps) {
    return _.difference(nextProps.updatingShows, nextProps.fetchingShows)
  }

  _updateShowTimers(nextProps) {
    const idsToFetch = this._showIDsToFetch(nextProps)
    const validTimers = _.pick(this.state.showTimers, idsToFetch)
    const newTimers = _(idsToFetch)
      .reject(id => _.has(validTimers, id))
      .map(id => [id, window.setTimeout(
        () => this.props.onFetchShow(id),
        ShowRefreshTime,
      )])
      .fromPairs()
      .value();
    const invalidTimers = _.omit(this.state.showTimers, idsToFetch)
    this._clearShowTimers(invalidTimers)
    return Object.assign({},validTimers, newTimers);
  }

  _setListTimer(refreshTime) {
    return window.setTimeout(
      () => this.props.onFetchShows(),
      refreshTime,
    );
  }    

  _clearShowTimers(timers) {
    _(timers).each(t => window.clearTimeout(t))
  }

  _clearAllTimers() {
    window.clearTimeout(this.state.listTimer)
    this._clearShowTimers(_.values(this.state.showTimers))
  } 

  render() {
    return null;
  }
}

const mapStateToProps = (state) => ({
  fetchingList: state.app.async.showList,
  fetchingShows: _.keys(state.app.async.showsByID),
  isUpdatingFeedItemsForAllShows: state.app.isUpdatingFeedItemsForAllShows,
  updatingShows: _.filter(
    state.app.showsByID,
    s => s.is_updating_feed_items,
  ).map(s => s.id),  
})

const mapDispatchToProps = (dispatch) => ({
  onFetchShows: () => dispatch(fetchShows()),
  onFetchShow: (id) => dispatch(fetchShow(id)), 
})


const ShowFetcher = connect(
  mapStateToProps,
  mapDispatchToProps,
)(ShowFetcherPresentation)

export default ShowFetcher  