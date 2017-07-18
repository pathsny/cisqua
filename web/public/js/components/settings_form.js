'use strict';

import React, { PropTypes, Component } from 'react';
import TextField from 'material-ui/TextField';
import RaisedButton from 'material-ui/RaisedButton';

import { Field, reduxForm } from 'redux-form'
import invariant from 'invariant'

import {saveSettings, JSONResponseCarryingError} from '../actions'

function submit(name) {
  return async function(values, dispatch) {
    try {
      await dispatch(saveSettings(name, values));
    } catch (e) {
      if (e.reason instanceof JSONResponseCarryingError) {
        const errorJSON = e.reason.payload
        let resultJson = {}
        for (let k of _.keys(errorJSON)) {
          resultJson[k] = errorJSON[k][0] 
        }
        throw new SubmissionError(resultJson)
      } else {
        throw e
      }
    }
  }
}

async function submitTorrent(values, dispatch) {
  try {
    await dispatch(saveSettings('Torrent', values));
  } catch (e) {
    if (e.reason instanceof JSONResponseCarryingError) {
      const errorJSON = e.reason.payload
      let resultJson = {}
      for (let k of _.keys(errorJSON)) {
        resultJson[k] = errorJSON[k][0] 
      }
      throw new SubmissionError(resultJson)
    } else {
      throw e
    }
  }
}

class SettingsFormPresentation extends Component {
  _renderField(f) {
    switch(f.type) {
      case 'number':
      case 'text':
      case 'password':
        return (
          <Field name={f.name} key={f.name} component={ props => 
            {
            return <TextField
              floatingLabelText={f.label}
              hintText={f.placeholder}
              fullWidth={true}
              type={f.type}
              errorText = {props.touched && props.error}
              {...props}
            />
            } 
          }/>
        );   
      default:
        invariant(false, `unsupported option type ${f.type} of name ${f.name}`)
    }
  }

  render() {
    return (
      <form onSubmit={this.props.handleSubmit}>
        {this.props.config.fields.map(f => this._renderField(f))}
        <RaisedButton
          type="submit"
          label="Save"
          primary={true}
          disabled={this.props.pristine || this.props.submitting}
        />
      </form>
    );
  }
}

SettingsFormPresentation.propTypes = {
  config: PropTypes.object.isRequired,
  handleSubmit: PropTypes.func.isRequired,
}

export default {
  SettingsForm: reduxForm({
    onSubmit: submitTorrent
  })(SettingsFormPresentation),
}