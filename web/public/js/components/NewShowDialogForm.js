import React, { PropTypes, Component } from 'react'
import Dialog from 'material-ui/Dialog';
import { connect } from 'react-redux'
import { Field, reduxForm } from 'redux-form'
import { SubmissionError } from 'redux-form'; 
import FlatButton from 'material-ui/FlatButton';
import RaisedButton from 'material-ui/RaisedButton';
import TextField from 'material-ui/TextField';
import Toggle from 'material-ui/Toggle';

import _ from 'lodash'

import AnimeAutosuggest from './AnimeAutosuggest.js'
import {addShowToServer, addShowDialog, JSONResponseCarryingError, addShow} from '../actions.js'

async function onSubmit(values, dispatch) {
  try {
    const anime = values.anime.suggestion
    const result = await addShowToServer(
      _.parseInt(anime['@aid']),
      anime.name,
      values.feed_url,
      values.auto_fetch,  
    );
    return dispatch(addShow(result))
  } catch (e) {
    if (e instanceof JSONResponseCarryingError) {
      const errorJSON = e.payload
      let resultJson = {}
      for (let k of _.keys(errorJSON)) {
        const key = ['id', 'name'].includes(k) ? 'anime' : k
        resultJson[key] = errorJSON[k][0] 
      }
      throw new SubmissionError(resultJson)
    } else {
      throw e
    }
  }
}

const validate = values => {
  const errors = {}
  if (!values.feed_url) {
    errors.feed_url = 'Feed URL Required'
  }
  if (!values.anime.suggestion) {
    errors.anime = 'Anime Required'
  }
  return errors
}

const initialValues = {
  anime: {
    suggestion: null,
    searchText: '',
  },
  feed_url: '',
  auto_fetch: true,
}

class NewShowDialogFormPresentation extends Component {
  _getActions() {
    return [
      <Field name="auto_fetch" component={ auto_fetch =>
        <Toggle
          form="addShowForm"
          label="Auto Fetch"
          labelPosition="left"
          toggled={auto_fetch.value}
          onToggle={(event, toggled) => auto_fetch.onChange(toggled)}
        />
      }/>,
      <FlatButton
        type="button"
        label="Cancel"
        secondary={true}
        onTouchTap={this.props.onRequestClose}
      />,
      <FlatButton
        type="submit"
        label="Submit"
        form="addShowForm"
        primary={true}
        disabled={this.props.pristine || this.props.submitting}
      />,
    ];
  }

  render() {
    return (
      <Dialog
        title="Add a New Show"
        actions={this._getActions()}
        onRequestClose={this.props.onRequestClose}
        open={true}>
        <form onSubmit={this.props.handleSubmit} id="addShowForm">
          <Field name="anime" component={ anime => 
            <AnimeAutosuggest
              floatingLabelText="Show Name"
              autoFocus={true}
              errorText = {anime.touched && anime.error}
              {...anime}
              onChange={(_e, newValue) => anime.onChange(newValue)}
              onBlur={(_e, f) => anime.onBlur(anime.value)}
              fullWidth={true}
            />
          }/>
          <Field name="feed_url" component={ feed_url => 
            <TextField
              floatingLabelText="Feed URL"
              errorText = {feed_url.touched && feed_url.error}
              {...feed_url}
              fullWidth={true}
            />
          }/>
        </form>    
      </Dialog>
    );
  }
}

NewShowDialogFormPresentation.propTypes = {
  onRequestClose: PropTypes.func.isRequired,
  handleSubmit: PropTypes.func.isRequired,
  submitting: PropTypes.bool.isRequired,
  pristine: PropTypes.bool.isRequired,
}

export default reduxForm({
  form: 'addShow',
  validate,
  onSubmit,
  initialValues,
})(NewShowDialogFormPresentation)
