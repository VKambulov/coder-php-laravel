FROM ubuntu:22.04

ARG NODE_VERSION=20
ARG POSTGRES_VERSION=15
ARG USER=coder

WORKDIR $WORKDIR

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update \
    && mkdir -p /etc/apt/keyrings \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip supervisor sqlite3 libcap2-bin libpng-dev python2 dnsutils librsvg2-bin fswatch ffmpeg \
       build-essential htop jq locales man python3 python3-pip software-properties-common sudo systemd systemd-sysv wget rsync nano phpmyadmin apache2 \
    && add-apt-repository ppa:git-core/ppa \
    && apt-get install --yes git \
    && curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu jammy main" > /etc/apt/sources.list.d/ppa_ondrej_php.list \
    && apt-get update \
    && apt-get install -y php8.3-cli php8.3-dev \
       php8.3-pgsql php8.3-sqlite3 php8.3-gd \
       php8.3-curl \
       php8.3-imap php8.3-mysql php8.3-mbstring \
       php8.3-xml php8.3-zip php8.3-bcmath php8.3-soap \
       php8.3-intl php8.3-readline \
       php8.3-ldap \
       php8.3-msgpack php8.3-igbinary php8.3-redis php8.3-swoole \
       php8.3-memcached php8.3-pcov php8.3-imagick php8.3-xdebug \
       php8.3-fpm libapache2-mod-php8.3 \
    && curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && npm install -g pnpm \
    && npm install -g bun \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list \
    && curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list \
    && apt-get update \
    && apt-get install -y yarn \
    && apt-get install -y mysql-server mysql-client \
    && apt-get install -y postgresql-$POSTGRES_VERSION \
    && apt-get install -y containerd.io docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && apt-get install -y redis

RUN apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8

RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.3

RUN ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php.ini /etc/php/8.3/cli/conf.d/99-sail.ini

# Setting up phpmyadmin
RUN mkdir -p /ssl
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /ssl/apache.key -out /ssl/apache.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=localhost"

RUN a2enmod ssl
RUN sed -ri -e 's,80,4443,' /etc/apache2/sites-available/000-default.conf
RUN sed -i -e '/^<\/VirtualHost>/i SSLEngine on' /etc/apache2/sites-available/000-default.conf
RUN sed -i -e '/^<\/VirtualHost>/i SSLCertificateFile /ssl/apache.crt' /etc/apache2/sites-available/000-default.conf
RUN sed -i -e '/^<\/VirtualHost>/i SSLCertificateKeyFile /ssl/apache.key' /etc/apache2/sites-available/000-default.conf

RUN sed -ri -e 's,80,8080,' /etc/apache2/ports.conf
RUN sed -ri -e 's,443,4443,' /etc/apache2/ports.conf

# RUN echo "\$cfg['ForceSSL'] = 'true';" >> /etc/phpmyadmin/config.inc.php
# RUN sed -i "/\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'cookie';/c\\\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';" /etc/phpmyadmin/config.inc.php
RUN ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
RUN a2enconf phpmyadmin.conf
RUN a2enconf php8.3-fpm
# RUN sed -i "/VirtualHost \*:80/c\\<VirtualHost \*:8080\>" /etc/apache2/sites-enabled/000-default.conf
# RUN sed -i "/Listen 80/c\Listen 8080" /etc/apache2/ports.conf
RUN apachectl configtest

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
RUN sed -i -e 's/\r$//' /usr/local/bin/start.sh

RUN useradd --groups sudo --create-home --shell /bin/bash $USER \
	&& echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
	&& chmod 0440 /etc/sudoers.d/${USER}

USER ${USER}
