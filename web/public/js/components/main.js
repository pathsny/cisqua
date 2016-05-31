'use strict';

import React, { PropTypes, Component } from 'react';
import AppBar from 'material-ui/AppBar';
import IconButton from 'material-ui/IconButton';
import Refresh from 'material-ui/svg-icons/navigation/refresh'
import CircularProgress from 'material-ui/CircularProgress';
import { connect } from 'react-redux'
import ShowContainer from './ShowContainer'
import Snackbar from 'material-ui/Snackbar';
import {HotKeys} from 'react-hotkeys';
import MoreVertIcon from 'material-ui/svg-icons/navigation/more-vert';
import MenuItem from 'material-ui/MenuItem';
import IconMenu from 'material-ui/IconMenu';
import _ from 'lodash'

import { fetchShows, dismissSnackbar, addShowDialog, checkAllFeeds } from '../actions'
import '../../styles/main.css'
import NewShowDialogFormWrapper from './NewShowDialogForm'

const {NewShowDialogForm} = NewShowDialogFormWrapper 

class MainPresentation extends Component {
  constructor(props) {
    super(props)
    this._onAddShowKey = this._onAddShowKey.bind(this)
  }

  _renderRightIcon() {
    return (
      <IconMenu 
        iconButtonElement={<IconButton><MoreVertIcon /></IconButton>}
        targetOrigin={{horizontal: 'right', vertical: 'top'}}
        anchorOrigin={{horizontal: 'right', vertical: 'top'}}
      >
        <MenuItem 
          primaryText="Refresh Shows"
          disabled={this.props.fetchingList}
          onTouchTap={this.props.onRefresh}
        />
        <MenuItem
          primaryText="Check All Feeds"
          onTouchTap={this.props.onCheckAllFeeds}
        /> 
      </IconMenu>
    )
  }

  _getStyle() {
    const spacing = this.context.muiTheme.spacing
    return {
      root: {
        paddingTop: spacing.desktopKeylineIncrement,
        minHeight: 400,
      },
      content: {
        margin: spacing.desktopGutter,
        width: 1200,
      },
      appBar: {
        position: 'fixed',
        top: 0,
      }
    }
  }

  _renderSnackBar() {
    return (
      <Snackbar
        open={!!this.props.snackbarPayload}
        message={_.get(this.props.snackbarPayload, 'message') || ''}
        onRequestClose={this.props.dismissSnackbar}
        autoHideDuration={2000}
      />
    );
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

  _renderMainPage() {
    const style = this._getStyle();
    return (
      <div>
        <AppBar
          title="Cisqua"
          iconElementRight={this._renderRightIcon()}
          showMenuIconButton={false}
          style={style.appBar}
        />
        <div style={style.root}>
          <div style={style.content}>
            <ShowContainer />
          </div>
        </div>
        {this._renderSnackBar()}
      </div>
    )
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
        handlers={handlers} 
        focused={this.getChildContext().noDialogsOpen}
        attach={window}
      >
        {this._renderNewShowDialog()}
        {this._renderMainPage()}
      </HotKeys>  
    );  
  }
}

MainPresentation.propTypes = {
  onAddDialogStateChange: PropTypes.func.isRequired,
  dialogsOpen: PropTypes.object.isRequired,
}

MainPresentation.contextTypes = {
  muiTheme: PropTypes.object.isRequired,
}

MainPresentation.childContextTypes = {
  noDialogsOpen: PropTypes.bool.isRequired,
}


const mapStateToProps = (state) => ({
  fetchingList: state.app.fetching.list,
  snackbarPayload: _.first(state.snackbarPayloads),
  dialogsOpen: state.app.dialogsOpen,
})

const mapDispatchToProps = (dispatch) => ({
  onRefresh: () => dispatch(fetchShows()),
  dismissSnackbar: () => dispatch(dismissSnackbar()),
  onAddDialogStateChange: (newValue) => dispatch(addShowDialog(newValue)),
  onCheckAllFeeds: () => dispatch(checkAllFeeds()),
})

const Main = connect(
  mapStateToProps,
  mapDispatchToProps,
)(MainPresentation)

export default Main
