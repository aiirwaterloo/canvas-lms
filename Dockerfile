FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV RAILS_ENV=production

# Install base dependencies
RUN apt-get update && apt-get install -y \
  software-properties-common curl gnupg lsb-release git

# Add Instructure Ruby PPA and install Ruby
RUN add-apt-repository ppa:instructure/ruby -y && \
    apt-get update && \
    apt-get install -y \
    ruby3.3 ruby3.3-dev zlib1g-dev libxml2-dev \
    libsqlite3-dev postgresql libpq-dev \
    libxmlsec1-dev libyaml-dev libidn11-dev make g++ imagemagick rsync

# Install Node.js 18 + npm latest
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Set working directory
WORKDIR /app

COPY . /app

RUN mkdir -p config && \
    echo "encryption_key: \"$(openssl rand -hex 32)\"" > config/security.yml && \
    echo "encryption_keys:" >> config/security.yml && \
    echo "  - \"$(openssl rand -hex 32)\"" >> config/security.yml

# Install Ruby gems
RUN gem install bundler --version 2.5.10 && \
    bundle config set --local path vendor/bundle && \
    bundle install --without development test

# Install JS dependencies

RUN apt-get remove -y cmdtest
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn=1.19.1-1
# Precompile static assets

# Expose app port
EXPOSE 3000

# Default command
RUN chmod +x /app/entrypoint2.sh
ENTRYPOINT ["/app/entrypoint2.sh"]