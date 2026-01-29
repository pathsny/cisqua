import { copyText, notify, invariant } from '../utils/utils.js';



const videoExtensions = ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'];
const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg', 'webp'];
const musicExtensions = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma'];
const specialNfo = ['nfo'];


function torrentFiles(torrent) {
  return {
    init() {
      this.initalizeCollapsedState(torrent.nestedFolderStructure, this.collapsedState)
    },
    showFileList: false,
    collapsedState: {},
    isInsideCollapsedFolder(item) {
      return this.navigateToFolderHelper(
        [...item.parents],
        (midItem) => !midItem.__collapsed,
        (midItem) => midItem.__collapsed,
      );
    },
    toggleCollapse(item) {
      const container = this.navigateToFolderHelper(
        [...item.parents, item.nameParts[0]],
        () => true,
        (midItem) => midItem,
      );
      container.__collapsed = !container.__collapsed;
    },
    isCollapsed(item) {
      return this.navigateToFolderHelper(
        [...item.parents, item.nameParts[0]],
        (midItem) => !midItem.__collapsed,
        (midItem) => midItem.__collapsed,
      );
    },
    initalizeCollapsedState(nestedFolderStructure, collapsedState) {
      let nextState = collapsedState;
      if (nestedFolderStructure.nameParts.length !== 0) {
        const key = nestedFolderStructure.nameParts[0];
        invariant(!collapsedState[key], 'collapsedState is not initialized');
        nextState = {
          __collapsed: !nestedFolderStructure.wanted
        }
        collapsedState[key] = nextState;
      }
      nestedFolderStructure.folders.forEach(
        (folder) => this.initalizeCollapsedState(folder, nextState)
      )
    },
    navigateToFolderHelper(path, continueFn, returnFn, viewItem = this.collapsedState) {
      if (path.length === 0 || !continueFn(viewItem)) {
        return returnFn(viewItem);
      }
      const [first, ...rest] = path;
      viewItem = viewItem[first];
      return this.navigateToFolderHelper(rest, continueFn, returnFn, viewItem);
    },
    fileType(item) {
      const extension = item.name.split('.').pop().toLowerCase();
      if (videoExtensions.includes(extension)) {
        return 'video';
      } else if (imageExtensions.includes(extension)) {
        return 'image';
      } else if (musicExtensions.includes(extension)) {
        return 'audio';
      } else if (specialNfo.includes(extension)) {
        return 'special';
      } else {
        return 'unknown';
      }
    },
    fileIcon(item) {
      const type = this.fileType(item);
      if (type === 'video') {
        return 'fa-file-video';
      } else if (type === 'image') {
        return 'fa-file-image';
      } else if (type === 'audio') {
        return 'fa-file-audio';
      } else if (type === 'special') {
        return 'fa-file-code';
      } else {
        return 'fa-file';
      }
    },
    size(item) {
      return filesize(item.length);
    },
    fileStatusText(item) {
      if (item.completed) {
        return '(Complete)';
      }
      return '';
    },
    copyPath(item) {
      const parts = (item.type === 'file') ?
        [...item.parents, item.name] :
        [...item.parents, item.nameParts]
      const path = parts.join('/')
      console.log(item.wanted, item.completed)
      copyText(path)
      notify({
        type: 'success',
        message: `Copied ${path} to Clipboard`
      });
    }
  }
}

export default torrentFiles;
