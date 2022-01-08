const Gun = require('gun');

const gun = Gun({
  //   peers: ['http://localhost:8766/gun', 'http://localhost:8765/gun'],
  peers: ['http://gundb:8765/gun'],
  file: false,
  localStorage: false,
  axe: false,
  radisk: false,
});

const csv = require('csv-parser');
const fs = require('fs');
const results = [];

sensors = gun.get('sensors');

sensor = gun.get('sensor-1');
sensors.set(sensor);

counter = 0;
setTimeout(() => {
  fs.createReadStream('import30.csv')
    .pipe(csv())
    .on('data', (data) => {
      counter = counter + 1;
      //   console.log('try to save data');
      var dataEntry = gun.get('sensor-1' + data.timestamp).put(data);
      sensor.set(dataEntry, () => {
        console.log('inserted entry');
      });
    })
    .on('end', () => {
      console.log('Successfully inserted data / counter: ', counter);
    });
}, 1000);
