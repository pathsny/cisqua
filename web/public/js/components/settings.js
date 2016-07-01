'use strict';

import React, { PropTypes, Component } from 'react';

import { connect } from 'react-redux'


class SettingsPresentation extends Component {
  constructor(props) {
    super(props)
  }

  render() {
    return (
      <div>Settings</div>
    );
  }
}

SettingsPresentation.propTypes = {
}

const mapStateToProps = (state) => ({
})

const mapDispatchToProps = (dispatch) => ({
})


const Settings = connect(
  mapStateToProps,
  mapDispatchToProps,
)(SettingsPresentation)

export default Settings