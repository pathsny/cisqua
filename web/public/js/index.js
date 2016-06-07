'use strict';

import React from 'react';
import {render} from 'react-dom';
import injectTapEventPlugin from 'react-tap-event-plugin';

import App from './components/app'

// Needed by Material UI
injectTapEventPlugin();

render(<App/>, document.getElementById('app'));

