'use strict';

import React, { PropTypes, Component } from 'react';
import AppBar from 'material-ui/AppBar';
import IconButton from 'material-ui/IconButton';
import Refresh from 'material-ui/svg-icons/navigation/refresh'
import CircularProgress from 'material-ui/CircularProgress';
import { connect } from 'react-redux'
import { fetchShowsSmart } from '../actions'
import ShowContainer from './ShowContainer'

import '../../styles/main.css'

class MainPresentation extends Component {
  constructor(props) {
    super(props)
    this._onRefresh = this._onRefresh.bind(this)
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

  render() {
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
          <ShowContainer/>
        </div>
      </div> 
      </div>
    );  
  }
}

MainPresentation.contextTypes = {
  muiTheme: PropTypes.object.isRequired,
}


const mapStateToProps = (state) => ({
  fetchingList: state.app.fetching.list
})

const mapDispatchToProps = (dispatch) => ({
  onRefresh: () => dispatch(fetchShowsSmart())
})

const Main = connect(
  mapStateToProps,
  mapDispatchToProps,
)(MainPresentation)

export default Main


