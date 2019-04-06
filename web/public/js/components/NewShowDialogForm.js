import PropTypes from 'prop-types';
import React, { Component } from 'react';
import Dialog from '@material-ui/core/Dialog';
import DialogActions from '@material-ui/core/DialogActions';
import DialogContent from '@material-ui/core/DialogContent';
import DialogTitle from '@material-ui/core/DialogTitle';
import { connect } from 'react-redux'
import { Field, reduxForm } from 'redux-form'
import { SubmissionError } from 'redux-form';
import Button from '@material-ui/core/Button';
import TextField from '@material-ui/core/TextField';
import FormControlLabel from '@material-ui/core/FormControlLabel';
import Switch from '@material-ui/core/Switch';
import { withStyles } from '@material-ui/core/styles';

import _ from 'lodash'

import AnimeAutosuggest from './AnimeAutosuggest.js'
import {addShowDialog, JSONResponseCarryingError, addShow} from '../actions.js'

async function onSubmit(values, dispatch) {
  try {
    const anime = values.anime.suggestion
    await dispatch(addShow(
      _.parseInt(anime['@aid']),
      anime.name,
      values.feed_url,
      values.auto_fetch,
    ));
  } catch (e) {
    if (e.reason instanceof JSONResponseCarryingError) {
      const errorJSON = e.reason.payload
      let resultJson = {}
      for (let k of _.keys(errorJSON)) {
        const key = ['id', 'name'].includes(k) ? 'anime' : k
        resultJson[key] = errorJSON[k][0]
      }
      throw new SubmissionError(resultJson)
    } else {
      throw e
    }
  }
}

const validate = values => {
  const errors = {}
  if (!values.feed_url) {
    errors.feed_url = 'Feed URL Required'
  }
  if (!values?.anime?.suggestion) {
    errors.anime = 'Anime Required'
  }
  return errors
}

const initialValues = {
  // anime: {
  //   suggestion: null,
  //   searchText: '',
  // },
  anime: '',
  feed_url: '',
  auto_fetch: true,
}

const styles = theme => ({
});

class NewShowDialogFormPresentation extends Component {
  _getActions() {
    return (
      <DialogActions>
        <Button
          type="button"
          color="default"
          onClick={this.props.onRequestClose}
        >Cancel</Button>
        <Button
          type="submit"
          form="addShowForm"
          color="primary"
          disabled={this.props.pristine || this.props.submitting}
        >Submit</Button>
      </DialogActions>
    );
  }

  render() {
    const {classes} = this.props;
    return (
      <Dialog
        onClose={this.props.onRequestClose}
        open={true}
        classes={classes} >
        <DialogTitle>Add a New Show</DialogTitle>
        <DialogContent>
          <form onSubmit={this.props.handleSubmit} id="addShowForm">
            <Field name="anime" component={ anime =>
              // <AnimeAutosuggest
              //   label="Show Name"
              //   autoFocus={true}
              //   errorText = {anime.touched && anime.error}
              //   {...anime}
              //   onChange={(_e, newValue) => anime.onChange(newValue)}
              //   onBlur={(_e, f) => anime.onBlur(anime.value)}
              //   fullWidth={true}
              // />
              <TextField
                label="Show"
                error={anime.touched && anime.error}
                FormHelperTextProps={{children: anime.touched && anime.error}}
                {...anime.input}
                 autoFocus={true}
                fullWidth={true}
              />
            }/>
            <Field name="feed_url" component={ feed_url =>
              <TextField
                label="Feed URL"
                error={feed_url.meta.touched && feed_url.meta.error}
                FormHelperTextProps={{children: feed_url.touched && feed_url.error}}
                {...feed_url.input}
                fullWidth={true}
              />
            }/>
            <Field name="auto_fetch" component={ auto_fetch => {
              return <FormControlLabel
                control={
                  <Switch
                    checked={auto_fetch.input.value}
                    {...auto_fetch.input}
                    form="addShowForm"
                  />
                }
                labelPlacement="top"
                label="Auto Fetch"
              />
              }}/>
          </form>
        </DialogContent>
        {this._getActions()}
      </Dialog>
    );
  }
}

NewShowDialogFormPresentation.propTypes = {
  onRequestClose: PropTypes.func.isRequired,
  handleSubmit: PropTypes.func.isRequired,
  submitting: PropTypes.bool.isRequired,
  pristine: PropTypes.bool.isRequired,
}

export default {
  NewShowDialogForm: reduxForm({
    form: 'addShow',
    validate,
    onSubmit,
    initialValues,
  })(withStyles(styles)(NewShowDialogFormPresentation))
}
