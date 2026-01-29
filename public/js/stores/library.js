import makeAnime from '../models/makeAnime.js';
import { notify } from '../utils/utils.js';

const libraryBaseUrl = '/library?limit=20';

function makeLibrary() {
  return {
    animeDetails: new Map(),
    reset() {
      this.error = null;
      this.loadingState = 'init';
      this.animeIds = [];
      this.animeIdsBySearchTerm = new Map();
      this.totalAnimeCount = 0;
      this.nextCursor = null;
    },
    init() {
      this.reset();
      // We only record the data, but we don't add these to the library list.
      // Once we fetch the list comprehensively, animes will be ordered.
      this.update(window.initialData.library);
    },
    getAnimes(searchTerm) {
      const animes = this.animeIds.map(id => this.animeDetails.get(id))
      if (!searchTerm) {
        return animes
      } else {
        const existing = this.animeIdsBySearchTerm.get(searchTerm)
        const existing_ids = existing ? existing['ids'] : []
        return existing_ids.map(id => this.animeDetails.get(id))
      }
    },
    animeCount(searchTerm) {
      if (!searchTerm) {
        return this.totalAnimeCount;
      } else {
        const existing = this.animeIdsBySearchTerm.get(searchTerm)
        return existing ? existing['total_count'] : null
      }
    },
    fetchMore(searchTerm) {
      return searchTerm ? this.searchLibrary(searchTerm) : this.fetchLibrary()
    },
    async searchLibrary(searchTerm) {
      if (this.loadingState == 'loading' || this.loadingState == 'error') {
        return; // prevent concurrent fetches
      }
      const baseUrl = `${libraryBaseUrl}&search=${encodeURIComponent(searchTerm)}`
      const fetchNext = async (cursor) => {
        const url = cursor ? `${baseUrl}&cursor=${encodeURIComponent(cursor)}` : baseUrl;
        const response = await fetch(url);
        if (!response.ok) {
          console.error("Error fetching library:", response);
          notify({
            type: 'error',
            message: `Error: Unable to fetch the library: ${error}`
          });
          this.loadingState = 'error';
          return
        }
        const { library_data, next_cursor, count } = await response.json();
        const existing = this.animeIdsBySearchTerm.get(searchTerm)
        const existing_ids = existing ? existing['ids'] : [];
        library_data.forEach(anime_data => {
          if (!existing_ids.includes(anime_data.id)) {
            existing_ids.push(anime_data.id);
            this.animeDetails.set(anime_data.id, makeAnime(anime_data));
          }
        });
        const total_count = cursor ? existing['total_count'] : count;

        this.animeIdsBySearchTerm.set(searchTerm, {
          ids: existing_ids,
          fetchedAll: next_cursor ? false : true,
          total_count: total_count,
        });
        if (next_cursor) {
          setTimeout(() => fetchNext(next_cursor), 0);
        }
      }
      fetchNext();
    },
    async fetchLibrary() {
      if (this.loadingState == 'loading' || this.loadingState == 'error') {
        return; // prevent concurrent fetches
      }
      if (this.loadingState !== 'init' && !this.nextCursor) {
        return; // we've reached the end
      }
      this.loadingState = 'loading';
      const url = this.nextCursor ?
        `${libraryBaseUrl}&cursor=${encodeURIComponent(this.nextCursor)}` :
        libraryBaseUrl;

      try {
        const response = await fetch(url);
        if (!response.ok) {
          console.error("Error fetching library:", response);
          notify({
            type: 'error',
            message: `Error: Unable to fetch the library: ${error}`
          });
          this.loadingState = 'error';
          return
        }
        const { library_data, next_cursor, count } = await response.json();
        this.appendAnimes(library_data);
        if (!this.nextCursor) {
          this.totalAnimeCount = count
        }
        this.nextCursor = next_cursor;
        this.loadingState = 'loaded';
      } catch (error) {
        console.error(error);
        notify({
          type: 'error',
          message: `Error: Unable to fetch the library: ${error}`
        });
        this.loadingState = 'error';
        this.error = error;
      }
    },
    lastIsAfter(name) {
      const last = this.animeIds.slice(-1)[0];
      return last && this.animeDetails.get(last).name.localeCompare(name) > 0;
    },
    async fetchTill(name) {
      while (!this.lastIsAfter(name) && this.nextCursor) {
        await this.fetchLibrary();
      }
    },
    appendAnimes(library_data) {
      library_data.forEach(anime_data => {
        this.animeIds.push(anime_data.id);
        this.animeDetails.set(anime_data.id, makeAnime(anime_data));
      });
    },
    update(library_data) {
      library_data.forEach(anime_data => this.insertAnime(anime_data));
    },
    // These are updates that are not necessarily in sorted order.
    insertAnime(anime_data) {
      // We always store the data in the overall map
      const newAnime = makeAnime(anime_data);
      this.animeDetails.set(anime_data.id, newAnime);
      if (this.loadingState == 'error' || this.loadingState == 'init') {
        return; // We've not started fetching the library.
      }

      let index = this.animeIds.findIndex(id => {
        return this.animeDetails.get(id).name.localeCompare(newAnime.name) >= 0;
      })
      if (this.animeIds[index] === newAnime.id) {
        return; // element already exists
      }
      if (index >= 0) {
        // Insert at the found index
        this.animeIds.splice(index, 0, newAnime.id);
      } else {
        // no Index was found. It's only safe to insert at the end if we've
        // fetched the entire library. That way we will not change the order of shows.
        if (!this.nextCursor) {
          this.animeIds.push(newAnime.id);
        }
      }
    },
    hasMoreItems(searchTerm) {
      if (this.loadingState == 'error') {
        return false;
      }
      if (this.loadingState == 'init' || this.loadingState == 'loading') {
        return true;
      }
      if (!searchTerm) {
        return !!this.nextCursor;
      }
      const existing = this.animeIdsBySearchTerm.get(searchTerm)
      return !existing || !existing['fetchedAll']
    },
    refetchLibrary() {
      this.reset();
      return this.fetchLibrary();
    },
    get isLoading() {
      return this.loadingState == 'loading'
    },
  };
}

const library = makeLibrary();
export default library;
