'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import { connect } from 'react-redux'
import ShowContainer from './ShowContainer'
import {HotKeys} from 'react-hotkeys';
import _ from 'lodash'

import { addShowDialog } from '../actions'
import NewShowDialogFormWrapper from './NewShowDialogForm'
import ShowFetcher from './show_fetcher'

const {NewShowDialogForm} = NewShowDialogFormWrapper

const keyEventsMap = {
  'addShow': 'n',
  'filterShows': 'f',
  'escape': 'escape',
};

class HomePresentation extends Component {
  constructor(props) {
    super(props)
    this._onAddShowKey = this._onAddShowKey.bind(this)
  }

  _getStyle() {
    const spacing = this.context.muiTheme.spacing
    return {
    }
  }

  _renderNewShowDialog() {
    if (!this.props.dialogsOpen.addShow) {
      return;
    }
    return (
      <NewShowDialogForm
        onRequestClose={() => this.props.onAddDialogStateChange(false)}
      />
    );
  }

  _onAddShowKey(event) {
    event.preventDefault()
    this.props.onAddDialogStateChange(!this.props.dialogsOpen.addShow); 
  }

  getChildContext() {
    return {
      noDialogsOpen: !_(this.props.dialogsOpen).values().some(),
    };
  }

  render() {
    const handlers = {
      'addShow': this._onAddShowKey,
    };
    return (
      <HotKeys
        keyMap={keyEventsMap} 
        handlers={handlers} 
        focused={this.getChildContext().noDialogsOpen}
        attach={window}
      >
        {this._renderNewShowDialog()}
        <ShowContainer />
        <ShowFetcher />
      </HotKeys>  
    );  
  }
}

HomePresentation.propTypes = {
  onAddDialogStateChange: PropTypes.func.isRequired,
  dialogsOpen: PropTypes.object.isRequired,
}

HomePresentation.childContextTypes = {
  noDialogsOpen: PropTypes.bool.isRequired,
}

const mapStateToProps = (state) => ({
  dialogsOpen: state.app.dialogsOpen,
})

const mapDispatchToProps = (dispatch) => ({
  onAddDialogStateChange: (newValue) => dispatch(addShowDialog(newValue)),
})

const Home = connect(
  mapStateToProps,
  mapDispatchToProps,
)(HomePresentation)

export default Home
