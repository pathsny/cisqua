'use strict';

import PropTypes from 'prop-types';
import React, { Component } from 'react';
import _ from 'lodash'
import invariant from 'invariant'
import { connect } from 'react-redux'
import Select from "react-select";
import { fieldInputPropTypes, fieldMetaPropTypes } from 'redux-form'

import {fetchSuggestionsFromAnidb} from '../actions'

const suggestions = [
  { label: 'Afghanistan' },
  { label: 'Aland Islands' },
  { label: 'Albania' },
  { label: 'Algeria' },
  { label: 'American Samoa' },
  { label: 'Andorra' },
  { label: 'Angola' },
  { label: 'Anguilla' },
  { label: 'Antarctica' },
  { label: 'Antigua and Barbuda' },
  { label: 'Argentina' },
  { label: 'Armenia' },
  { label: 'Aruba' },
  { label: 'Australia' },
  { label: 'Austria' },
  { label: 'Azerbaijan' },
  { label: 'Bahamas' },
  { label: 'Bahrain' },
  { label: 'Bangladesh' },
  { label: 'Barbados' },
  { label: 'Belarus' },
  { label: 'Belgium' },
  { label: 'Belize' },
  { label: 'Benin' },
  { label: 'Bermuda' },
  { label: 'Bhutan' },
  { label: 'Bolivia, Plurinational State of' },
  { label: 'Bonaire, Sint Eustatius and Saba' },
  { label: 'Bosnia and Herzegovina' },
  { label: 'Botswana' },
  { label: 'Bouvet Island' },
  { label: 'Brazil' },
  { label: 'British Indian Ocean Territory' },
  { label: 'Brunei Darussalam' },
].map(suggestion => ({
  value: suggestion.label,
  name: suggestion.label,
}));

class AnimeAutosuggestPresentation extends Component {
  static propTypes = {
    field: PropTypes.shape({
      input: PropTypes.shape({
        ...fieldInputPropTypes,
        value: PropTypes.shape({
          selection: PropTypes.object,
          // selection: PropTypes.shape({
          //   '@aid': PropTypes.string.isRequired,
          //   name: PropTypes.string.isRequired,
          // }),
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

  state = {
    searchText: '',
    selection: null,
  }

  constructor(props) {
    super(props)
    // this.state = initialState;
    // this._onChange = this._onChange.bind(this);
    // this._onSuggestionSelected = this._onSuggestionSelected.bind(this);
    // this._shouldSuggest = this._shouldSuggest.bind(this);
  }

  // componentWillReceiveProps(nextProps) {
  //   const {value: {suggestion, searchText}, suggestionMap} = nextProps
  //   invariant( // only the user can select an anime;
  //     !suggestion || suggestion.name === searchText,
  //     `invalid props being sent ${searchText} does not match ${suggestion && suggestion.name}`
  //   );
  //   if (suggestion) {
  //     return; // there is a valid suggestion and it matches the text.
  //   }
  //   if (!this._shouldSuggest(searchText)) {
  //     this.setState(initialState)
  //   } else {
  //     if (_.has(suggestionMap, searchText)) {
  //       this.setState({suggestions: suggestionMap[searchText]})
  //     } else {
  //       this.props.fetchSuggestions(searchText)
  //     }
  //   }
  // }

  // _onChange(newSearchText) {
  //   const {selection, searchText} = this.props.field.value
  //   const newSelection = (selection && selection.name === newSearchText) ?
  //     selection :
  //     _.find(this.state.suggestions, s => s.name === newSearchText) // might be null
  //   this.props.onChange(null, {searchText: newSearchText, selection: newSelection});
  // }

  _shouldSuggest(searchText) {
    return searchText.trim().length >= 2;
  }

  _handleInputChange = (searchText, details) => {
    if (details.action === "input-change") {
      this.setState({searchText});
      // console.log("the input is ", searchText, " and ", details);
      // this.props.field.input.onChange({
      //   ...this.props.field.input.value,
      //   searchText,
      // });
    }
  }

  _handleSelection = (selection, ...args) => {
    console.log("I got ", selection, ...args);
    this.setState({
      searchText: selection?.name || '',
      selection,
    });
    // this.props.field.input.onChange({
    //   searchText: selection?.name || '',
    //   selection
    // });
  }

  // _onSuggestionSelected(name, index) {
  //   this.props.onChange(null, {
  //     // note there is a small chance of a race condition,
  //     // if the selection is made before we render, but after setting state
  //     // or if between the user selecting and this callback firing, state is changed
  //     suggestion: this.state.suggestions[index],
  //     searchText: name,
  //   })
  // }

  render() {
    const {hintsBeingFetched, suggestionMap, field} = this.props
    // const isLoading = _.has(hintsBeingFetched, field.input.value.searchText)
    const {searchText, selection} = this.state;
    // const status = (isLoading ? 'Loading...' : 'Type to load suggestions');
    console.log("starting render with ", searchText, selection)
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

        // onChange={(selected_option, selection_meta, ...args) => {
        //     anime.input.onChange(selected_option);
        //        }}
        autoFocus={this.props.autoFocus}
        onBlurResetsInput={false}
        isClearable
      />

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
