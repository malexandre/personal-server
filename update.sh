git pull --rebase
mkdir -p staticfiles
wget -O ./staticfiles/mbp15.html https://raw.githubusercontent.com/malexandre/mbp-1.5-pool-generator/master/index.html
docker-compose up -d
