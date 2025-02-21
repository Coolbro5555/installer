#!/bin/bash

# Variables
WORDPRESS_DOMAIN="sideshosting.com"
PTERODACTYL_DOMAIN="panel.sideshosting.com"
MYSQL_WP_USER="wordpressuser"
MYSQL_WP_PASS="strongpassword"
MYSQL_PTERO_USER="pterodactyl"
MYSQL_PTERO_PASS="securepassword"
LEMP_DIR="/var/www"
PTERODACTYL_DIR="/var/www/pterodactyl"
WP_DIR="/var/www/sideshosting.com"

# Update system
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y nginx mariadb-server php php-cli php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip unzip git curl composer redis-server certbot python3-certbot-nginx

# Configure MySQL
echo "Configuring MySQL..."
sudo mysql -e "CREATE DATABASE wordpress;"
sudo mysql -e "CREATE USER '${MYSQL_WP_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO '${MYSQL_WP_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

sudo mysql -e "CREATE DATABASE pterodactyl;"
sudo mysql -e "CREATE USER '${MYSQL_PTERO_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PTERO_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON pterodactyl.* TO '${MYSQL_PTERO_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Install WordPress
echo "Installing WordPress..."
sudo mkdir -p ${WP_DIR}
cd ${LEMP_DIR}
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzf latest.tar.gz
sudo mv wordpress/* ${WP_DIR}
sudo chown -R www-data:www-data ${WP_DIR}
sudo chmod -R 755 ${WP_DIR}

# Configure Nginx for WordPress
echo "Configuring Nginx for WordPress..."
cat <<EOF | sudo tee /etc/nginx/sites-available/${WORDPRESS_DOMAIN}
server {
    listen 80;
    server_name ${WORDPRESS_DOMAIN} www.${WORDPRESS_DOMAIN};
    root ${WP_DIR};
    index index.php index.html;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/${WORDPRESS_DOMAIN} /etc/nginx/sites-enabled/

# Install Pterodactyl Panel
echo "Installing Pterodactyl Panel..."
sudo mkdir -p ${PTERODACTYL_DIR}
cd ${PTERODACTYL_DIR}
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
cp .env.example .env
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan migrate --seed --force
sudo chown -R www-data:www-data ${PTERODACTYL_DIR}

# Configure Nginx for Pterodactyl
echo "Configuring Nginx for Pterodactyl..."
cat <<EOF | sudo tee /etc/nginx/sites-available/${PTERODACTYL_DOMAIN}
server {
    listen 80;
    server_name ${PTERODACTYL_DOMAIN};
    root ${PTERODACTYL_DIR}/public;
    index index.php;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/${PTERODACTYL_DOMAIN} /etc/nginx/sites-enabled/

# Restart Nginx
echo "Restarting Nginx..."
sudo systemctl restart nginx

# Enable SSL
echo "Enabling SSL with Certbot..."
sudo certbot --nginx -d ${WORDPRESS_DOMAIN} -d www.${WORDPRESS_DOMAIN} -n --agree-tos --email admin@${WORDPRESS_DOMAIN}
sudo certbot --nginx -d ${PTERODACTYL_DOMAIN} -n --agree-tos --email admin@${PTERODACTYL_DOMAIN}

# Done
echo "Installation complete! Visit https://${WORDPRESS_DOMAIN} for WordPress and https://${PTERODACTYL_DOMAIN} for Pterodactyl Panel."