function invariant(condition, message) {
  if (condition) {
    return
  }
  throw new Error(`Invariant Failure: ${message}`)
}

function invariantIsBool(value, message) {
  return invariant(typeof value === 'boolean', message);
}

const utils = {
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  },
  copyText(aid) {
    navigator.clipboard.writeText(aid)
  },
  // Remove the proxy stuff
  dd(obj) {
    return JSON.parse(JSON.stringify(obj))
  },
}

const statusBadges = {
  'ongoing': {
    wrapperClass: 'ongoing',
    icon: 'fas fa-sync',
    statusTooltip: 'Ongoing',
  },
  'ended-complete': {
    wrapperClass: 'ended-complete',
    icon: 'fas fa-check-circle',
    statusTooltip: 'Ended (Complete)',
  },
  'ended-incomplete': {
    wrapperClass: 'ended-incomplete',
    icon: 'fas fa-exclamation-circle',
    statusTooltip: 'Ended (InComplete)',
  },
  forAnime(anime) {
    invariantIsBool(anime.ended, 'Anime must have ended property');
    invariantIsBool(anime.complete, 'Anime must have ended property');
    if (!anime.ended) {
      return this['ongoing'];
    }
    return this[anime.complete ? "ended-complete" : "ended-incomplete"]
  }
}

function makeAnime(anime_data) {
  return {
    ...anime_data,
    image: anime_data.has_image ? `a${anime_data.id}.jpg` : 'missing.png',
    thumb: anime_data.has_image ? `a${anime_data.id}_t.jpg` : 'missing.png',
    contents: anime_data.eps_w_grps,
    get badge() {
      if (this.ended) {
        // Ongoing Collection
        return statusBadges[this.complete ? "ended-complete" : "ended-incomplete"]
      } else {
        return statusBadges["ongoing"];
      }
    },
    hasSpecials() {
      return this.special_ep_count > 0;
    },
  };
}

const libraryBaseUrl = '/library?limit=20';

function makeLibrary() {
  return {
    animeDetails: new Map(),
    reset() {
      this.error = null;
      this.loadingState = 'init';
      this.animeIds = [];
      this.nextCursor = null;
    },
    init() {
      this.reset();
      // We only record the data, but we don't add these to the library list.
      // Once we fetch the list comprehensively, animes will be ordered.
      this.update(window.initialData.library);
    },
    async fetchLibrary() {
      if (this.loadingState == 'loading' || this.loadingState == 'error') {
        return; // prevent concurrent fetches
      }
      if (this.loadingState !== 'init' && !this.nextCursor) {
        return; // we've reached the end
      }
      this.loadingState = 'loading';
      const url = this.nextCursor ?
        `${libraryBaseUrl}&cursor=${encodeURIComponent(this.nextCursor)}` :
        libraryBaseUrl;

      try {
        const response = await fetch(url);
        if (!response.ok) {
          console.error("Error fetching library:", response);
          notify({
            type: 'error',
            message: `Error: Unable to fetch the library: ${error}`
          });
          this.loadingState = 'error';
          return
        }
        const { library_data, next_cursor } = await response.json();
        this.appendAnimes(library_data);
        this.nextCursor = next_cursor;
        this.loadingState = 'loaded';
      } catch (error) {
        console.error(error);
        notify({
          type: 'error',
          message: `Error: Unable to fetch the library: ${error}`
        });
        this.loadingState = 'error';
        this.error = error;
      }
    },
    lastIsAfter(name) {
      const last = this.animeIds.slice(-1)[0];
      return last && this.animeDetails.get(last).name.localeCompare(name) > 0;
    },
    async fetchTill(name) {
      while (!this.lastIsAfter(name) && this.nextCursor) {
        await this.fetchLibrary();
      }
    },
    appendAnimes(library_data) {
      library_data.forEach(anime_data => {
        this.animeIds.push(anime_data.id);
        this.animeDetails.set(anime_data.id, makeAnime(anime_data));
      });
    },
    update(library_data) {
      library_data.forEach(anime_data => this.insertAnime(anime_data));
    },
    // These are updates that are not necessarily in sorted order.
    insertAnime(anime_data) {
      // We always store the data in the overall map
      const newAnime = makeAnime(anime_data);
      this.animeDetails.set(anime_data.id, newAnime);
      if (this.loadingState == 'error' || this.loadingState == 'init') {
        return; // We've not started fetching the library.
      }

      let index = this.animeIds.findIndex(id => {
        return this.animeDetails.get(id).name.localeCompare(newAnime.name) >= 0;
      })
      if (this.animeIds[index] === newAnime.id) {
        return; // element already exists
      }
      if (index >= 0) {
        // Insert at the found index
        this.animeIds.splice(index, 0, newAnime.id);
      } else {
        // no Index was found. It's only safe to insert at the end if we've
        // fetched the entire library. That way we will not change the order of shows.
        if (!this.nextCursor) {
          this.animeIds.push(newAnime.id);
        }
      }
    },
    hasMoreItems() {
      if (this.loadingState == 'error') {
        return false;
      }
      if (this.loadingState == 'init' || this.loadingState == 'loading') {
        return true;
      }
      return !!this.nextCursor;
    },
    refetchLibrary() {
      this.reset();
      return this.fetchLibrary();
    },
    get isLoading() {
      return this.loadingState == 'loading'
    },
  };
}

