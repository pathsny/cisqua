'use strict';

import React from 'react';
import {render} from 'react-dom';
import injectTapEventPlugin from 'react-tap-event-plugin';

import Main from './components/main'

// Needed by Material UI
injectTapEventPlugin();

render(<Main/>, document.getElementById('app'));

