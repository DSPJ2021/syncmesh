const Gun = require('gun');
const fs = require('fs');
const { performance } = require('perf_hooks');
const gun = Gun({
  peers: ['http://35.203.41.11:8080/gun', 'http://35.236.172.109:8080/gun', 'http://34.88.86.182:8080/gun'],
});
// gun.get("sensors").get("sensor-1").on(test => {console.log(Object.keys(test).length)}, {wait: 1})

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
      sensor_datapoints = {};
      getData(
        sensor,
        (data) => {
          sensor_datapoints[sensor] = removeMetaData(data);
          console.log(sensor, Object.keys(data).length);
        },
        14000
      );
    });

    // Check if all data points have been loaded before continuing
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
            Object.keys(sensor_datapoints[sensor]).forEach((key) => {
              getData(
                key,
                (data) => {
                  retrieved_sensor_data_points[sensor][key] = data;
                  //   console.log(key, data);
                },
                1
              );
            });
          });
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
  3
);

function exit() {
  fs.rmdirSync('./radata', { recursive: true });
  process.exit();
}
//   test = gun.get('sensors').once((sensors) => {
//     if (sensors == undefined) {
//       console.log('no sensors');
//       process.exit();
//       return;
//     }
//     console.log(sensors);
//     sensors = Object.keys(sensors._['>']);
//     sensor_data = {};
//     sensor_count = {};
//
//   });
//   });

function timer(lap) {
  if (lap) console.log(`${lap} in: ${(performance.now() - timer.prev).toFixed(3)}ms`);
  timer.prev = performance.now();
}

function write_data(data, sensor) {
  //   console.log(data);
  const filename = 'out/output-' + sensor + '.csv';
  data = data.sort((a, b) => a.test - b.test);
  fs.writeFile(filename, extractAsCSV(data), (err) => {
    if (err) {
      console.log('Error writing to csv file', err);
    } else {
      console.log(`saved as ${filename}`);
    }
  });
}

function extractAsCSV(data) {
  const header = Object.keys(data[0]).join(',');
  const rows = data
    .map((data) =>
      Object.keys(data)
        .map((key) => data[key])
        .join(',')
    )
    .join('\n');
  //   console.log(rows);
  return header + '\n' + rows;
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
