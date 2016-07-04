'use strict';

import React, { PropTypes, Component } from 'react';
import TextField from 'material-ui/TextField';
import { Field, reduxForm } from 'redux-form'
import invariant from 'invariant'

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
    console.log('the props are', this.props);
    return (
      <form onSubmit={this.props.handleSubmit}>
        {this.props.config.fields.map(f => this._renderField(f))}
      </form>
    );
  }
}

SettingsFormPresentation.propTypes = {
  config: PropTypes.object.isRequired,
}

export default {
  SettingsForm: reduxForm({})(SettingsFormPresentation),
}