const notification = {
  data: null,
  badgeMap: {
    'success': '✔️',
    'warning': '⚠️',
    'error': '❌'
  },
  show(notifData) {
    this.data = {
      ...notifData,
      css_class: notifData.type,
      badge: this.badgeMap[notifData.type],
    }
    setTimeout(() => {
      this.data = null;
    }, 3000);
  }
};

function notify(notifData) {
  Alpine.store('notification').show(notifData);
}

function makeLastUpdate() {
  return {
    init() {
      this.update(window.initialData.last_update);
    },
    update(update_data) {
      Object.assign(this, update_data);
    },
    get hasRun() {
      return !!this.updated_timestamp;
    },
    get scanInProgress() {
      return !!this.scan_in_progress;
    }
  }
}

function makeScan(scan) {
  return {
    ...scan,
    updates: scan.updates.map(anime_updates => {
      return {
        ...anime_updates,
        final_status: anime_updates.latest,
      };
    }),
  };
}

function makeScansData() {
  return {
    init() {
      this.scans = window.initialData.scans.map((scan) => makeScan(scan));
    },
    update(data) {
      const newScans = data.map(scan => makeScan(scan));
      const unmodifiedScans = this.scans.filter(scan => {
        isUpdated = data.find(updatedScan => updatedScan.id === scan.id);
        return !isUpdated;
      });

      this.scans = newScans.concat(unmodifiedScans);
    },
  }
}

function scanShow() {
  const noHover = {
    aid: null,
    scanId: null,
    anchorId: 'scans',
    anime: null,
  };
  return {

    init() {
      this.hover = noHover;
      this.nextShow = null;
      this.clearTimeoutHandle = null;
      this.showTimeoutHandle = null;
    },
    cancelShow() {
      clearTimeout(this.showTimeoutHandle);
      this.showTimeoutHandle = null;
      this.nextShow = null;
    },
    cancelClear() {
      clearTimeout(this.clearTimeoutHandle);
      this.clearTimeoutHandle = null;
    },
    setShow(show) {
      if (!show) {
        this.hover = noHover;
      } else {
        this.hover = {
          ...show,
          anchorId: `${show.scanId}-${show.aid}-img`,
          get anime() {
            return Alpine.store('library').animeDetails.get(this.aid);
          },
        };
      }
    },
    setHoverAnime(scanId, aid) {
      if (this.hover.scanId === scanId && this.hover.aid === aid) {
        // cancel any timers and next steps if we're back on the same show.
        this.cancelClear();
        this.cancelShow();
        return
      }
      if (this.nextShow?.scanId === scanId && this.nextShow?.aid === aid) {
        // this is already the plan
        return;
      }
      // we allow a clear timer to run if there is one.
      this.cancelShow();

      this.nextShow = { aid, scanId };
      this.showTimeoutHandle = setTimeout(
        () => {
          this.showTimeoutHandle = null;
          this.setShow(this.nextShow);
          this.nextShow = null;
        },
        500
      );
    },
    clearHoverAnime() {
      if (this.showTimeoutHandle) {
        // never pop up a card we were about to if asked to clear
        this.cancelShow();
      }
      if (this.clearTimeoutHandle) {
        return;
      }
      if (!this.hover.aid) {
        return
      }
      this.clearTimeoutHandle = setTimeout(() => {
        this.clearTimeoutHandle = null;
        this.setShow(null);
      }, 200);
    },
    onEnterHoverCard() {
      invariant(this.hover.aid, 'must be true if we enter the hover card');
      this.setHoverAnime(this.hover.scanId, this.hover.aid);
    },
    onLeaveHoverCard() {
      this.clearHoverAnime();
    },
  }
}

