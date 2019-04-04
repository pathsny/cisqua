'use strict';

import Table from '@material-ui/core/Table';
import TableBody from '@material-ui/core/TableBody';
import TableCell from '@material-ui/core/TableCell';
import TableHead from '@material-ui/core/TableHead';
import TableRow from '@material-ui/core/TableRow';

import PropTypes from 'prop-types';
import React, { Component } from 'react';
import ReactDOM from 'react-dom';

import { connect } from 'react-redux'
import moment from 'moment'
import {deepPurple900, grey500, green800, grey900, amber900, red500, white} from '@material-ui/core/colors';
import { withStyles } from '@material-ui/core/styles';

import {startTailingLogs, stopTailingLogs} from '../actions.js'

const logLevels = [
  'DEBUG',
  'INFO',
  'WARN',
  'ERROR',
];

const styles = theme => {
  const column = {
    padding: '0px 4px 0px 4px',
    margin: '0px 0px 0px 0px',
    boxSizing: 'border-box',
    height: '25px',
    fontSize: '10px',
    fontWeight: 900,
  };
  const level = (l) => {
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
  };

  const levelStyles = _.chain(logLevels)
    .keyBy(l => `level_${l}`)
    .mapValues(l => level(l))
    .value();

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
    spacer: _.merge({}, column, {
      width: '15px',
    }),
    message: _.merge({}, column, {
      width: '1000px',
      fontWeight: 500,
    }),
    column,
    ...levelStyles
  }
}

class LogsPresentation extends Component {
   bottom = React.createRef()

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
    this.shouldScrollBottom = (
      this.bottom.current.scrollHeight - this.bottom.current.scrollTop === this.bottom.current.clientHeight
    );
  }

  componentDidUpdate() {
    if (this.state.firstRender) {
      this.setState({firstRender: false})
      this.bottom.current.scrollIntoView({behavior: 'smooth'});
    }
    if (this.shouldScrollBottom) {
      this.bottom.current.scrollIntoView({behavior: 'smooth'});
    }
  }

  _renderLog(l, i) {
    const classes = this.props.classes
    return (
      <TableRow key={i} border={0} className={classes.row}>
        <TableCell className={classes.timestamp}>
          [&nbsp;&nbsp;
          {moment(l.timestamp).format('YYYY-MM-DD HH:mm:ss')}
          &nbsp;&nbsp;]
        </TableCell>
        <TableCell className={classes[`level_${l.level}`]}>{l.level}</TableCell>
        <TableCell className={classes.spacer}>--</TableCell>
        <TableCell className={classes.logger}>{l.logger}:</TableCell>
        <TableCell className={classes.message}>{l.message}</TableCell>
        <TableCell className={classes.column}/>
      </TableRow>
    )
  }

  render() {
    return (
      <div>
        <Table>
          <TableBody>
            {this.props.logs.map(this._renderLog)}
          </TableBody>
        </Table>
        <div ref={this.bottom} />
      </div>
    );
  }
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
)(withStyles(styles)(LogsPresentation))

export default Logs
