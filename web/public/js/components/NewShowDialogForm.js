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
import {getAnidbTitle} from '../utils/anidb_utils.js'
import {addShow, addShowToServer, addShowDialog, JSONResponseCarryingError} from '../actions.js'

async function onSubmit(values, dispatch) {
  try {
    const result = await addShowToServer(
      _.parseInt(values.anime.anime['@aid']),
      getAnidbTitle(values.anime.anime),
      values.feed,
      values.auto_fetch,  
    );
    dispatch(addShow(result));
  } catch (e) {
    if (e instanceof JSONResponseCarryingError) {
      const errorJSON = e.payload
      let resultJson = {}
      for (let k of _.keys(errorJSON)) {
        const key = ['id', 'name'].includes(k) ? 'feed' : k
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
  if (!values.feed) {
    errors.feed = 'Feed Required'
  }
  if (!values.anime.anime) {
    errors.feed = 'Anime Required'
  }
  return errors
}

const initialValues = {
  anime: {
    anime: null,
    lastSelectionByUser: false,
  },
  feed: '',
  auto_fetch: true,
}

class NewShowDialogFormPresentation extends Component {
  _getStyle() {
    return {
      feed: {
        width: '400px'
      },
      toggle: {
        float: 'right',
        maxWidth: '500px'
      },
      autosuggest: {
        width: '400px'
      }
    }
  }

  _getActions() {
    return [
      <FlatButton
        type="button"
        label="Cancel"
        primary={true}
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
    const style = this._getStyle();
    return (
      <Dialog
        title="Add a New Show"
        actions={this._getActions()}
        modal={true}
        open={true}>
        <form onSubmit={this.props.handleSubmit} id="addShowForm">
          <div style={style.autosuggest}>
            <Field name="anime" component={ props =>
              <AnimeAutosuggest
                value={props.value}
                onChange={(event, newValue) => props.onChange(newValue)}
              />
            }/>
          </div>
          <div style={style.toggle}>
            <Field name="auto_fetch" component={ props =>
              <Toggle
                label="Auto Fetch"
                labelPosition="right"
                toggled={props.value}
                onToggle={(event, toggled) => props.onChange(toggled)}
              />
            }/>
          </div>
          <div>
            <Field name="feed" component={ feed => 
              <TextField
                floatingLabelText="Feed URL"
                style={style.feed}
                errorText = {feed.touched && feed.error}
                {...feed}
              />
            }/>
          </div>
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
