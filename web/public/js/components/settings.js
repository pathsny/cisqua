'use strict';

import React, { PropTypes, Component } from 'react';
import { connect } from 'react-redux'
import { withStyles } from '@material-ui/core/styles';
import CircularProgress from '@material-ui/core/CircularProgress';
import SettingsFormWrapper from './settings_form'
const {SettingsForm} = SettingsFormWrapper

import {fetchSettings} from '../actions'

const styles = theme => ({
  progress: {
    margin: theme.spacing.unit * 2,
  },
});

class SettingsPresentation extends Component {
  constructor(props) {
    super(props)
    props.onFetchSettings()
  }

  _getStyle() {
    return {
      container: {
        position: 'relative'
      },
      overlay: {
        zIndex: 10,
        display: 'none',
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
    const refreshStyle = this.props.fetchingValues ?
      _.merge({}, style.overlay, {display: 'block'}) :
      style.overlay;
    return (
    <div style={style.container}>
      <SettingsForm {...this.props}/>
      <div style={refreshStyle}>
      <CircularProgress className={classes.progress}/>
      </div>
    </div>
    )
  }
}

const mapStateToProps = (state) => {
  const config = state.settings.config[0];
  return {
    form: config.name,
    fields: config.fields.map(f => f.name),
    config: config,
    initialValues: state.settings.values[config.name],
    fetchingValues: state.settings.async.values,
  }
}

const mapDisatchToProps = (dispatch) => ({
  onFetchSettings: () => dispatch(fetchSettings()),
})

const Settings = connect(mapStateToProps, mapDisatchToProps)(withStyles(styles)(SettingsPresentation))

export default Settings
