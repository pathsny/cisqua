'use strict';

import React, { PropTypes, Component } from 'react';
import _ from 'lodash'

import AnimeAutosuggest from './AnimeAutosuggest.js'
import {getAnidbTitle} from './anidb_utils.js'

const initialState = {
  selectedAnime: null,
  feed_url: '',
  lastSelectionByUser: false,
};

export default class NewShowForm extends Component {
  constructor(props) {
    super(props)
    this.state = initialState;
    this._onFeedUrlChange = this._onFeedUrlChange.bind(this);
    this._onAnimeSelection = this._onAnimeSelection.bind(this);
    this._addShow = this._addShow.bind(this);
  }

  _onFeedUrlChange(event) {
    this.setState({feed_url: event.target.value});
  }

  _onAnimeSelection(anime) {
    this.setState({
      selectedAnime: anime,
      lastSelectionByUser: true,
    });
  }

  _shouldDisableButton() {
    return !this.state.selectedAnime || this.state.feed_url === '';
  }

  _addShow() {
    this.props.onAddShow(
      _.parseInt(this.state.selectedAnime['@aid']),
      getAnidbTitle(this.state.selectedAnime),
      this.state.feed_url,
    );
    // this.setState(initialState);
  }

  render() {
    return (
        <div>
          <h2>Add a New Show</h2>
          <AnimeAutosuggest
            lastSelectionByUser={this.state.lastSelectionByUser}
            selectedAnime={this.state.selectedAnime}
            onAnimeSelection={this._onAnimeSelection}
          />
          <label for="feed_url">Feed URL</label>
          <input 
            id="feed_url" 
            value={this.state.feed_url}
            onChange={this._onFeedUrlChange}
          />
          <button 
            disabled={this._shouldDisableButton()} 
            onClick={this._addShow}>
            Add
          </button>
        </div>  
    );  
  }
}

NewShowForm.propTypes = {
  onAddShow: PropTypes.func.isRequired
}

