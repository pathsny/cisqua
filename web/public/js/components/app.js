'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import AppBar from '@material-ui/core/AppBar';
import MoreVertIcon from '@material-ui/icons/MoreVert';
import MenuItem from '@material-ui/core/MenuItem';
import Menu from '@material-ui/core/Menu';
import IconButton from '@material-ui/core/IconButton';
import Snackbar from '@material-ui/core/Snackbar';
import Divider from '@material-ui/core/Divider';

import ActionHome from '@material-ui/icons/Home';
import ActionBugReport from '@material-ui/icons/BugReport';
import ActionSettings from '@material-ui/icons/Settings';

import { IndexLink, Link } from 'react-router'

// import getMuiTheme from 'material-ui/styles/getMuiTheme';
// import MuiThemeProvider from 'material-ui/styles/MuiThemeProvider';

import { connect } from 'react-redux'
import _ from 'lodash'
import {
  fetchShows,
  dismissSnackbar,
  checkAllFeeds,
  runPostProcessor,
} from '../actions'
import '../../styles/app.css'

class AppPresentation extends Component {
  state = {
    anchorEl: null,
  };

  handleClick = event => {
    this.setState({ anchorEl: event.currentTarget });
  };

  handleClose = () => {
    this.setState({ anchorEl: null });
  };

  _disableMenu() {
    return !this.context.router
  }

  _disablePath(path) {
    return !this.context.router|| this.context.router.isActive(path, true)
  }

  _renderRightIcon(style) {
    const { anchorEl } = this.state;
    const open = Boolean(anchorEl);
    return (
      <div>
        <IconButton
            aria-label="More"
            aria-owns={open ? 'more-menu' : undefined}
            aria-haspopup="true"
            onClick={this.handleClick}
          >
            <MoreVertIcon />
          </IconButton>
        <Menu
          id="long-menu"
          anchorEl={anchorEl}
          open={open}
          onClose={this.handleClose}
        >
          <MenuItem
            id="more-menu"
            disabled={this._disablePath('/')}
            onTouchTap={() => _.delay(() => this.context.router.push("/"))}
            primaryText="Home"
            leftIcon={<ActionHome/>}
          />
          <MenuItem
            disabled={this._disablePath('/logs')}
            onTouchTap={() => _.delay(() => this.context.router.push("/logs"))}
            primaryText="Logs"
            leftIcon={<ActionBugReport/>}
          />
          <MenuItem
            disabled={this._disablePath('/settings')}
            onTouchTap={() => _.delay(() => this.context.router.push("/settings"))}
            primaryText="Settings"
            leftIcon={<ActionSettings/>}
          />
          <Divider inset={true}/>
          <MenuItem
            primaryText="Refresh Shows"
            disabled={this._disableMenu() || this.props.fetchingList}
            onTouchTap={this.props.onRefresh}
            insetChildren={true}
          />
          <MenuItem
            disabled={this._disableMenu()}
            primaryText="Check All Feeds"
            onTouchTap={this.props.onCheckAllFeeds}
            insetChildren={true}
          />
          <MenuItem
            disabled={this._disableMenu()}
            primaryText="Run PostProcessor"
            onTouchTap={this.props.onRunPostProcessor}
            insetChildren={true}
          />
        </Menu>
      </div>
    )
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

  _getStyle(muiTheme) {
    const spacing = muiTheme.spacing
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
      },
      activeMenuItem: {
        color: muiTheme.palette.disabledColor,
      },
    }
  }

  render() {
    // const muiTheme = getMuiTheme();
    // const style = this._getStyle(muiTheme);
    return (
      // <MuiThemeProvider muiTheme={muiTheme}>
        <div>
          <AppBar
            title="Cisqua"
            iconElementRight={this._renderRightIcon(style)}
            showMenuIconButton={false}
            style={style.appBar}
          />
          <div style={style.root}>
            <div style={style.content}>
              {this.props.children}
            </div>
          </div>
          {this._renderSnackBar()}
        </div>
      // </MuiThemeProvider>
    );
  }
}

AppPresentation.propTypes = {
  fetchingList: PropTypes.bool.isRequired,
  snackbarPayload: PropTypes.object,
  onRefresh: PropTypes.func.isRequired,
  dismissSnackbar: PropTypes.func.isRequired,
  onCheckAllFeeds: PropTypes.func.isRequired,
}

AppPresentation.contextTypes = {
  router: PropTypes.object
}

const mapStateToProps = (state) => ({
  fetchingList: state.app.async.showList,
  snackbarPayload: _.first(state.snackbarPayloads),
})

const mapDispatchToProps = (dispatch) => ({
  onRefresh: () => dispatch(fetchShows()),
  dismissSnackbar: () => dispatch(dismissSnackbar()),
  onCheckAllFeeds: () => dispatch(checkAllFeeds()),
  onRunPostProcessor: () => dispatch(runPostProcessor()),
})

const App = connect(
  mapStateToProps,
  mapDispatchToProps,
)(AppPresentation)

export default App
