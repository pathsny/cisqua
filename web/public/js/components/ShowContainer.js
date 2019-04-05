'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import { connect } from 'react-redux'
import List from '@material-ui/core/List';
import ListItem from '@material-ui/core/ListItem';
import ListItemText from '@material-ui/core/ListItemText';
import AppBar from '@material-ui/core/AppBar';
import Toolbar from '@material-ui/core/Toolbar';
import Button from '@material-ui/core/Button';
import TextField from '@material-ui/core/TextField';
import InputAdornment from '@material-ui/core/InputAdornment';
import SearchIcon from '@material-ui/icons/Search';
import Dialog from '@material-ui/core/Dialog';
import {HotKeys} from 'react-hotkeys';

import {ShowPropType} from './proptypes.js'
import Show from './Show'
import NewShowDialogFormWrapper from './NewShowDialogForm'
import { fade } from '@material-ui/core/styles/colorManipulator';
import { withStyles } from '@material-ui/core/styles';
import {addShowDialog} from '../actions.js'

const {NewShowDialogForm} = NewShowDialogFormWrapper

const styles = theme => ({
  root: {
    width: '100%',
  },
  grow: {
    flexGrow: 1,
  },
  menuButton: {
    marginLeft: -12,
    marginRight: 20,
  },
  title: {
    display: 'none',
    [theme.breakpoints.up('sm')]: {
      display: 'block',
    },
  },
  search: {
    position: 'relative',
    borderRadius: theme.shape.borderRadius,
    backgroundColor: fade(theme.palette.common.white, 0.15),
    '&:hover': {
      backgroundColor: fade(theme.palette.common.white, 0.25),
    },
    marginRight: theme.spacing.unit * 64,
    width: '100%',
    flexGrow: 1,
  },
  inputRoot: {
    color: 'inherit',
    width: '100%',
  },
  sectionDesktop: {
    display: 'none',
    [theme.breakpoints.up('md')]: {
      display: 'flex',
    },
  },
  sectionMobile: {
    display: 'flex',
    [theme.breakpoints.up('md')]: {
      display: 'none',
    },
  },
});

const InitialState = {
  filterText: '',
}

class ShowContainerPresentation extends Component {
  constructor(props) {
    super(props)
    this.state = InitialState;
    this._handleFilterChange = this._handleFilterChange.bind(this)
    this._onFilterShows = this._onFilterShows.bind(this)
    this._onStopFilteringShowsMaybe = this._onStopFilteringShowsMaybe.bind(this)
  }

  _handleFilterChange(event) {
    this.setState({filterText: event.target.value})
  }

  _renderShow(show) {
    return (
      <ListItem key={show.id} disabled={true}>
        <Show anime={show} />
      </ListItem>
    );
  }

  _onFilterShows(event) {
    event.preventDefault();
    this.refs.filterField.focus()
    return false;
  }

  _onStopFilteringShowsMaybe(event) {
    if (event.keyCode === 27) {
      this.setState({filterText: ''});
      this.refs.filterField.blur();
    }
  }

  _renderControlSection() {
    const handlers = {
      'filterShows': this._onFilterShows,
    };
    const { classes } = this.props;
    return (

      <AppBar position="static" color="default">
        <Toolbar>
          <HotKeys
            handlers={handlers}
            focused={this.context.noDialogsOpen}
            attach={window}
          >
            <TextField
              ref="filterField"
              onChange={this._handleFilterChange}
              value={this.state.filterText}
              onKeyDown={this._onStopFilteringShowsMaybe}
              className={classes.search}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <SearchIcon />
                  </InputAdornment>
                ),
              }}
              classes={{
                root: classes.inputRoot,
              }}
            />
          </HotKeys>
          <span className={classes.grow}/>
          <Button
            color='secondary'
            variant='contained'
            onClick={() => this.props.onAddDialogStateChange(true)}
          >
            Add New Show
          </Button>
        </Toolbar>
      </AppBar>
    )
  }

  _filteredShowList() {
    const regexp = new RegExp(this.state.filterText, "i")
    return this.props.shows.filter(
      show => show.name.search(regexp) !== -1
    )
  }
  render() {
    return (
      <div>
        {this._renderControlSection()}
        <List>
          {this._filteredShowList().map(show => this._renderShow(show))}
       </List>
     </div>
    );
  }
}

ShowContainerPresentation.propTypes = {
  shows: PropTypes.arrayOf(ShowPropType.isRequired).isRequired,
  onAddDialogStateChange: PropTypes.func.isRequired,
  dialogsOpen: PropTypes.object.isRequired,
}

ShowContainerPresentation.contextTypes = {
  noDialogsOpen: PropTypes.bool.isRequired,
}

const mapStateToProps = (state) => ({
  shows: state.app.showList.map(id => state.app.showsByID[id]),
  dialogsOpen: state.app.dialogsOpen,
})

const mapDispatchToProps = (dispatch) => ({
  onAddDialogStateChange: (newValue) => dispatch(addShowDialog(newValue)),
})

const ShowContainer = connect(
  mapStateToProps,
  mapDispatchToProps,
)(ShowContainerPresentation)

export default  withStyles(styles)(ShowContainer)
