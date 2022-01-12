const Gun = require('gun');
const fs = require('fs');

const gun = Gun({
  peers: ['http://gundb:8765/gun'],
  file: false,
  localStorage: false,
  axe: false,
  radisk: false,
});

const csv = require('csv-parser');
const sensorName = 'sensor-1';

sensors = gun.get('sensors');

sensor = gun.get(sensorName);
sensors.set(sensor);

counter = 0;
setTimeout(() => {
  fs.createReadStream('import.csv')
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
