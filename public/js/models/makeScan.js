import makeRangesData from './makeRangesData.js';

const range_keys = ['added', 'duplicate', 'junk', 'previous', 'final_status']

function makeScan(scan) {
  return {
    ...scan,
    updates: scan.updates.map((anime_updates) => {
      const anime = Alpine.store('library').animeDetails.get(anime_updates.aid);
      const replaced = anime_updates.replaced.map(
        r => ({
          ...r,
          eps: makeRangesData(anime.hasSpecials(), r.eps)
        })
      );

      const ranges_updates = range_keys.reduce((acc, key) => {
        acc[key] = makeRangesData(anime.hasSpecials(), anime_updates[key]);
        return acc;
      }, {})

      return {
        ...anime_updates,
        ...ranges_updates,
        replaced,
      };
    }),
  };
}

export default makeScan;
