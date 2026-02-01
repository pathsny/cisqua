FROM ruby:3.3.0-alpine AS base

# Update and install necessary dependencies
RUN apk update && apk --no-cache --update add build-base sudo gcompat bash tzdata curl

FROM base AS dependencies

RUN apk add --update build-base git

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY ../Gemfile ../Gemfile.lock ../.ruby-version /usr/src/app/

RUN bundle config set --local without 'test development deployment'
RUN bundle install --jobs=3

FROM base
WORKDIR /usr/src/app

ARG GIT_COMMIT
ARG GIT_BRANCH
ARG GIT_COMMIT_TIME

COPY --from=dependencies /usr/local/bundle/ /usr/local/bundle/
COPY ../ /usr/src/app

RUN if [ -n "$GIT_COMMIT" ] && [ -n "$GIT_COMMIT_TIME" ]; then \
  printf '{"valid":true,"commit":"%s","branch":"%s","commit_time":"%s"}\n' \
  "$GIT_COMMIT" "${GIT_BRANCH:-unknown}" "$GIT_COMMIT_TIME" > /usr/src/app/config/version.json; \
fi

RUN touch Gemfile.lock && chmod a+w /usr/src/app/Gemfile.lock

VOLUME /usr/src/app/data

EXPOSE 4567

CMD ["bundle", "exec", "ruby", "app.rb"]
