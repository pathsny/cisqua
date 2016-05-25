'use strict';

import React, { PropTypes, Component } from 'react'
import { connect } from 'react-redux'
import {List, ListItem} from 'material-ui/List';
import {Toolbar, ToolbarGroup, ToolbarSeparator, ToolbarTitle} from 'material-ui/Toolbar';
import RaisedButton from 'material-ui/RaisedButton';
import TextField from 'material-ui/TextField';
import Dialog from 'material-ui/Dialog';

import {ShowPropType} from './proptypes.js'
import Show from './Show'
import NewShowDialogForm from './NewShowDialogForm'
import {addShowDialog} from '../actions.js'

class ShowContainerPresentation extends Component {
  constructor(props) {
    super(props)
    this.state = {filterText: ''}
    this._handleFilterChange = this._handleFilterChange.bind(this)
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

  _renderNewShowDialog() {
    if (!this.props.addDialogOpen) {
      return;
    }
    return (
      <NewShowDialogForm 
        onRequestClose={() => {console.log("called"); this.props.onAddDialogStateChange(false)}}
      />
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
          {this._renderNewShowDialog()}
          <RaisedButton 
            label="Add New Show" 
            primary={true}
            onTouchTap={() => this.props.onAddDialogStateChange(true)}
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
  onAddDialogStateChange: PropTypes.func.isRequired,
  addDialogOpen: PropTypes.bool.isRequired,
}

const mapStateToProps = (state) => ({
  shows: state.app.showList.map(id => state.app.showsByID[id]),
  addDialogOpen: state.app.dialogsOpen.addShow,
})

const mapDispatchToProps = (dispatch) => ({
  onAddDialogStateChange: (newValue) => dispatch(addShowDialog(newValue)) 
})

const ShowContainer = connect(
  mapStateToProps,
  mapDispatchToProps,
)(ShowContainerPresentation)

export default ShowContainer