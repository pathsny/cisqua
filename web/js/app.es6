class Show {
  constructor(data) {
    this.name = ko.observable(data.name);
    this.feed = ko.observable(data.feed);
    this.fetched_at = ko.observable(data.fetched_at);
    this.auto_fetch = ko.observable(data.auto_fetch);
    this.aid = ko.observable(data.aid);
  }
}

$.asArray = i => i ? ($.isArray(i) ? i : [i]) : []

$.generateAnidbTitle = (titleNode) => {
  let titles = $.asArray(titleNode);
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

function ShowListViewModel() {
  this.addShow = () => {
    let new_show = new Show({ aid: this.newShow().value, name: this.newShow().label });
    $.ajax("/shows/new", {
      type: "POST",
      contentType: "application/json",
      data: ko.toJSON(new_show),
    }).done(data => this.shows.push(new_show));
  }

  this.selectShow = (item) => {
    this.newShow(item);
    $('#show').val(item.label);
  }

  this.destroyShow = (show) => {
    $.ajax("/shows/" + show.aid(), {type: "DELETE"}).
      done(data => this.shows.remove(show));
  }

  this.onSelectShow = (event, ui) => {
    event.preventDefault();
    this.selectShow(ui.item);
  }

  this.onFocusShow = (event, ui) => {
    event.preventDefault();
    $('#show').val(ui.item.label);
  }

  this.allShows = (request, response) => {
    let query = request.term.trim().replace(/[\s]+/g, ' ').split(' ').
      map(w => `+${w}*`).join(' ');
    $.ajax({
      url: 'http://anisearch.outrance.pl/',
      dataType:"xml",
      data: {task: 'search', query: query}
    }).done(data => {
      let data = xml.xmlToJSON(data);
      let animes = $.asArray(data.animetitles.anime);
      response(animes.map(anime => {
        let titleText = $.generateAnidbTitle(anime.title);
          // let mainTitle = titles.map()
        return {
          label: titleText,
          value: anime['@aid']
        };
      }));
    });
  }

  this.setPrettyRender = () => {
    // $('#show').autocomplete('instance')._renderItem = (ul, item) => {
    //   var li = $(this.autocompleteTempl({aid: item.value, name: item.label}))
    //   $.ajax(`/anidb/${item.value}.xml`, {
    //     dataType:"xml"
    //   }).done(data => {
    //     console.log(" I got ", data);
    //   });

    //   return li.appendTo(ul);
    // }
  }

  this.shows = ko.observableArray([])
  $.getJSON("/shows", (raw) => this.shows(raw.map(item => new Show(item))));
  this.newShow = ko.observable();
  this.selectShow({aid: '', label: ''});
  this.autocompleteTempl = Handlebars.compile($("#autocomp-template").html());
}

let viewModelInstance = new ShowListViewModel();
ko.applyBindings(viewModelInstance);
viewModelInstance.setPrettyRender();
