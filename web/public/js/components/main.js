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
import _ from 'lodash'

import { fetchShows, dismissSnackbar } from '../actions'
import '../../styles/main.css'
import {addShowDialog} from '../actions.js'
import NewShowDialogFormWrapper from './NewShowDialogForm'

const {NewShowDialogForm} = NewShowDialogFormWrapper 

class MainPresentation extends Component {
  constructor(props) {
    super(props)
    this._onRefresh = this._onRefresh.bind(this)
    this._onAddShowKey = this._onAddShowKey.bind(this)
  }

  _onRefresh() {
    this.props.onRefresh()
  }

  _renderRightIcon() {
    if (this.props.fetchingList) {
      return (
        <CircularProgress 
          color={this.context.muiTheme.palette.alternateTextColor} 
          size={0.25} 
        />
      );
    } 
    return (
      <IconButton 
        tooltip="refresh" 
        onTouchTap={this._onRefresh}>
        <Refresh/>
      </IconButton>
    );
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
})

const Main = connect(
  mapStateToProps,
  mapDispatchToProps,
)(MainPresentation)

export default Main
