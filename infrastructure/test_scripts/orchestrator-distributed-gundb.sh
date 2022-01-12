#!/bin/bash

SERVER_IP=$(</server.txt) #10.0.0.3
CLIENT_IP="$(</client.txt)" #10.0.0.2
SEPERATOR_IP="$(</seperator.txt)" #92.60.39.199

# Those variables are set in the Orchestratore Template
#SLEEP_TIME=120
#PRE_TIME=60
#REPETITIONS=20

# install nodejs TODO: Setup node version
curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
sudo apt-get install -y nodejs



seperate () {
    echo "Waiting for Seperation Request ($SLEEP_TIME s)"
    sleep $SLEEP_TIME
    ssh -o StrictHostKeyChecking=no $CLIENT_IP "curl 'https://$SEPERATOR_IP'"
    echo "Waiting after Seperation Request ($PRE_TIME s)"
    sleep $PRE_TIME
}

queryDataCollect() {
# $1 - First Argument is the Start ISODate
for i in $(seq $REPETITIONS)
do
    # Query Data
    /usr/bin/time -ao collect.timings -f '%E' ssh -o StrictHostKeyChecking=no $CLIENT_IP "cd /; sudo node test.py collect $1 2017-07-31T23:59:59Z<<'EOF'
    $COMMAND
EOF
" 1> /dev/null
echo "Finished Request"
done
echo '\n' >> collect.timings
}

queryDataAggregate() {
# $1 - First Argument is the Start ISODate
for i in $(seq $REPETITIONS)
do
    # Query Data
    /usr/bin/time -ao aggregate.timings -f '%E' ssh -o StrictHostKeyChecking=no $CLIENT_IP "cd /; sudo node test.py aggregate $1 2017-07-31T23:59:59Z<<'EOF'
    $COMMAND
EOF
"
echo "Finished Request"
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