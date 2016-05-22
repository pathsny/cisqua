'use strict';

import React, { PropTypes, Component } from 'react';
import Autosuggest from 'react-autosuggest';
import xml from 'xml-to-json/xml.js'
import _ from 'lodash'
import invariant from 'invariant'
import theme from '../../styles/Autosuggest.css'

import {asArray, getAnidbTitle} from '../utils/anidb_utils.js'

const fixedInputProps = {
  placeholder: 'Show Name',
  type: 'search',
  name: 's',
};

const initialState = {
  value: '', 
  suggestions: [],
  isLoading: false,
};

export default class AnimeAutosuggest extends Component {
  constructor(props) {
    super(props)
    this.state = initialState;
    this._onChange = this._onChange.bind(this);
    this._onSuggestionsUpdateRequested = this._onSuggestionsUpdateRequested.bind(this);
    this._renderSuggestion = this._renderSuggestion.bind(this);
    this._suggestionValue = this._suggestionValue.bind(this);
    this._onSuggestionSelected = this._onSuggestionSelected.bind(this);
    this._shouldSuggest = this._shouldSuggest.bind(this);
    this._updateSuggestions = _.debounce(
      this._updateSuggestions.bind(this),
      300,
    );
  }

  componentWillReceiveProps(nextProps) {
    invariant( // only the user can select an anime;
      nextProps.value.lastSelectionByUser || 
      nextProps.value.anime === null,
      `invalid props being sent ${nextProps}`
    );
    if (!nextProps.value.lastSelectionByUser && this.props.value.anime !== null) {
      // this condition implies that we are clearing the selection
      this.setState(initialState);
    }
  }

  _onChange(event, { newValue }) {
    this.setState({value: newValue});
  }

  _shouldSuggest(value) {
    return value.trim().length >= 2;
  }

  _onSuggestionsUpdateRequested({ value }) {
    if (this._shouldSuggest(value)) {
      this._updateSuggestions(value);  
      this.setState({
        isLoading: true,
      });
    } else {
      this.setState({isLoading: false});
    }
  }

  async _updateSuggestions(value) {
    const query = value.trim().replace(/[\s]+/g, ' ').split(' ').
      map(w => `%2B${w}*`).join(' ');
    const url = 'http://anisearch.outrance.pl/?task=search&query=' + query;
    const response = await fetch(url)
    const text = await response.text();
    if (!this.state.isLoading) {
      return // we took too long to load suggestions, but now the user isnt waiting
      // either the user cleared the text, or has made a selection
    }
    const xmlData = xml.xmlToJSON(text);
    const animes = asArray(xmlData.animetitles.anime);
    if (this.state.value === value) {
      // we fetched what the user asked for
      this.setState({suggestions: animes, isLoading: false});  
    } else {
      // these selections are stale, we can display them though as long as there is a spinner
      this.setState({suggestions: animes, isLoading: true});  
    }
  }

  _renderSuggestion(anime) {
    return getAnidbTitle(anime);
  }

  _suggestionValue(anime) {
    return anime !== '' ? getAnidbTitle(anime) : '';
  }

  _onSuggestionSelected(event, {suggestion}) {
    this.props.onChange(suggestion)
    event.preventDefault();
  }

  render() {
    const { value, suggestions, isLoading } = this.state;
    const status = (isLoading ? 'Loading...' : 'Type to load suggestions');
    const inputProps = { ...fixedInputProps, value, onChange: this._onChange}; 
    return (
      <Autosuggest
        suggestions={suggestions}
        onSuggestionsUpdateRequested={this._onSuggestionsUpdateRequested}
        getSuggestionValue={this._suggestionValue}
        renderSuggestion={this._renderSuggestion}
        inputProps={inputProps}
        shouldRenderSuggestions={this._shouldSuggest}
        onSuggestionSelected={this._onSuggestionSelected}
        theme={theme}
      />
    );  
  }
}

//(if selectedAnime is null and was not done by the user
// that means we cleared the component)

AnimeAutosuggest.propTypes = {
  value: PropTypes.shape({
    anime: PropTypes.shape({
      '@aid': PropTypes.string.isRequired
    }),
    lastSelectionByUser: PropTypes.bool.isRequired,
  }).isRequired,
  onChange: PropTypes.func.isRequired,
}
