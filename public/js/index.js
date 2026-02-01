import statusBadges from './stores/statusBadges.js';
import lastUpdate from './stores/lastUpdate.js';
import library from './stores/library.js';
import scans from './stores/scans.js';
import notification from './stores/notification.js';
import torrents from './stores/torrents.js';
import mainTab from './viewModels/mainTab.js';
import scanShow from './viewModels/scanShow.js';
import torrentFiles from './viewModels/torrentFiles.js';
import searchLibrary from './viewModels/searchLibrary.js';
import requestScanForm from './viewModels/requestScanForm.js';
import versionOverlay from './viewModels/versionOverlay.js';
import mainService from './services/mainService.js';
import { notify, copyText } from './utils/utils.js';

document.addEventListener('alpine:init', () => {
  // Register Stores
  Alpine.store('statusBadges', statusBadges);
  Alpine.store('lastUpdate', lastUpdate)
  Alpine.store('library', library);
  Alpine.store('scansData', scans);
  Alpine.store('notification', notification);
  Alpine.store('torrents', torrents);

  // Register ViewModels
  Alpine.data('mainTab', () => mainTab);
  Alpine.data('scanShow', () => scanShow());
  Alpine.data('searchLibrary', () => searchLibrary());
  Alpine.data('requestScanForm', (dryRun) => requestScanForm(dryRun));
  Alpine.data('torrentFiles', (torrent) => torrentFiles(torrent));
  Alpine.data('versionOverlay', () => versionOverlay());

  // Register Magic Functions
  Alpine.magic('notify', () => {
    return (notifData) => notify(notifData);
  });
  Alpine.magic('getAnime', () => {
    return (aid) => Alpine.store('library').animeDetails.get(aid);
  });
  Alpine.magic('copyText', () => {
    return (elem) => copyText(elem)
  });
  mainService.start();
});
