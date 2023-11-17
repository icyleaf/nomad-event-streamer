FROM ruby:3.2

ENV APP_PATH /app
WORKDIR $APP_PATH

COPY Gemfile $APP_PATH
COPY Gemfile.lock $APP_PATH

RUN bundle install

COPY . $APP_PATH

CMD bundle exec ruby main.rb
