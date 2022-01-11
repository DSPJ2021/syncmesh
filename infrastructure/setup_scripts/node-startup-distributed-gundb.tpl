#!/bin/bash
VERSION=${mongo_version}
ID=${id}

pwd

echo "Hello from the Setup script!"
while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
  echo "waiting for other package installs to complete..."
  sleep 1
done
# Install Monitoring Agent
curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh && sudo bash add-monitoring-agent-repo.sh --also-install && sudo service stackdriver-agent start

user=$(whoami)
hostName=$(hostname)


sudo apt update -y

# Install Python for data distribution
sudo apt-get install -y python3.6 python3-pip

pip install requests


# Install GunDB
# Modified from https://github.com/amark/gun/blob/master/examples/install.sh

sudo apt-get install tmux -y

# install nodejs TODO: Setup node version
curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
sudo apt-get install -y nodejs

sudo npm install gun@0.2020.1235
cd ./node_modules/gun
sudo npm install .



# Download the data 
cd /
wget -O import.csv https://raw.githubusercontent.com/DSPJ2021/data/main/data/${id}.csv

# Import 30 Days worth of data 
currentTime=$(date --date="2017-07-31T00:00:00 30 day ago" +%s)
{

printf "sensor_id,location,lat,lon,timestamp,pressure,temperature,humidity\n" > data.csv
# This Read skips the header line!
read 
while IFS=, read -r sensor_id location lat lon timestamp pressure temperature humidity; do
    temp=$(date --date=$timestamp +%s)  
    if [ $temp -ge $currentTime ];
    then
        printf "$sensor_id,$location,$lat,$lon,$timestamp,$pressure,$temperature,$humidity\n" >> data.csv
    fi
done 
} < import.csv
mv data.csv import30.csv



# Run Gun Node with Data
# From https://github.com/amark/gun/blob/master/examples/http.js
printf "
;(function(){
	var cluster = require('cluster');
	if(cluster.isMaster){
	  return cluster.fork() && cluster.on('exit', function(){ cluster.fork(); require('../lib/crashed'); });
	}

	var fs = require('fs');
	var config = {
		port: process.env.OPENSHIFT_NODEJS_PORT || process.env.VCAP_APP_PORT || process.env.PORT || process.argv[2] || 8765,
		peers: process.env.PEERS && process.env.PEERS.split(',') || []
	};
	var Gun = require('gun')

	if(process.env.HTTPS_KEY){
		config.key = fs.readFileSync(process.env.HTTPS_KEY);
		config.cert = fs.readFileSync(process.env.HTTPS_CERT);
		config.server = require('https').createServer(config, Gun.serve(__dirname));
	} else {
		config.server = require('http').createServer(Gun.serve(__dirname+ '/node_modules/gun/examples'));
	}

	var gun = Gun({web: config.server.listen(config.port), peers: config.peers});

	console.log('Relay peer started on port ' + config.port + ' with /gun');

    
    const csv = require('csv-parser');
    const sensorName = 'sensor-$ID' 

    sensors = gun.get('sensors');

    sensor = gun.get(sensorName);
    sensors.set(sensor);

    counter = 0;
    setTimeout(() => {
    fs.createReadStream('import30.csv')
        .pipe(csv())
        .on('data', (data) => {
        counter = counter + 1;
        //   console.log('try to save data');
        var dataEntry = gun.get(sensorName + '-' + data.timestamp).put(data);
        sensor.set(dataEntry, () => {
            console.log('inserted entry');
        });
        })
        .on('end', () => {
            console.log('Successfully inserted data / counter: ', counter);
            var entry = gun.get(sensorName + '-datapointcount').put({ count: counter });
            sensor.set(entry, () => {
                console.log('inserted count');
            });
        });
    }, 1000);

	module.exports = gun;
}());
" > /start.js

cat start.js
npm install csv-parser

# start gun:
tmux new-session -d -s "gundb"
tmux send -t gundb 'cd /' ENTER
tmux send -t gundb 'node start.js 8080' ENTER