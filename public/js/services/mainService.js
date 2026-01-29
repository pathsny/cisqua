const mainService = {
  eventSource: null,
  start() {
    this.connect();
  },
  updateStores(data) {
    Alpine.store('lastUpdate').update(data.last_update)
    if (data.library) {
      Alpine.store('library').update(data.library)
    }
    if (data.scans) {
      Alpine.store('scansData').update(data.scans)
    }
    if (data.torrents) {
      Alpine.store('torrents').update(data.torrents)
    }
  },
  connect() {
    if (!this.eventSource) {
      const timestamp = Alpine.store('lastUpdate').connection.queried_timestamp
      const queriedTimestampParam = `queried_timestamp=${timestamp}`;
      this.eventSource = new EventSource(`/refresh?${queriedTimestampParam}`);
      this.eventSource.onopen = () => {
        Alpine.store('lastUpdate').connection.setConnected();
      };
      this.eventSource.onmessage = (event) => {
        const data = JSON.parse(event.data);
        this.updateStores(data)
      };
      this.eventSource.onerror = (_error) => {
        if (this.eventSource.readyState === EventSource.CLOSED) {
          Alpine.store('lastUpdate').connection.setDisconnected();
          if (!_error.message?.includes('timeout')) {
            console.log('EventSource connection closed unexpectedly');
          }
        }
      };
    }
  },
}

export default mainService;
