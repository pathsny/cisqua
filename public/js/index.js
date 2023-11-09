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
  return {
    notification: null,
    scans: window.initialData.scans,
    hasRun: !!window.initialData.latest_check,
    latestCheck: window.initialData.latest_check || {},
    queriedTimestamp: window.initialData.queried_timestamp,
    badgeMap: {
      'success': '✔️',
      'warning': '⚠️',
      'error': '❌'
    },
    activeTab: 'scans',

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
        this.showNotification('Error: Something went wrong!', 'error')
      }

      // Handle notifications
      switch (result.scan_enque_result) {
        case 'started':
          this.showNotification('Scan started successfully!', 'success');
          break;
        case 'waiting':
          this.showNotification('Scan already running', 'warning');
          break;
        case 'rejected':
          this.showNotification('Scan rejected', 'error');
          break;
        case 'no_files':
          this.showNotification('No New Files', 'warning');
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
      this.queriedTimestamp = newState.queried_timestamp;
    },

    showNotification(message, type) {
      this.notification = {
        message: message,
        type: type,
        badge: this.badgeMap[type],
      }
      setTimeout(() => {
        this.notification = null;
      }, 3000);
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
  }
}
