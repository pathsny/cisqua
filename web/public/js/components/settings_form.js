'use strict';

import React, { PropTypes, Component } from 'react';
import TextField from 'material-ui/TextField';
import RaisedButton from 'material-ui/RaisedButton';

import { Field, reduxForm } from 'redux-form'
import invariant from 'invariant'

import {saveSettings} from '../actions'

function submit(name) {
  return async function(values, dispatch) {
    try {
      await dispatch(saveSettings(name, values));
    } catch (e) {
      if (e.reason instanceof JSONResponseCarryingError) {
        const errorJSON = e.reason.payload
        let resultJson = {}
        for (let k of _.keys(errorJSON)) {
          const key = ['id', 'name'].includes(k) ? 'anime' : k
          resultJson[key] = errorJSON[k][0] 
        }
        throw new SubmissionError(resultJson)
      } else {
        throw e
        console.log("is this it", e)
      }
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
            <TextField
              floatingLabelText={f.label}
              hintText={f.placeholder}
              fullWidth={true}
              type={f.type}
              {...props}
            /> 
          }/>
        );   
      default:
        invariant(false, `unsupported option type ${f.type} of name ${f.name}`)
    }
  }

  render() {
    return (
      <form onSubmit={this.props.handleSubmit(submit(this.props.config.name))}>
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
  SettingsForm: reduxForm({})(SettingsFormPresentation),
}