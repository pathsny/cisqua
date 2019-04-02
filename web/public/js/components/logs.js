'use strict';

import {Table, TableBody, TableRow, TableRowColumn} from '@material-ui/core/Table';
import PropTypes from 'prop-types';
import React, { Component } from 'react';
import ReactDOM from 'react-dom';

import { connect } from 'react-redux'
import moment from 'moment'
import {deepPurple900, grey500, green800, grey900, amber900, red500, white} from '@material-ui/core/colors';

import {startTailingLogs, stopTailingLogs} from '../actions.js'

function GetStyle(theme, type, value) {
  const column = {
    padding: '0px 4px 0px 4px',
    margin: '0px 0px 0px 0px',
    boxSizing: 'border-box',
    height: '25px',
    fontSize: '10px',
    fontWeight: 900,
  }
  return {
    row: {
      padding: '0px 0px 0px 0px',
      margin: '0px 0px 0px 0px',
      height: '20px',
    },
    timestamp: _.merge({}, column, {
      width: '120px',
      color: theme.palette.primary1Color,
    }),
    logger: _.merge({}, column, {
      width: '80px',
      color: theme.palette.accent1Color,
    }),
    level(l) {
      const levelColors = {
        DEBUG: grey500,
        INFO: green800,
        WARN: amber900,
        ERROR: red500,
      }
      const style = {
        color: levelColors[l] || grey900,
        fontWeight: 'bold',
        width: '40px',
        backgroundColor: l === 'ERROR' ? theme.palette.textColor : theme.palette.canvasColor
      };
      return _.merge({}, column, style);
    },
    spacer: _.merge({}, column, {
      width: '15px',
    }),
    message: _.merge({}, column, {
      width: '1000px',
      fontWeight: 500,
    }),
    column,
  }
}

class LogsPresentation extends Component {
  constructor(props) {
    super(props)
    this._renderLog = this._renderLog.bind(this)
    this.state = {firstRender: true}
  }

  componentWillMount() {
    this.props.onStartTailingLogs();
  }

  componentWillUnmount() {
    this.props.onStopTailingLogs();
  }

  componentWillUpdate() {
    const node = ReactDOM.findDOMNode(this)
    this.shouldScrollBottom = (
      node.scrollHeight - node.scrollTop === node.clientHeight
    );
  }

  componentDidUpdate() {
    const node = ReactDOM.findDOMNode(this)
    if (this.state.firstRender) {
      this.setState({firstRender: false})
      node.scrollIntoView(false)
    }
    if (this.shouldScrollBottom) {
      node.scrollIntoView(false)
    }
  }

  _renderLog(l, i) {
    const style = GetStyle(this.context.muiTheme)
    return (
      <TableRow key={i} displayBorder={false} style={style.row}>
        <TableRowColumn style={style.timestamp}>
          [&nbsp;&nbsp;
          {moment(l.timestamp).format('YYYY-MM-DD HH:mm:ss')}
          &nbsp;&nbsp;]
        </TableRowColumn>
        <TableRowColumn style={style.level(l.level)}>{l.level}</TableRowColumn>
        <TableRowColumn style={style.spacer}>--</TableRowColumn>
        <TableRowColumn style={style.logger}>{l.logger}:</TableRowColumn>
        <TableRowColumn style={style.message}>{l.message}</TableRowColumn>
        <TableRowColumn style={style.column}/>
      </TableRow>
    )
  }

  render() {
    return (
      <Table>
        <TableBody  displayRowCheckbox={false}>
          {this.props.logs.map(this._renderLog)}
        </TableBody>
      </Table>
    );
  }
}

LogsPresentation.contextTypes = {
  muiTheme: PropTypes.object.isRequired
}

LogsPresentation.propTypes = {
  logs: PropTypes.arrayOf(PropTypes.object.isRequired).isRequired,
  onStartTailingLogs: PropTypes.func.isRequired,
  onStopTailingLogs: PropTypes.func.isRequired,
}

const mapStateToProps = (state) => ({
  logs: state.logs
})

const mapDispatchToProps = (dispatch) => ({
  onStartTailingLogs: () => dispatch(startTailingLogs()),
  onStopTailingLogs: () => stopTailingLogs(),
})


const Logs = connect(
  mapStateToProps,
  mapDispatchToProps,
)(LogsPresentation)

export default Logs
