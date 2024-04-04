#!/bin/bash

set -e

cd $WORKDIR

sudo chown -R $USER:$USER /var/www/html
sudo chown -R $USER:$USER /home/$USER

if [ ! -z "$WWWUSER" ]; then
    sudo usermod -u $WWWUSER $USER
fi

sudo systemctl enable docker

sudo service mysql start
sudo service postgresql start
sudo service redis-server start
sudo service apache2 start
sudo service apache2 reload

# install and start code-server
curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
/tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &

if [ -z "$(ls -A $WORKDIR)" ]; then
    git clone $GIT_URL $WORKDIR
fi

/usr/bin/php8.3 /usr/bin/composer install

npm i
npm run build

if [ ! -e ".env" ]; then
    cp .env.example .env

    sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' .env

    sed -i 's/^# DB_USERNAME=.*/DB_USERNAME=sail/' .env
    sed -i 's/^DB_USERNAME=.*/DB_USERNAME=sail/' .env

    sed -i 's/^# DB_DATABASE=.*/DB_DATABASE=laravel/' .env
    sed -i 's/^DB_DATABASE=.*/DB_DATABASE=laravel/' .env

    sed -i 's/^# DB_PASSWORD=.*/DB_PASSWORD=password/' .env
    sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=password/' .env

    sed -i 's/^REDIS_CLIENT=.*/REDIS_CLIENT=redis/' .env

    sudo mysql --user=root <<-EOSQL
    CREATE USER 'sail'@'%' IDENTIFIED BY 'password';
    CREATE DATABASE IF NOT EXISTS laravel;
    GRANT ALL PRIVILEGES ON \`laravel%\`.* TO 'sail'@'%';
EOSQL

    /usr/bin/php8.3 artisan key:generate
    /usr/bin/php8.3 artisan migrate

    if $SEED; then
      /usr/bin/php8.3 artisan db:seed
    fi
fi

sudo /usr/bin/supervisord -s -c /etc/supervisor/conf.d/supervisord.conf >/tmp/supervisor.log 2>&1 &
