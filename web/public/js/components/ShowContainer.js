'use strict';

import PropTypes from 'prop-types';

import React, { Component } from 'react';
import { connect } from 'react-redux'
import {List, ListItem} from '@material-ui/core/List';
import {Toolbar, ToolbarGroup, ToolbarSeparator, ToolbarTitle} from '@material-ui/core/Toolbar';
import Button from '@material-ui/core/Button';
import TextField from '@material-ui/core/TextField';
import Dialog from '@material-ui/core/Dialog';
import {HotKeys} from 'react-hotkeys';

import {ShowPropType} from './proptypes.js'
import Show from './Show'
import NewShowDialogFormWrapper from './NewShowDialogForm'
import {addShowDialog} from '../actions.js'

const {NewShowDialogForm} = NewShowDialogFormWrapper

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
    return (
      <Toolbar>
        <ToolbarGroup float="left">
          <HotKeys
            handlers={handlers}
            focused={this.context.noDialogsOpen}
            attach={window}
          >
            <TextField
              ref="filterField"
              hintText="Filter"
              fullWidth={true}
              onChange={this._handleFilterChange}
              value={this.state.filterText}
              onKeyDown={this._onStopFilteringShowsMaybe}
            />
          </HotKeys>
        </ToolbarGroup>
        <ToolbarGroup float="right" lastChild={true}>
          <Button
            label="Add New Show"
            primary={true}
            variant='contained'
          />
        </ToolbarGroup>
      </Toolbar>
            onClick={() => this.props.onAddDialogStateChange(true)}
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
      <List>
        {this._renderControlSection()}
        {this._filteredShowList().map(show => this._renderShow(show))}
      </List>
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

export default ShowContainer
