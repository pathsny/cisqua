import makeScan from '../models/makeScan.js';

function makeScansData() {
  return {
    init() {
      this.scans = window.initialData.scans.map((scan) => makeScan(scan));
    },
    update(data) {
      const newScans = data.map(scan => makeScan(scan));
      const unmodifiedScans = this.scans.filter(scan => {
        const isUpdated = data.find(updatedScan => updatedScan.id === scan.id);
        return !isUpdated;
      });

      this.scans = newScans.concat(unmodifiedScans);
    },
  }
}

const scans = makeScansData();
export default scans;
