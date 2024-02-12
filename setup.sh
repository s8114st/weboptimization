#!/bin/bash

# Update system
sudo apt update
sudo apt upgrade -y

# Install Nginx and PHP
sudo apt install nginx php-fpm php-opcache php-mysql -y

# Configure PHP
sudo sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.4/fpm/php.ini # Update PHP configuration
sudo systemctl restart php7.4-fpm

# Configure Nginx
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup # Backup original nginx.conf
cat << EOF | sudo tee /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
worker_rlimit_nofile 100000;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log  off;
    error_log  /var/log/nginx/error.log crit;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    keepalive_timeout 15;
    keepalive_requests 1000;

    server_tokens off;
    types_hash_max_size 2048;

    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types
        application/javascript
        application/json
        application/xml
        application/rss+xml
        text/css
        text/javascript
        text/plain
        text/xml
        text/x-component
        image/svg+xml;
    gzip_buffers 16 8k;
    gzip_disable "msie6";

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
    
    # FastCGI Cache
    fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=FASTCGICACHE:100m inactive=60m;
    fastcgi_cache_key "$scheme$request_method$host$request_uri";
    fastcgi_cache_use_stale updating error timeout invalid_header http_500;
    
    # Microcaching
    fastcgi_cache_lock on;
    fastcgi_cache_lock_timeout 5s;
    fastcgi_cache_valid 200 301 302 10s;
    fastcgi_cache_bypass $no_cache;
    fastcgi_no_cache $no_cache;
    fastcgi_cache_bypass $http_pragma $http_authorization;
    
    # Buffer Sizes
    client_body_buffer_size 10K;
    client_header_buffer_size 1k;
    client_max_body_size 8m;
    large_client_header_buffers 2 1k;
    
    # Limit Access Logs
    access_log off;
}
EOF

# Remove HTTP/1.0 and HTTP/1.1 support
sudo sed -i '/http1.0/d' /etc/nginx/nginx.conf
sudo sed -i '/http1.1/d' /etc/nginx/nginx.conf

# Restart Nginx
sudo systemctl restart nginx
