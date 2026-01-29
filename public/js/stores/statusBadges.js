import { invariantIsBool } from '../utils/utils.js';

const statusBadges = {
  'ongoing': {
    wrapperClass: 'ongoing',
    icon: 'fas fa-sync',
    statusTooltip: 'Ongoing',
  },
  'ended-complete': {
    wrapperClass: 'ended-complete',
    icon: 'fas fa-check-circle',
    statusTooltip: 'Ended (Complete)',
  },
  'ended-incomplete': {
    wrapperClass: 'ended-incomplete',
    icon: 'fas fa-exclamation-circle',
    statusTooltip: 'Ended (InComplete)',
  },
  forAnime(anime) {
    invariantIsBool(anime.ended, 'Anime must have ended property');
    invariantIsBool(anime.complete, 'Anime must have ended property');
    if (!anime.ended) {
      return this['ongoing'];
    }
    return this[anime.complete ? "ended-complete" : "ended-incomplete"]
  }
}

export default statusBadges;