const mainService = {
  eventSource: null,
  init() {
    if (Alpine.store('lastUpdate').scanInProgress) {
      this.start();
    }
  },
  updateStores(data) {
    Alpine.store('lastUpdate').update(data.last_update)
    Alpine.store('scansData').update(data.scans)
    Alpine.store('library').update(data.library)
    if (Alpine.store('lastUpdate').scanInProgress) {
      this.start();
    }
    if (!Alpine.store('lastUpdate').scanInProgress) {
      this.stop();
    }
  },
  start() {
    if (!this.eventSource) {
      timestamp = Alpine.store('lastUpdate').checked_timestamp
      const queriedTimestampParam = `queried_timestamp=${timestamp}`;
      this.eventSource = new EventSource(`/refresh?${queriedTimestampParam}`);
      this.eventSource.onmessage = (event) => {
        const data = JSON.parse(event.data);
        this.updateStores(data)
      };

      this.eventSource.onerror = (error) => {
        console.error('EventSource failed:', error);
        this.eventSource.close();
        this.eventSource = null;
      };
    }
  },
  stop() {
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
  }
}

const mainTab = {
  activeTab: window.location.hash ? window.location.hash.substring(1) : 'scans',
  isScrolled: { scans: false, library: false },
  setActiveTab(tabName) {
    this.activeTab = tabName;
    history.pushState({ tab: tabName }, '', `#${tabName}`);
  },
  isTabActive(tabName) {
    return this.activeTab === tabName;
  },
  scrollToTop(elem) {
    elem.scrollTo({ top: 0, behavior: 'smooth' });
  }
};

function formHandler(initialDryRun) {
  return {
    formData: {
      debug_mode: false,
      dry_run: initialDryRun,
      queried_timestamp: ''
    },
    async submitForm() {
      let result;
      try {
        this.formData.queried_timestamp = Alpine.store('lastUpdate').checked_timestamp;
        const response = await fetch('/start_scan', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(this.formData),
        });
        result = await response.json();
      } catch (error) {
        console.error("Error while starting scan:", error);
        notify({ type: 'error', message: `Error: Something went wrong! ${error.message}` })
      }
      switch (result.scan_enque_result) {
        case 'started':
          notify({ type: 'success', message: 'Scan started successfully!' })
          break;
        case 'waiting':
          notify({ type: 'warning', message: 'Scan already running' })
          break;
        case 'rejected':
          notify({ type: 'error', message: 'Scan rejected' })
          break;
        case 'no_files':
          notify({ type: 'warning', message: 'No New Files' })
          break;
        default:
          throw new Error(`Unknown scan_enque_result: ${result.scan_enque_result}`);
      }
      mainService.updateStores(result.updates);
    },
  }
}


document.addEventListener('alpine:init', () => {
  Alpine.store('statusBadges', statusBadges);
  Alpine.store('lastUpdate', makeLastUpdate())
  Alpine.store('library', makeLibrary());
  Alpine.store('scansData', makeScansData());
  Alpine.store('notification', notification);
  Alpine.magic('notify', () => {
    return (notifData) => notify(notifData);
  });
  Alpine.magic('getAnime', () => {
    return (aid) => Alpine.store('library').animeDetails.get(aid);
  });
});
