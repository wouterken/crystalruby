# Stage 1: Use the Crystal official image to build Crystal
FROM crystallang/crystal:1.14 AS crystal-builder

# Stage 2: Use the Ruby image and copy Crystal from the previous stage
FROM ruby:3.3

MAINTAINER Wouter Coppieters <wc@pico.net.nz>

# Install necessary dependencies for Ruby and Crystal
RUN apt-get update && apt-get install -y \
  curl \
  gnupg2 \
  software-properties-common \
  build-essential \
  lsb-release

# Copy Crystal binaries and libraries from the Crystal image
COPY --from=crystal-builder /usr/share/crystal /usr/share/crystal
COPY --from=crystal-builder /usr/lib/crystal /usr/lib/crystal
COPY --from=crystal-builder /usr/bin/crystal /usr/bin/crystal
COPY --from=crystal-builder /usr/bin/shards /usr/bin/shards

# Set the working directory
WORKDIR /usr/src/app

# Copy the Ruby dependencies
COPY Gemfile Gemfile.lock ./
COPY crystalruby.gemspec ./
COPY lib/crystalruby/version.rb ./lib/crystalruby/version.rb

# Install Ruby dependencies
RUN bundle install

# Copy the rest of your application
COPY . .

# Define the command to run your application
CMD ["bundle", "exec", "irb"]
