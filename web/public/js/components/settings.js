'use strict';

import React, { PropTypes, Component } from 'react';
import { connect } from 'react-redux'

import RefreshIndicator from 'material-ui/RefreshIndicator';
import SettingsFormWrapper from './settings_form'
const {SettingsForm} = SettingsFormWrapper 


class SettingsPresentation extends Component {
  componentWillMount() {

  }

  _getStyle() {
    return {
      container: {
        position: 'relative'
      },
      overlay: {
        zIndex: 10,
        display: 'block',
        position: 'absolute',
        height: '100%',
        top: '0px',
        left: '0px',
        right: '0px',
        background: 'rgba(0, 0, 0, 0.5)',
      },
      indicator: {
        background: 'rgba(0 ,0 ,0 , 0)',
        boxShadow: 'none',
      }
    }
  }

  render() {
    const style = this._getStyle();
    return (
    <div style={style.container}>
      <SettingsForm {...this.props}/>
      <div style={style.overlay}> 
      <RefreshIndicator
        size={200}
        left={300}
        top={40}
        status="loading"
        style={style.indicator}
      />
      </div>
    </div>
    )
  }  
}  

const mapStateToProps = (state) => ({
  form: state.settings.config[0].name,
  fields: state.settings.config[0].fields.map(f => f.name),
  config: state.settings.config[0],
})

const Settings = connect(mapStateToProps)(SettingsPresentation)

export default Settings