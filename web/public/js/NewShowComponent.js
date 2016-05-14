'use strict';

import {Component} from 'react';
import NewShowForm from './NewShowForm'
import { connect } from 'react-redux'
import { addShow } from './actions'

const mapStateToProps = (state) => {
  return {}
}

const mapDispatchToProps = (dispatch) => {
  return {
    onAddShow: (id, name, feed) => {
      dispatch(addShow(id, name, feed))
    }
  }
}

const NewShowComponent = connect(
  mapStateToProps,
  mapDispatchToProps
)(NewShowForm)

export default NewShowComponent