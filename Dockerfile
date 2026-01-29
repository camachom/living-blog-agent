FROM ruby:4.0-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install --without development test

COPY lib/ ./lib/

COPY bin/living_blog ./bin/living_blog

RUN chmod +x ./bin/living_blog

ENTRYPOINT ["./bin/living_blog"]