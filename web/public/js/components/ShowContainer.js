'use strict';

import React, { PropTypes, Component } from 'react'
import { connect } from 'react-redux'
import {List, ListItem} from 'material-ui/List';
import {Toolbar, ToolbarGroup, ToolbarSeparator, ToolbarTitle} from 'material-ui/Toolbar';
import RaisedButton from 'material-ui/RaisedButton';
import Dialog from 'material-ui/Dialog';

import {ShowPropType} from './proptypes.js'
import Show from './Show'
import NewShowDialogForm from './NewShowDialogForm'
import TextField from 'material-ui/TextField';


class ShowContainerPresentation extends Component {
  constructor(props) {
    super(props)
    this.state = {filterText: '', addDialogOpen: false}
    this._handleFilterChange = this._handleFilterChange.bind(this)
    this._handleAddShowClick = this._handleAddShowClick.bind(this)
    this._onRequestClose = this._onRequestClose.bind(this)
  }

  _handleFilterChange(event) {
    this.setState({filterText: event.target.value})
  }

  _handleAddShowClick() {
    this.setState({addDialogOpen: true})
  }

  _onRequestClose() {
    this.setState({addDialogOpen: false})
  }

  _renderShow(show) {
    return (
      <ListItem key={show.id} disabled={true}>
        <Show anime={show} />
      </ListItem>
    );  
  } 

  _renderControlSection() {
    return (
      <Toolbar>
        <ToolbarGroup float="left">
          <TextField 
            hintText="Filter"
            fullWidth={true}
            onChange={this._handleFilterChange}
            value={this.state.filterText}
          />
        </ToolbarGroup>
        <ToolbarGroup float="right" lastChild={true}>
          <NewShowDialogForm 
            dialogOpen={this.state.addDialogOpen}
            onRequestClose={this._onRequestClose}
          />
          <RaisedButton 
            label="Add New Show" 
            primary={true}
            onTouchTap={this._handleAddShowClick}
          />
        </ToolbarGroup>  
      </Toolbar>  
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
}

const mapStateToProps = (state) => ({
  shows: state.showList.map(id => state.showsByID[id])
})

const ShowContainer = connect(
  mapStateToProps,
)(ShowContainerPresentation)

export default ShowContainer