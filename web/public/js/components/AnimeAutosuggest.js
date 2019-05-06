'use strict';

import PropTypes from 'prop-types';
import React, { Component } from 'react';
import _ from 'lodash'
import invariant from 'invariant'
import { connect } from 'react-redux'
import Select from "react-select";
import { fieldInputPropTypes, fieldMetaPropTypes } from 'redux-form'

import {fetchSuggestionsFromAnidb} from '../actions'

class AnimeAutosuggestPresentation extends Component {
  static propTypes = {
    field: PropTypes.shape({
      input: PropTypes.shape({
        ...fieldInputPropTypes,
        value: PropTypes.shape({
          selection: PropTypes.shape({
            '@aid': PropTypes.string.isRequired,
            name: PropTypes.string.isRequired,
          }),
          searchText: PropTypes.string.isRequired,
        }).isRequired,
      }).isRequired,
      meta: PropTypes.shape(fieldMetaPropTypes).isRequired
    }),
    suggestionMap: PropTypes.objectOf(
      PropTypes.array.isRequired
    ).isRequired,
    hintsBeingFetched: PropTypes.objectOf(
      PropTypes.string.isRequired
    ).isRequired,
    fetchSuggestions: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props)
  }

  _shouldSuggest = (searchText) => {
    return searchText.trim().length >= 2;
  }

  _handleInputChange = (searchText, details) => {
    if (details.action === "input-change") {
      this.props.field.input.onChange({
        ...this.props.field.input.value,
        searchText,
      });
      if (
        !this._shouldSuggest(searchText) ||
        _.has(this.props.suggestionMap, searchText) ||
        _.has(this.props.hintsBeingFetched, searchText)
      ) {
        return;
      } else {
        this.props.fetchSuggestions(searchText);
      }
    }
  }

  _handleSelection = (selection, ...args) => {
    this.props.field.input.onChange({
      searchText: '',
      selection
    });
  }

  render() {
    const {hintsBeingFetched, suggestionMap, field} = this.props
    const {searchText, selection} = field.input.value
    const isLoading = this._shouldSuggest(searchText) && !_.has(suggestionMap, searchText);
    const suggestions = _.has(suggestionMap, searchText) ? suggestionMap[searchText] : [];
    return (
      <Select
        name={field.input.name}
        onFocus={field.input.onFocus}
        onBlur={() => {}}
        inputValue={searchText}
        value={selection}
        onInputChange={this._handleInputChange}
        onChange={this._handleSelection}
        placeholder="Search for a show"
        options={suggestions}
        getOptionLabel={(option) => option.name}
        autoFocus={this.props.autoFocus}
        onBlurResetsInput={false}
        isLoading={isLoading}
        isClearable
      />
    );
  }
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
