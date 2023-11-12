const libraryBadges = {
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
    return libraryBadges["ongoing"];
  } else {
    return libraryBadges[entry.complete ? "ended-complete" : "ended-incomplete"]
  }
};


function librarySection(notif) {
  return {
    libraryBadges,
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
          this.notif.show('Error: Unable to fetch the library!', 'error');
          window.nox = this.notif
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
        notif.show('Error: Unable to fetch the library!', 'error');
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
      return libraryBadges[style];
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
    setNotif(notif) {
      this.notif = notif;
    }
  }
}

function notification() {
  return {
    data: null,
    badgeMap: {
      'success': '✔️',
      'warning': '⚠️',
      'error': '❌'
    },

    show(message, type) {
      this.data = {
        message: message,
        type: type,
        badge: this.badgeMap[type],
      }
      setTimeout(() => {
        this.data = null;
      }, 3000);
    },
  }
}


function data() {
  function mergeScans(oldScans, scanUpdates) {
    // Extract scans from scanUpdates that have entirely new ids
    const newScans = scanUpdates.filter(newScan =>
      !oldScans.some(oldScan => oldScan.id === newScan.id)
    );

    // Merge attributes of updated scans into old scans
    const updatedOldScans = oldScans.map(oldScan => {
      const update = scanUpdates.find(scan => scan.id === oldScan.id);
      return update ? Object.assign({}, oldScan, update) : oldScan;
    });

    return newScans.concat(updatedOldScans);
  }

  const notif = notification();

  return {
    scans: window.initialData.scans,
    hasRun: !!window.initialData.latest_check,
    latestCheck: window.initialData.latest_check || {},
    queriedTimestamp: window.initialData.queried_timestamp,
    activeTab: 'scans',
    notif: notif,
    library: librarySection(notif),


    submitForm: async function () {
      let result;
      try {
        const formData = new FormData(document.querySelector(".request-scan form"));
        const response = await fetch('/start_scan', {
          method: 'POST',
          body: formData,
        });
        result = await response.json();
      } catch (error) {
        console.error("Error while starting scan:", error);
        this.notif.show('Error: Something went wrong!', 'error')
      }

      // Handle notifications
      switch (result.scan_enque_result) {
        case 'started':
          this.notif.show('Scan started successfully!', 'success');
          break;
        case 'waiting':
          this.notif.show('Scan already running', 'warning');
          break;
        case 'rejected':
          this.notif.show('Scan rejected', 'error');
          break;
        case 'no_files':
          this.notif.show('No New Files', 'warning');
          break;
        default:
          throw new Error(`Unknown scan_enque_result: ${result.scan_enque_result}`);
      }
      this.updateState(result.updates)
    },
    updateState(newState) {
      this.hasRun = true
      Object.assign(this.latestCheck, newState.latest_check);
      this.scans = mergeScans(this.scans, newState.scans);
      if (newState.library) {
        this.library.mergeUpdates(newState.library)
      }
      this.queriedTimestamp = newState.queried_timestamp;
    },

    init() {
      this.$watch('latestCheck.scan_in_progress', (value) => {
        if (value) {
          this.startSSE();
        } else {
          this.stopSSE();
        }
      });
      if (this.latestCheck.scan_in_progress) {
        this.startSSE();
      }
      window.scans = this.scans
      this.library.setNotif(this.notif)
    },
    startSSE() {
      if (!this.eventSource) {
        const queriedTimestampParam = `queried-timestamp=${this.queriedTimestamp}`;
        this.eventSource = new EventSource(`/refresh?${queriedTimestampParam}`);
        this.eventSource.onmessage = (event) => {
          const data = JSON.parse(event.data);
          this.updateState(data)
        };

        this.eventSource.onerror = (error) => {
          console.error('EventSource failed:', error);
          this.eventSource.close();
          this.eventSource = null;
        };
      }
    },
    stopSSE() {
      if (this.eventSource) {
        this.eventSource.close();
        this.eventSource = null;
      }
    },
    setActiveTab(tabName) {
      this.activeTab = tabName;
      if (tabName === 'library') {
        this.library.maybeLoad()
      }
    },
    isTabActive(tabName) {
      return this.activeTab === tabName;
    },
  }
}
