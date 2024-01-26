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
  'unknown-file': {
    wrapperClass: 'unknown-file',
    icon: 'fas fa-file-circle-question',
    statusTooltip: 'Unknown File',
  }
}

function getBadgeDetails(entry) {
  if (!entry.ended) {
    // Ongoing Collection
    return statusBadges["ongoing"];
  } else {
    return statusBadges[entry.complete ? "ended-complete" : "ended-incomplete"]
  }
};

function makeLibrary() {
  return {
    libraryData: {},
    libraryState: null,
    libraryCards: {},
    maybeLoad() {
      if (!this.libraryState) {
        this.fetchLibrary();
      }
    },
    async fetchLibrary() {
      try {
        this.libraryState = 'loading';
        const response = await fetch('/library');
        if (!response.ok) {
          console.error("Error fetching library:", response);
          notify({
            type: 'error',
            message: `Error: Unable to fetch the library: ${error}`
          });
          this.libraryState = 'error';
          return
        }
        const library = await response.json();
        this.libraryData = {};
        this.libraryCards = {};
        this.libraryState = 'loaded';
        this.mergeUpdates(library)
      } catch (error) {
        console.error("Error fetching library:", error);
        notify({ type: 'error', message: `Error: Something went wrong! ${error.message}` })
      }
    },
    mergeUpdates(libraryUpdates) {
      if (this.libraryState != 'loaded') {
        return
      }
      for (const entry of libraryUpdates) {
        this.libraryData[entry.id] = entry;
        this.libraryCards[entry.id] = this.libraryCard(entry);
      }
    },
    libraryBadgeData(style) {
      return statusBadges[style];
    },
    libraryCard(entry) {
      const card_data = {
        id: entry.id,
        name: entry.name,
        type: entry.type,
        eps: entry.eps,
        air_date: entry.air_date,
        end_date: entry.end_date,
        english_name: entry.english_name,
        badge: getBadgeDetails(entry),

        contents() {
          return entry.eps_w_grps
        },
      };
      return card_data;
    },
  }
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

function makeScansData() {
  return {
    init() {
      this.scans = window.initialData.scans;
    },
    update(data) {
      const newScans = data.filter(newScan =>
        !this.scans.some(scan => scan.id === newScan.id)
      );

      const updatedScans = this.scans.map(scan => {
        const update = data.find(updatedScan => updatedScan.id === scan.id);
        return update ? Object.assign({}, scan, update) : scan;
      });

      this.scans = newScans.concat(updatedScans);
    }
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
    Alpine.store('lastUpdate').update(data.last_update);
    Alpine.store('scansData').update(data.scans);
    if (data.library) {
      Alpine.store('library').mergeUpdates(data.library);
    }
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
    if (tabName === 'library') {
      Alpine.store('library').maybeLoad();
    }
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
  })
});
