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

function librarySection() {
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
          this.$dispatch('show-notification', { type: 'error', message: 'Error: Unable to fetch the library!' })
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
        this.$dispatch('show-notification', { type: 'error', message: 'Error: Unable to fetch the library!' })
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
    show(notifData) {
      this.data = {
        ...notifData,
        badge: this.badgeMap[notifData.type],
      }
      setTimeout(() => {
        this.data = null;
      }, 3000);
    }
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
    library: librarySection(),


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
        this.$dispatch('show-notification', { type: 'error', message: 'Error: Something went wrong!' })
      }

      // Handle notifications
      switch (result.scan_enque_result) {
        case 'started':
          this.$dispatch('show-notification', { type: 'success', message: 'Scan started successfully!' })
          break;
        case 'waiting':
          this.$dispatch('show-notification', { type: 'warning', message: 'Scan already running' })
          break;
        case 'rejected':
          this.$dispatch('show-notification', { type: 'error', message: 'Scan rejected' })
          break;
        case 'no_files':
          this.$dispatch('show-notification', { type: 'warning', message: 'No New Files' })
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