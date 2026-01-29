import { makeStringWithPills, fileTransferSize } from "../utils/utils.js"

function makeStatusContent(torrentData) {
  switch (torrentData.status) {
    case 0:
      return {
        content: 'Stopped',
        type: 'stopped',
      };
    case 1:
      return {
        content: 'Verifying',
        queue: true,
        type: 'verifying',
      };
    case 2:
      return {
        content: 'Verifying',
        type: 'verifying',
      };
    case 3:
      return {
        content: 'Downloading',
        queue: true,
        type: 'downloading',
      };
    case 4:
      return {
        content: 'Downloading',
        type: 'downloading',
      };
    case 5:
      return {
        content: 'Seeding',
        queue: true,
        type: 'seeding',
      };
    case 6:
      return {
        content: 'Seeding',
        type: 'seeding',
      };
    default:
      return {
        content: 'Unknown status',
        type: 'unknown',
      };
  }
}

function nestFilesByFolders(files) {
  const root = {
    folders: {},
    files: [],
  };

  files.forEach(file => {
    const parts = file.name.split('/');
    let current = root;

    parts.forEach((part, index) => {
      if (index === parts.length - 1) {
        const percent_done = (file.bytes_completed / file.length * 100).toFixed(1);
        current.files.push({ file_path: file.name, ...file, name: part, percent_done });
      } else {
        current.folders[part] = current.folders[part] || { folders: {}, files: [] };
      }
      current = current.folders[part];
    });
  });
  return root;
}

// Post process the folder structure. We will do two things:
//  - Add metadata to each folder that summarizes the children.
//  - Eleminate folders that only contain a single child folder.
function postProcessFolders(nameParts, folder) {
  let inputSubFolders = Object.entries(folder.folders)
  let files = folder.files
  while (nameParts.length > 0 && inputSubFolders.length == 1 && files.length == 0) {
    let [name, folder] = inputSubFolders[0]
    nameParts.push(name)
    inputSubFolders = Object.entries(folder.folders)
    files = folder.files
  }


  const subFolders = inputSubFolders.
    sort((a, b) => a[0].localeCompare(b[0])).
    map(([name, folder]) => postProcessFolders([name], folder))

  const children = [...subFolders, ...files]
  const metadata = {
    wanted: false,
    completed: true,
    length: 0,
    bytes_completed: 0,
  }
  children.forEach(child => {
    metadata.wanted = metadata.wanted || child.wanted
    metadata.completed = metadata.completed && (child.completed || !child.wanted)
    metadata.length += child.wanted ? child.length : 0
    metadata.bytes_completed += child.wanted ? child.bytes_completed : 0
  })
  return {
    nameParts,
    folders: subFolders,
    files: files,
    ...metadata,
    percent_done: metadata.wanted ? (metadata.bytes_completed / metadata.length * 100).toFixed(1) : 0,
  }
}


function flattenFileStructure(folderStructure, level = 0, parents = []) {
  const result = [];
  folderStructure.folders.forEach(innerFolder => {
    result.push({
      type: 'folder',
      nameParts: innerFolder.nameParts,
      level,
      parents,
      wanted: innerFolder.wanted,
      completed: innerFolder.completed,
      length: innerFolder.length,
      bytes_completed: innerFolder.bytes_completed,
      percent_done: innerFolder.percent_done,
    });
    result.push(...flattenFileStructure(
      innerFolder,
      level + 1,
      [...parents, ...innerFolder.nameParts],
    ));
  });

  folderStructure.files
    .sort((a, b) => a.name.localeCompare(b.name))
    .forEach(file => {
      result.push({ type: 'file', level, parents, ...file });
    });

  return result;
}


function makeTorrent(torrentData) {
  const status = makeStatusContent(torrentData)
  const isComplete = torrentData.percent_done == 100
  const nestedFiles = nestFilesByFolders(torrentData.files);
  const nestedFolderStructure = postProcessFolders([], nestedFiles)
  const flatFileList = flattenFileStructure(nestedFolderStructure);
  const displayETA = torrentData.eta >= 0 ?
    dateFns.formatDistanceToNow(dateFns.addSeconds(new Date(), torrentData.eta)) :
    (torrentData.eta == -1 ? 'Not Available' : 'Unknown')
  return {
    ...torrentData,
    nameParts: makeStringWithPills(torrentData.name),
    status,
    isComplete,
    nestedFolderStructure,
    flatFileList,
    displayETA,
    size_when_done: filesize(torrentData.size_when_done),
    total_size: filesize(torrentData.total_size),
    rate_download: fileTransferSize(torrentData.rate_download),
    rate_upload: fileTransferSize(torrentData.rate_upload),
  }
}

function makeTorrents() {
  return {
    torrents: [],
    init() {
      this.torrents = window.initialData.torrents.map((data) => makeTorrent(data));
    },
    update(torrentsData) {
      const newTorrents = torrentsData.map(d => makeTorrent(d))
      const existingTorrentsMap = new Map(this.torrents.map(
        torrent => [torrent.hash_string, torrent]
      ));
      const mergedTorrents = newTorrents.reduce((acc, newTorrent) => {
        acc.push(newTorrent);
        if (existingTorrentsMap.has(newTorrent.hash_string)) {
          existingTorrentsMap.delete(newTorrent.hash_string);
        }
        return acc;
      }, []);
      mergedTorrents.push(...Array.from(existingTorrentsMap.values()));
      this.torrents = mergedTorrents.sort((a, b) => b.added_at - a.added_at);
    }
  }
}

const torrents = makeTorrents();

export default torrents;
