FROM ruby:3.3

MAINTAINER Wouter Coppieters <wc@pico.net.nz>

RUN apt-get update && apt-get install -y curl gnupg2 software-properties-common lsb-release
RUN curl -fsSL https://crystal-lang.org/install.sh | bash
WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
COPY crystalruby.gemspec ./
COPY lib/crystalruby/version.rb ./lib/crystalruby/version.rb

RUN bundle install
COPY . .

# Define the command to run your application
CMD ["bundle", "exec", "irb"]
