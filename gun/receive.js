const Gun = require('gun');
const fs = require('fs');
const { performance } = require('perf_hooks');

const peers = fs.readFileSync('nodes.txt').toString().replace(/\r\n/g, '\n').split('\n');

const gun = Gun({
  peers: peers.map((peer) => 'http://' + peer + ':8080/gun'),
});

// Get Args
const args = process.argv.slice(2);
// node receive.js <mode:collect/aggregate> <intervalBegin:ISODate> <intervalEnd:ISODate>
// node receive.js collect 2019-10-01T00:00:00Z 2019-10-02T00:00:00Z

const startDate = new Date(args[1]);
const endDate = new Date(args[2]);
console.log('startDate', startDate);
console.log('endDate', endDate);

// For the distributed database there is no difference between the aggregate and collect mode, as both need the data locally.

// Interval check in ms
interval = 100;

function getData(key, callback, expectedLength) {
  test = gun.get(key).once((data) => {
    // Compare with length + 1 (for internal object)
    // console.log(data);
    if (data == undefined || Object.keys(data).length < expectedLength + 1) {
      if (data != undefined) {
        // console.log(Object.keys(data).length);
      }
      setTimeout(() => {
        getData(key, callback, expectedLength);
      }, interval);
    } else {
      callback(data);
    }
  });
}

timer('sensors');
timer('sensors_datapoints');
timer('sensors_datapoints_data');

getData(
  'sensors',
  (sensors_data) => {
    timer('sensors');
    console.log(sensors_data);
    sensors = Object.keys(removeMetaData(sensors_data));
    sensors.forEach((sensor) => {
      // Get datapoint_count
      getData(
        sensor + '-datapointcount',
        (data) => {
          datapointcount = removeMetaData(data);
          console.log(sensor, datapointcount.count);
          console.log(sensor + 'datapointcount', Object.keys(data).length);
          sensor_datapoints = {};
          getData(
            sensor,
            (data) => {
              sensor_datapoints[sensor] = removeMetaData(data);
              console.log(sensor, Object.keys(data).length);
            },
            datapointcount.count
          );

          // Check if all data points have been loaded before continuing (the list of datapoints)
          let checkDataPoints = () => {
            setTimeout(() => {
              console.log('check sensor points', Object.keys(sensor_datapoints).length);
              if (Object.keys(sensor_datapoints).length >= sensors.length) {
                timer('sensors_datapoints');
                console.log('loaded sensor points');
                retrieved_sensor_data_points = {};
                check_loaded_points = {};
                sensors.forEach((sensor) => {
                  retrieved_sensor_data_points[sensor] = {};
                  Object.keys(sensor_datapoints[sensor])
                    .filter((datapointId) => {
                      // Datapoint format <sensor>-<timestamp>, e.g. sensor-1-2017-07-11T06:54:45
                      // To accomodate more than 9 sensor we find the index
                      let date = new Date(datapointId.slice(datapointId.indexOf('-', 7) + 1));
                      // Retrieve data point if in time interval
                      if (date > startDate && date < endDate) {
                        return true;
                      } else {
                        delete sensor_datapoints[sensor][datapointId];
                        // Hacky way of removing datapoints that are not needed so we don't have to wait for retrieval
                        return false;
                      }
                    })
                    .forEach((key) => {
                      getData(
                        key,
                        (data) => {
                          retrieved_sensor_data_points[sensor][key] = data;
                          // console.log(key, data);
                        },
                        1
                      );
                    });
                });

                // Check if the points data have been loaded before continuing (the content)
                let checkForRetrievedDataPoints = () => {
                  setTimeout(() => {
                    console.log('retrieved data points');

                    sensors.forEach((sensor) => {
                      console.log(
                        sensor,
                        Object.keys(retrieved_sensor_data_points[sensor]).length,
                        '/',
                        Object.keys(sensor_datapoints[sensor]).length
                      );
                      if (
                        Object.keys(retrieved_sensor_data_points[sensor]).length >=
                        Object.keys(sensor_datapoints[sensor]).length - 1
                      ) {
                        check_loaded_points[sensor] = true;
                      }
                    });

                    console.log(check_loaded_points);
                    if (Object.keys(check_loaded_points).length >= sensors.length) {
                      timer('sensors_datapoints_data');
                      console.log('all data points loaded');
                      exit();
                    } else {
                      checkForRetrievedDataPoints();
                    }
                  }, 1000);
                };
                checkForRetrievedDataPoints();
              } else {
                checkDataPoints();
              }
            }, 1000);
          };
          checkDataPoints();
        },
        1
      );
    });
  },
  3
);

function exit() {
  fs.rmdirSync('./radata', { recursive: true });
  fs.readdirSync('.').map((e) => {
    if (e.endsWith('.tmp')) {
      fs.unlinkSync(e);
    }
  });
  process.exit();
}

function timer(lap) {
  if (lap) console.log(`${lap} in: ${(performance.now() - timer.prev).toFixed(3)}ms`);
  timer.prev = performance.now();
}

const removeMetaData = (o) => {
  // A
  const copy = { ...o };
  //   try {
  //     copy.id = copy._['#'];
  //   } catch (e) {
  //     console.log('no id');
  //   }
  delete copy._;
  return copy;
};
