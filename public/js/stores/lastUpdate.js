function isValidDate(value) {
  return value instanceof Date && !Number.isNaN(value.getTime());
}

function makeConnection() {
  const connection = {
    connected: false,
    isConnected: false,
    disconnected_at: new Date(),
    timeSinceDisconnected: null,
    queried_at: null,
    queried_timestamp: null,
    timeSinceLastQueried: null,
    update(updateData) {
      const { queried_at, ...rest } = updateData
      Object.assign(this, {
        ...rest,
        queried_timestamp: queried_at,
        queried_at: queried_at && new Date(queried_at * 1000),
      });
    },
    setConnected() {
      this.connected = true;
      this.disconnected_at = null;
      this.isConnected = true;
    },
    setDisconnected() {
      if (this.connected) {
        this.connected = false;
        this.disconnected_at = new Date();
      }
    },
  }
  connection.setDisconnected();
  return connection;
}

function makeScansUpdate() {
  return {
    update(updateData) {
      const { checked_at, scanned_at, ...rest } = updateData
      Object.assign(this, {
        ...rest,
        checked_at: checked_at && new Date(checked_at * 1000),
        scanned_at: scanned_at && new Date(scanned_at * 1000),
      })
    },
    get hasRun() {
      return !!this.scanned_at;
    },
    get scanInProgress() {
      return !!this.scan_in_progress;
    },
    get scannedDate() {
      if (!isValidDate(this.scanned_at)) {
        return '';
      }
      return dateFns.format(this.scanned_at, 'EEE, yyyy-MM-dd')
    },
    get scannedTime() {
      if (!isValidDate(this.scanned_at)) {
        return '';
      }
      return dateFns.format(this.scanned_at, 'HH:mm:ss')
    }
  }
}

function makeTorrentsUpdate() {
  return {
    update(updateData) {
      const { synced_at, ...rest } = updateData
      Object.assign(this, {
        ...rest,
        synced_at: synced_at && new Date(synced_at * 1000)
      })
    }
  }
}

function makeLastUpdate() {
  return {
    connection: makeConnection(),
    scans: makeScansUpdate(),
    torrents: makeTorrentsUpdate(),
    init() {
      this.update(window.initialData.last_update);
      setInterval(() => {
        this.updateTimeSince();
      }, 1000);
    },
    update(updateData) {
      if (updateData.scans) {
        this.scans.update(updateData.scans);
      }
      if (updateData.connection) {
        this.connection.update(updateData.connection);
      }
      if (updateData.torrents) {
        this.torrents.update(updateData.torrents);
      }
    },
    updateTimeSince() {
      this.scans.timeSinceLastCheck = isValidDate(this.scans.checked_at) ?
        dateFns.formatDistanceToNow(
          this.scans.checked_at,
          { addSuffix: true },
        ) :
        '';
      if (this.connection.connected) {
        this.connection.timeSinceDisconnected = '';
      } else {
        const now = new Date();
        if (
          isValidDate(this.connection.disconnected_at) &&
          dateFns.differenceInMinutes(now, this.connection.disconnected_at) > 1
        ) {
          this.connection.isConnected = false;
        }
        this.connection.timeSinceDisconnected = isValidDate(this.connection.disconnected_at) ?
          dateFns.formatDistance(
            this.connection.disconnected_at,
            now,
            { addSuffix: true },
          ) :
          '';
      }
      this.connection.timeSinceLastQueried = isValidDate(this.connection.queried_at) ?
        dateFns.formatDistanceToNow(
          this.connection.queried_at,
          { addSuffix: true },
        ) :
        '';
      this.torrents.timeSinceLastSync = isValidDate(this.torrents.synced_at) ?
        dateFns.formatDistanceToNow(
          this.torrents.synced_at,
          { addSuffix: true },
        ) :
        '';
    },
  }
}

const lastUpdate = makeLastUpdate();
export default lastUpdate;
