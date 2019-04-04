'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import AppBar from '@material-ui/core/AppBar';
import Toolbar from '@material-ui/core/Toolbar';
import Typography from '@material-ui/core/Typography';
import MenuItem from '@material-ui/core/MenuItem';
import Menu from '@material-ui/core/Menu';
import IconButton from '@material-ui/core/IconButton';
import MenuIcon from '@material-ui/icons/Menu';
import MoreVertIcon from '@material-ui/icons/MoreVert';
import ListItemIcon from '@material-ui/core/ListItemIcon';
import ListItemText from '@material-ui/core/ListItemText';

import Snackbar from '@material-ui/core/Snackbar';
import Divider from '@material-ui/core/Divider';

import ActionHome from '@material-ui/icons/Home';
import ActionBugReport from '@material-ui/icons/BugReport';
import ActionSettings from '@material-ui/icons/Settings';

import { matchPath, withRouter } from "react-router";
import { withStyles } from '@material-ui/core/styles';
import {
  usePopupState,
  bindTrigger,
  bindMenu,
} from 'material-ui-popup-state/hooks'

import { connect } from 'react-redux'
import _ from 'lodash'
import {
  fetchShows,
  dismissSnackbar,
  checkAllFeeds,
  runPostProcessor,
} from '../actions'
import '../../styles/app.css'

const styles = theme => {
  const spacing = theme.spacing;
  return {
    root: {
      paddingTop: spacing.desktopKeylineIncrement,
      minHeight: 400,
    },
    content: {
      margin: spacing.desktopGutter,
      width: 1200,
    },
    title: {
      display: 'none',
      [theme.breakpoints.up('sm')]: {
        display: 'block',
      },
      flexGrow: 1,
    },
    menuButton: {
      marginLeft: -12,
      marginRight: 20,
    },
    activeMenuItem: {
      color: theme.palette.disabledColor,
    },
  };
};

const AppPresentation = (props) => {
  const {classes} = props;
  const popupState = usePopupState({ variant: 'popover', popupId: 'rightMenu' });
  const disablePath = path => {
    return !!matchPath(props.location.pathname, {
      path,
      exact: true
    });
  }
  const closeMenuAndAction = action => (
    (evt) => {
      console.log("ok even ", evt);
      popupState.close();
      action(evt);
    }
  );

  const closeMenuAndNavigateTo = path =>
    closeMenuAndAction((evt) => props.history.push(path));

  const rightMenu = (
    <Menu {...bindMenu(popupState)}>
      <MenuItem
        disabled={disablePath('/')}
        onClick={closeMenuAndNavigateTo("/")}
      >
        <ListItemIcon><ActionHome/></ListItemIcon>
        <ListItemText>Home</ListItemText>
      </MenuItem>
      <MenuItem
        disabled={disablePath('/logs')}
        onClick={closeMenuAndNavigateTo("/logs")}
      >
        <ListItemIcon><ActionBugReport/></ListItemIcon>
        <ListItemText>Logs</ListItemText>
      </MenuItem>
      <MenuItem
        disabled={disablePath('/settings')}
        onClick={closeMenuAndNavigateTo("/settings")}
      >
        <ListItemIcon><ActionSettings/></ListItemIcon>
        <ListItemText>Settings</ListItemText>
      </MenuItem>
      <Divider variant="inset"/>
      <MenuItem
        disabled={props.fetchingList}
        onClick={closeMenuAndAction(props.onRefresh)}
      >
        <ListItemText inset={true}>Refresh Shows</ListItemText>
      </MenuItem>
      <MenuItem onClick={closeMenuAndAction(props.onCheckAllFeeds)}>
        <ListItemText inset={true}>Check All Feeds</ListItemText>
      </MenuItem>
      <MenuItem onClick={closeMenuAndAction(props.onRunPostProcessor)}>
        <ListItemText inset={true}>Run PostProcessor</ListItemText>
      </MenuItem>
    </Menu>
  );

  const snackBar = (
    <Snackbar
      open={!!props.snackbarPayload}
      message={_.get(props.snackbarPayload, 'message') || ''}
      variant="error"
      onRequestClose={props.dismissSnackbar}
      autoHideDuration={2000}
    />
  );


  return (
    <div>
      <AppBar className={classes.appBar}>
        <Toolbar>
          <Typography className={classes.title} variant="h6" color="inherit">
            Cisqua
          </Typography>
          <IconButton
            className={classes.menuButton}
            {...bindTrigger(popupState)}
          >
            <MenuIcon />
          </IconButton>
          {rightMenu}
        </Toolbar>
      </AppBar>
      <div className={classes.root}>
        <div className={classes.content}>
          {props.children}
        </div>
      </div>
      {snackBar}
    </div>
  );
}

AppPresentation.propTypes = {
  fetchingList: PropTypes.bool.isRequired,
  snackbarPayload: PropTypes.object,
  onRefresh: PropTypes.func.isRequired,
  dismissSnackbar: PropTypes.func.isRequired,
  onCheckAllFeeds: PropTypes.func.isRequired,
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

const App = withRouter(connect(
  mapStateToProps,
  mapDispatchToProps,
)(withStyles(styles)(AppPresentation)))

export default App
