import makeRangesData from './makeRangesData.js';
import statusBadges from '../stores/statusBadges.js';

function makeAnime(anime_data) {
  return {
    ...anime_data,
    eps_by_group: makeRangesData(
      anime_data.special_ep_count > 0,
      anime_data.eps_by_group,
    ),
    image: anime_data.has_image ? `a${anime_data.id}.jpg` : 'missing.png',
    thumb: anime_data.has_image ? `a${anime_data.id}_t.jpg` : 'missing.png',
    contents: anime_data.eps_w_grps,
    get badge() {
      if (this.ended) {
        // Ongoing Collection
        return statusBadges[this.complete ? "ended-complete" : "ended-incomplete"]
      } else {
        return statusBadges["ongoing"];
      }
    },
    hasSpecials() {
      return this.special_ep_count > 0;
    },
  };
}

export default makeAnime;
