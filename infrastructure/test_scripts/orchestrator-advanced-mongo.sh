#!/bin/bash

SERVER_IP=$(</server.txt) #10.0.0.3
CLIENT_IP="$(</client.txt)" #10.0.0.2
SEPERATOR_IP="$(</seperator.txt)" #92.60.39.199
PORT="27017"

# Those variables are set in the Orchestratore Template
#SLEEP_TIME=120
#PRE_TIME=60
#REPETITIONS=20

seperate () {
    echo "Waiting for Seperation Request ($SLEEP_TIME s)"
    sleep $SLEEP_TIME
    ssh -o StrictHostKeyChecking=no $CLIENT_IP "curl 'https://$SEPERATOR_IP'"
    echo "Waiting after Seperation Request ($PRE_TIME s)"
    sleep $PRE_TIME
}

queryDataCollect() {
# # First Argument is the Start ISODate

 # Maybe use .aggregate({ $replaceWith: "$pressure" })
read -r -d '' COMMAND <<EOF
use syncmesh
db.sensor_data.find({
    timestamp: {
        \$gte: ISODate("$1"),
        \$lt: ISODate("2017-07-31T23:59:59Z")
    }
}, { timestamp: 1, pressure: 1, temperature: 1, humidity: 1, _id: 0 }).toArray()
EOF

for i in $(seq $REPETITIONS)
do
    # Query Data
    /usr/bin/time -ao collect.timings -f '%E' ssh -o StrictHostKeyChecking=no $CLIENT_IP "mongo --networkMessageCompressors snappy --host $SERVER_IP:$PORT <<'EOF'
    $COMMAND
EOF
" 1> /dev/null
echo "Finished Mongo Request"
done
echo '\n' >> collect.timings
}

queryDataAggregate() {
# First Argument is the Start ISODate

# Maybe use .aggregate({ $replaceWith: "$pressure" })
read -r -d '' COMMAND <<EOF
use syncmesh
db.sensor_data.aggregate([{
    \$match: {
      timestamp: {
        \$gte: ISODate("$1"),
        \$lt: ISODate("2017-07-31T23:59:59Z")
        }
    }
  },{
    \$group: {
        _id: null,
        avgTemperature: { \$avg: "\$temperature" },
        avgPressure: { \$avg: "\$pressure" },
        avgHumidity: { \$avg: "\$humidity" }
    }
}])
EOF

for i in $(seq $REPETITIONS)
do
    # Query Data
    /usr/bin/time -ao aggregate.timings -f '%E' ssh -o StrictHostKeyChecking=no $CLIENT_IP "mongo --networkMessageCompressors snappy --host $SERVER_IP:$PORT <<'EOF'
    $COMMAND
EOF
"
echo "Finished Mongo Request"
done
echo '\n' >> aggregate.timings
}


seperate

# Collect

echo "Scenario: Collect - 1 day"
queryDataCollect "2017-07-31T00:00:00Z"

seperate

echo "Scenario: Collect - 7 day"
queryDataCollect "2017-07-24T00:00:00Z"

seperate

echo "Scenario: Collect - 14 day"
queryDataCollect "2017-07-17T00:00:00Z"

seperate

echo "Scenario: Collect - 30 day"
queryDataCollect "2017-06-30T00:00:00Z"

seperate


# Aggregate
echo "Scenario: Aggregate - 1 day"
queryDataAggregate "2017-07-31T00:00:00Z"


seperate

echo "Scenario: Aggregate - 7 day"
queryDataAggregate "2017-07-24T00:00:00Z"


seperate

echo "Scenario: Aggregate - 14 day"
queryDataAggregate "2017-07-17T00:00:00Z"

seperate

echo "Scenario: Aggregate - 30 day"
queryDataAggregate "2017-06-30T00:00:00Z"

seperate