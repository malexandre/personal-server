git pull --rebase
mkdir -p www
mkdir -p www/staticfiles
wget -O www/staticfiles/mbp15.html https://raw.githubusercontent.com/malexandre/mbp-1.5-pool-generator/master/index.html
docker-compose up -d
