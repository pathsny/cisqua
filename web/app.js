function Show(data) {
  this.name = ko.observable(data.name);
  this.feed = ko.observable(data.feed);
  this.fetched_at = ko.observable(data.fetched_at);
  this.auto_fetch = ko.observable(data.auto_fetch);
  this.aid = ko.observable(data.aid);
}

function asArray(i) {
  if ($.isArray(i)) {
    return i;
  }
  if (!i) return [];
  return [i];
}

function ShowListViewModel() {
    var self = this;
    self.shows = ko.observableArray([]);
    $.getJSON("/shows", function(raw) {
      var shows = $.map(raw, function(item) { return new Show(item) });
      self.shows(shows);
    });
    self.newShow = ko.observable();
    self.addShow = function() {
      var new_show = new Show({ aid: this.newShow().value, name: this.newShow().label });
      $.ajax("/shows/new", {
        type: "POST",
        contentType: "application/json",
        data: ko.toJSON(new_show),
      }).done(function(data){
        self.shows.push(new_show)
      });
      self.selectShow({aid: '', label: ''});
    };
    self.destroyShow = function(show) {
      $.ajax("/shows/" + show.aid(), {
        type: "DELETE",
      }).done(function(data){
        self.shows.remove(show);
      })
    }
    self.selectShow = function(item) {
      self.newShow(item);
      $('#show').val(item.label);
    }
    self.onSelectShow = function(event, ui) {
      event.preventDefault();
      self.selectShow(ui.item);
    }
    self.onFocusShow = function(event, ui) {
      event.preventDefault();
      $('#show').val(ui.item.label);
    }
    self.allShows = function(request, response) {
    query = request.term.
      trim().
      replace(/[\s]+/g, ' ').
      split(' ').
      map(function(w) { return '+' + w + '*'}).
      join(' ');
    $.ajax({
      url: 'http://anisearch.outrance.pl/',
      dataType:"xml",
      data: {
        task: 'search',
        query: query,
        langs: 'en,x-jat'
      }  
    }).done(function(data) {
      data = xml.xmlToJSON(data);
      animes = asArray(data.animetitles.anime);
      response(animes.map(function(anime) {
        return {
          label: asArray(anime.title)[0].Text,
          value: anime['@aid']
        };
      }));
    });
  }
}
ko.applyBindings(new ShowListViewModel());

