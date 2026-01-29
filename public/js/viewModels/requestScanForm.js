import { notify } from '../utils/utils.js';
import mainService from '../services/mainService.js';

function requestScanForm(initialDryRun) {
  return {
    formData: {
      debug_mode: false,
      dry_run: initialDryRun,
      queried_timestamp: ''
    },
    async submitForm() {
      let result;
      try {
        const queried_timestamp = Alpine.store('lastUpdate').connection.queried_timestamp
        this.formData.queried_timestamp = queried_timestamp;
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

export default requestScanForm;
