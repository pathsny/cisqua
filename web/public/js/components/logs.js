'use strict';

import React, { PropTypes, Component } from 'react';

let wsclient;

export default class Logs extends Component {
  constructor(props) {
    super(props)
    console.log("none")
  }

  componentWillMount() {
    const uri = `ws://${window.document.location.host}/log_tailer`
    wsclient = new WebSocket(uri)
    wsclient.onopen = function(evt) {
      console.log("so opened with", evt)
    }
    wsclient.onmessage = function(message) {
      console.log(`I got ${message.data}`)
      // wsclient.send("sending out something")
    };
    wsclient.onclose = function(evt) {
      console.log("so closed with", evt)
    }
  }

  componentWillUnmount() {
    wsclient.close()
    this.setState({ws: null})
  }

  render() {
    return (
      <div>
      Welcome to Proscutto
      </div>  
    );
  }
}  