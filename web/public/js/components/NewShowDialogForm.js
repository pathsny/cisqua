import React, { PropTypes, Component } from 'react'
import Dialog from 'material-ui/Dialog';
import { connect } from 'react-redux'
import FlatButton from 'material-ui/FlatButton';
import RaisedButton from 'material-ui/RaisedButton';
import TextField from 'material-ui/TextField';
import Toggle from 'material-ui/Toggle';

import _ from 'lodash'

import AnimeAutosuggest from './AnimeAutosuggest.js'
import {getAnidbTitle} from '../utils/anidb_utils.js'

const initialState = {
  selectedAnime: {
    anime: null,
    lastSelectionByUser: false,
  },
  feed_url: '',
};

class NewShowDialogFormPresentation extends Component {
  constructor(props) {
    super(props)
    this.state = initialState
    this._onFeedUrlChange = this._onFeedUrlChange.bind(this);
    this._onAnimeSelection = this._onAnimeSelection.bind(this);
    this._addShow = this._addShow.bind(this);
  }

  _onFeedUrlChange(event) {
    this.setState({feed_url: event.target.value});
  }

  _onAnimeSelection(anime) {
    this.setState({
      selectedAnime: {
        anime: anime,
        lastSelectionByUser: true,
      }
    });
  }

  _addShow() {
    this.props.onAddShow(
      _.parseInt(this.state.selectedAnime.anime['@aid']),
      getAnidbTitle(this.state.selectedAnime.anime),
      this.state.feed_url,
    );
  }

  _getStyle() {
    return {
      feed_url: {
        width: '400px'
      },
      toggle: {
        float: 'right',
        maxWidth: '250px'
      }
    }
  }

  _getActions() {
    return [
      <FlatButton
        label="Cancel"
        primary={true}
        onTouchTap={this.props.onRequestClose}
      />,
      <FlatButton
        label="Submit"
        primary={true}
        disabled={true}
        onTouchTap={this.props.onRequestClose}
      />,
    ];
  }

  render() {
    const style = this._getStyle();
    return (
      <Dialog
        title="Add a New Show"
        actions={this._getActions()}
        modal={true}
        open={this.props.dialogOpen}
      >
        <div>
        <AnimeAutosuggest
          value={this.state.selectedAnime}
          onChange={this._onAnimeSelection}
        />
        </div>
        <div>
          <TextField
            id="feed_url" 
            onChange={this._onFeedUrlChange}
            value={this.state.feed_url}
            floatingLabelText="Feed URL"
            style={style.feed_url}
          />
          <div style={style.toggle}>
            <Toggle
              label="Automatically Download"
              labelPosition="right"
              defaultToggled={true}
            />
          </div>
        </div>  
      </Dialog>
    );
  }
}

NewShowDialogFormPresentation.propTypes = {
  dialogOpen: PropTypes.bool.isRequired,
  onRequestClose: PropTypes.func.isRequired,
}

const mapDispatchToProps = (dispatch) => ({
  onAddShow: (id, name, feed) => dispatch(addShow(id, name, feed))
})

const NewShowDialogForm = connect(
  (state) => ({}),
  mapDispatchToProps,
)(NewShowDialogFormPresentation)

export default NewShowDialogForm
