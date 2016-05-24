'use strict';

import React, { PropTypes, Component } from 'react';
import Autosuggest from 'react-autosuggest';
import _ from 'lodash'
import invariant from 'invariant'
import { connect } from 'react-redux'
import theme from '../../styles/Autosuggest.css'

import {fetchSuggestionsFromAnidbSmart} from '../actions'

const fixedInputProps = {
  placeholder: 'Show Name',
  type: 'search',
  name: 's',
};

const initialState = {
  value: '', 
  suggestions: [],
};

export default class AnimeAutosuggestPresentation extends Component {
  constructor(props) {
    super(props)
    this.state = initialState;
    this._onChange = this._onChange.bind(this);
    this._onSuggestionsUpdateRequested = this._onSuggestionsUpdateRequested.bind(this);
    this._onSuggestionSelected = this._onSuggestionSelected.bind(this);
    this._shouldSuggest = this._shouldSuggest.bind(this);
    this._renderSuggestion = this._renderSuggestion.bind(this);
    this._suggestionValue = this._suggestionValue.bind(this);
  }

  componentWillReceiveProps(nextProps) {
    invariant( // only the user can select an anime;
      nextProps.value.lastSelectionByUser || 
      nextProps.value.anime === null,
      `invalid props being sent ${nextProps}`
    );
    if (_.has(nextProps.suggestionMap, this.state.value)) {
      this.setState({
        suggestions: nextProps.suggestionMap[this.state.value],
      });
    }
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
      this.props.fetchSuggestions(value)
    }
  }

  _suggestionValue(suggestion) {
    return suggestion.text
  }

  _onSuggestionSelected(event, {suggestion: {value}}) {
    this.props.onChange(event, {
      suggestion: value,
      lastSelectionByUser: true,
    })
    event.preventDefault();
  }

  _renderSuggestion(suggestion) {
    return suggestion.text
  }

  render() {
    const { value, suggestions } = this.state;
    const isLoading = _.has(this.state.hintsBeingFetched, this.state.value)
    const status = (isLoading ? 'Loading...' : 'Type to load suggestions');
    const inputProps = { ...fixedInputProps, value, onChange: this._onChange}; 
    return (
      <Autosuggest
        suggestions={suggestions.map(s => ({text: s.name, value: s}))}
        onSuggestionsUpdateRequested={this._onSuggestionsUpdateRequested}
        getSuggestionValue={this._suggestionValue}
        inputProps={inputProps}
        renderSuggestion={this._renderSuggestion}
        shouldRenderSuggestions={this._shouldSuggest}
        onSuggestionSelected={this._onSuggestionSelected}
        theme={theme}
      />
    );  
  }
}

//(if selectedAnime is null and was not done by the user
// that means we cleared the component)

AnimeAutosuggestPresentation.propTypes = {
  value: PropTypes.shape({
    anime: PropTypes.shape({
      '@aid': PropTypes.string.isRequired
    }),
    lastSelectionByUser: PropTypes.bool.isRequired,
  }).isRequired,
  onChange: PropTypes.func.isRequired,
  suggestionMap: PropTypes.objectOf(
    PropTypes.array.isRequired
  ).isRequired,
  hintsBeingFetched: PropTypes.objectOf(
    PropTypes.string.isRequired
  ).isRequired,
  fetchSuggestions: PropTypes.func.isRequired,
}

const mapStateToProps = (state) => ({
  suggestionMap: state.autosuggest.suggestions,
  hintsBeingFetched: state.autosuggest.fetching,
});

const mapDispatchToProps = (dispatch) => ({
  fetchSuggestions: (hint) => dispatch(fetchSuggestionsFromAnidbSmart(hint)) 
})

const AnimeAutosuggest = connect(
  mapStateToProps,
  mapDispatchToProps,
)(AnimeAutosuggestPresentation)

export default AnimeAutosuggest
