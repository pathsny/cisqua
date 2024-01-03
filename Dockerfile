FROM ruby:3.3.0-alpine as base

# Update and install necessary dependencies
RUN apk update && apk --no-cache --update add build-base sudo gcompat redis bash tzdata

FROM base as dependencies

RUN apk add --update build-base

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock .ruby-version /usr/src/app/

RUN bundle config set --local without 'test development deployment'
RUN bundle install --jobs=3

FROM base
WORKDIR /usr/src/app

COPY --from=dependencies /usr/local/bundle/ /usr/local/bundle/
COPY . /usr/src/app

RUN touch Gemfile.lock && chmod a+w /usr/src/app/Gemfile.lock

VOLUME /usr/src/app/data

EXPOSE 4567
CMD ["bundle", "exec", "ruby", "app.rb"]


