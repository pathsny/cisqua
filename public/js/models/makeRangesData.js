import { invariant } from '../utils/utils.js';

function makeFormattedRanges(category, ranges, withPrefix) {
  if (ranges === null) {
    return '';
  }
  switch (category) {
    case 'movie_part':
      return ranges.map(r => {
        if (r.total === 1) {
          return 'Complete Movie';
        }
        if (r.parts.length == 1 && r.parts[0].part_range.length == 1) {
          return `Part ${r.parts[0].part_range[0]} of ${r.total}`
        }
        const parts_str = r.parts.map(p => p.part_range.length == 1 ?
          p.part_range[0] :
          `${p.part_range[0]}-${p.part_range[1]}`
        ).join(', ')
        return `Parts ${parts_str} of ${r.total}`
      }).join(', ');
    case 'episode':
    case 'special':
      const str = ranges.map(
        r => r.ep_range.length > 1 ? `${r.ep_range[0]}-${r.ep_range[1]}` : r.ep_range[0]
      ).join(', ');
      if (withPrefix) {
        const plural = ranges.length > 1 || ranges.some(r => r.ep_range.length > 1);
        return `Episode${plural ? 's' : ''} ${str}`
      } else {
        return str;
      }
  }
  invariant(false, `unknown category ${category}`);
}


function makeRangesData(has_specials, eps_by_group) {
  return eps_by_group.map(({ group, ep_data }) => {
    const { normal, special } = ep_data;
    return {
      group,
      normal: {
        ...normal,
        ranges: makeFormattedRanges(normal.category, normal.range_data, true),
      },
      special: has_specials ? {
        ...special,
        ranges: makeFormattedRanges(special.category, special.range_data),
        bar_data: {
          ...special.bar_data,
          remaining: special.bar_data.total - special.bar_data.count,
        },
      } : null,
    };
  })
}

export default makeRangesData;
