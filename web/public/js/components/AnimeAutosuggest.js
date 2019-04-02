'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import _ from 'lodash'
import invariant from 'invariant'
import { connect } from 'react-redux'
// import AutoComplete from '@material-ui/core/AutoComplete';

import {fetchSuggestionsFromAnidb} from '../actions'

const initialState = {
  suggestions: [],
};

class AnimeAutosuggestPresentation extends Component {
  constructor(props) {
    super(props)
    this.state = initialState;
    this._onChange = this._onChange.bind(this);
    this._onSuggestionSelected = this._onSuggestionSelected.bind(this);
    this._shouldSuggest = this._shouldSuggest.bind(this);
  }

  componentWillReceiveProps(nextProps) {
    const {value: {suggestion, searchText}, suggestionMap} = nextProps
    invariant( // only the user can select an anime;
      !suggestion || suggestion.name === searchText,
      `invalid props being sent ${searchText} does not match ${suggestion && suggestion.name}`
    );
    if (suggestion) {
      return; // there is a valid suggestion and it matches the text.
    }
    if (!this._shouldSuggest(searchText)) {
      this.setState(initialState)
    } else {
      if (_.has(suggestionMap, searchText)) {
        this.setState({suggestions: suggestionMap[searchText]})
      } else {
        this.props.fetchSuggestions(searchText)
      }
    }
  }

  _onChange(newSearchText) {
    const {suggestion, searchText} = this.props.value
    const newSuggestion = (suggestion && suggestion.name === newSearchText) ?
      suggestion :
      _.find(this.state.suggestions, s => s.name === newSearchText) // might be null
    this.props.onChange(null, {searchText: newSearchText, suggestion: newSuggestion});
  }

  _shouldSuggest(searchText) {
    return searchText.trim().length >= 2;
  }

  _onSuggestionSelected(name, index) {
    this.props.onChange(null, {
      // note there is a small chance of a race condition,
      // if the selection is made before we render, but after setting state
      // or if between the user selecting and this callback firing, state is changed
      suggestion: this.state.suggestions[index],
      searchText: name,
    })
  }

  render() {
    const isLoading = _.has(this.state.hintsBeingFetched, this.props.searchText)
    const status = (isLoading ? 'Loading...' : 'Type to load suggestions');
    return (<div/>
      // <AutoComplete
      //   dataSource={this.state.suggestions.map(s => s.name)}
      //   filter={AutoComplete.noFilter} // fuzzyFilter works for us, but has not been released yet
      //   onNewRequest={this._onSuggestionSelected}
      //   onUpdateInput={this._onChange}
      //   searchText={this.props.searchText}
      //   openOnFocus={true}
      //   {..._.omit(this.props, ['value', 'onChange', 'suggestionMap', 'hintsBeingFetched'])}
      // />
    );
  }
}

//(if selectedAnime is null and was not done by the user
// that means we cleared the component)

AnimeAutosuggestPresentation.propTypes = {
  value: PropTypes.shape({
    suggestion: PropTypes.shape({
      '@aid': PropTypes.string.isRequired,
      name: PropTypes.string.isRequired,
    }),
    searchText: PropTypes.string.isRequired,
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
  hintsBeingFetched: state.autosuggest.async,
});

const mapDispatchToProps = (dispatch) => ({
  fetchSuggestions: (hint) => dispatch(fetchSuggestionsFromAnidb(hint))
})

const AnimeAutosuggest = connect(
  mapStateToProps,
  mapDispatchToProps,
)(AnimeAutosuggestPresentation)

export default AnimeAutosuggest
