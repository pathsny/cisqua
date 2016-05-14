'use strict';

import { connect } from 'react-redux'
import ShowList from './ShowList'

const mapStateToProps = (state) => {
  return {
    shows: state.showList.map(id => state.showsByID[id])
  }
}

const mapDispatchToProps = (dispatch) => {
  return {}
}

const ShowListComponent = connect(
  mapStateToProps,
  mapDispatchToProps
)(ShowList)

export default ShowListComponent