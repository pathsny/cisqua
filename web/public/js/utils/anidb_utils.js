'use strict';
import _ from 'lodash'

export function asArray(i) {
  return i ? (_(i).isArray() ? i : [i]) : [];
}

export function getAnidbTitle(anime) {
  let titles = asArray(anime.title);
  let main = titles.find(t => t['@type'] === 'main')
  let en_titles = titles.filter(t => t['@lang'] === 'en')
  let selectEnTitle = () => en_titles.find(t => t['@type'] === 'official') || en_titles[0]
  if (!main) {
    return (selectEnTitle() || titles[0]).Text
  }
  if (en_titles.some(t => t.Text === main.Text)) {
    return main.Text
  }
  let en_title = selectEnTitle()  
  return en_title ? `${main.Text} (${en_title.Text})` : main.Text
}  
