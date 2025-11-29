FROM mcr.microsoft.com/devcontainers/ruby:3.4-bookworm

# DEBIAN_FRONTEND=noninteractive is required to install tzdata in non interactive way
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg2 \
  software-properties-common \
  librsvg2-bin \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
  && add-apt-repository "deb [arch=amd64,arm64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  && curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

# Get node from nodesource - node 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh \
  && sudo -E bash nodesource_setup.sh \
  && rm nodesource_setup.sh

ENV USER='vscode'
# ENV NODE_VERSION 20.14.0
ENV NODE_ENV docker
ENV NPM_CONFIG_PREFIX="/home/${USER}/.npm-global"
ENV BUNDLE_PATH=/home/${USER}/.gems

COPY --chown="${USER}":"${USER}" doubtfire-api/.ci-setup/ /workspace/doubtfire-api/.ci-setup/

RUN apt-get update \
  && apt-get install -y  --no-install-recommends \
  lsb-release \
  nodejs \
  ffmpeg \
  ghostscript \
  qpdf \
  imagemagick \
  libmagic-dev \
  libmagickwand-dev \
  libmariadb-dev \
  # python3-pygments \
  tzdata \
  wget \
  libc6-dev \
  gosu \
  # inkscape \
  # librsvg2-bin \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  # smoke tests
  && node --version \
  && npm --version \
  && gem install bundler -v '~> 2.5.11'

USER "${USER}"

WORKDIR /workspace

RUN mkdir -p "${NPM_CONFIG_PREFIX}/lib" \
  && npm install -g npm@9.6.1 husky @angular/cli standard-version

# Install oh-my-zsh, powerlevel10k theme, and plugins
RUN git clone https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k \
  && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
  && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

ENV GEM_HOME /home/vscode/.gems
RUN /usr/local/rvm/bin/rvm implode --force

ENV RAILS_ENV development
ENV PATH /home/$USER/.gems/ruby/3.4.0/bin:$PATH:/tmp/texlive/bin/x86_64-linux:/tmp/texlive/bin/aarch64-linux:$PATH:/home/$USER/.npm-global/bin
ENV GEM_PATH /home/$USER/.gems/ruby/3.4.0:$GEM_PATH

# Install the web ui
WORKDIR /workspace/doubtfire-web
COPY --chown="${USER}":"${USER}" doubtfire-web/package.json /workspace/doubtfire-web

# Install web ui packages
RUN npm install -f

# Setup the folder where we will deploy the code
WORKDIR /workspace/doubtfire-api

COPY --chown="${USER}":"${USER}" doubtfire-api/Gemfile /workspace/doubtfire-api/Gemfile
COPY --chown="${USER}":"${USER}" doubtfire-api/Gemfile.lock /workspace/doubtfire-api/Gemfile.lock

RUN bundle install

WORKDIR /workspace

RUN sudo ln -s /workspace/doubtfire-api /doubtfire

EXPOSE 9876

COPY --chown="${USER}":"${USER}" .devcontainer /workspace/.devcontainer

ENV HISTFILE /workspace/tmp/.zsh_history

RUN sudo chmod +x /workspace/.devcontainer/*.sh

RUN rm -rf /workspace/tmp && \
  mkdir /workspace/tmp && \
  sudo mkdir /student-work && \
  sudo chown vscode:vscode /student-work

ENTRYPOINT [ "/workspace/.devcontainer/docker-entrypoint.sh" ]
CMD [ "sleep", "infinity" ]
