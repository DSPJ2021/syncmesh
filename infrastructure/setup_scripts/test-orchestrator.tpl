#!/bin/bash


cat > /nodes.txt <<EOF
%{ for node in nodes ~}
${node.network_interface.0.network_ip}
%{ endfor ~}
EOF


cat > /client.txt <<EOF
${client.network_interface.0.network_ip}
EOF

%{ for s in server ~}
cat > /server.txt <<EOF
${s.network_interface.0.network_ip}
EOF
%{ endfor ~}

cat > /scenario.txt <<EOF
${scenario}
EOF

cat > /seperator.txt <<EOF
${seperator}
EOF

cat > ~/.ssh/id_rsa <<EOF
${private_key}
EOF
ssh-add ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

cat > ~/.ssh/config <<EOF
Host *
    User orchestrator
EOF

# The Quotes are there so the variables arent expanded
cat > test.sh <<'CUSTOMEOF'
${testscript}
CUSTOMEOF

while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
  echo "waiting for other package installs to complete..."
  sleep 1
done
# Install Monitoring Agent
curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh && sudo bash add-monitoring-agent-repo.sh --also-install && sudo service stackdriver-agent start

echo "Waiting for everything to be set up (static timer)"
# 10 Minutes should be more than sufficient
sleep 600

echo "Setting up TCP Dump"

while read internalIP; do
    echo "SHH $internalIP"
    ssh -o StrictHostKeyChecking=no $internalIP "sudo sh -c ' nohup /usr/sbin/tcpdump -ni any net 10.0.0.0/8 or host ${seperator} -w /capture.pcap -s 96 >> /tcpdump.log 2>&1 &'" < /dev/null
done < /nodes.txt

while read internalIP; do
    echo "SHH $internalIP"
    ssh -o StrictHostKeyChecking=no $internalIP "sudo sh -c ' nohup /usr/sbin/tcpdump -ni any net 10.0.0.0/8 or host ${seperator} -w /capture.pcap -s 96 >> /tcpdump.log 2>&1 &'" < /dev/null
done < /client.txt

while read internalIP; do
    echo "SHH $internalIP"
    ssh -o StrictHostKeyChecking=no $internalIP "sudo sh -c ' nohup /usr/sbin/tcpdump -ni any net 10.0.0.0/8 or host ${seperator} -w /capture.pcap -s 96 >> /tcpdump.log 2>&1 &'" < /dev/null
done < /server.txt



echo "Executing Scenarios"

# Those variables are set in the Orchestratore Template
export SLEEP_TIME=${sleep_time}
export PRE_TIME=${pre_time}
export REPETITIONS=${repetitions}
# Execute
bash test.sh

echo "Collecting TCP Dumps"


mkdir /tmp/captures
while read internalIP; do
    echo "SHH $internalIP"
    ssh -o StrictHostKeyChecking=no $internalIP "sudo sh -c 'killall tcpdump'" < /dev/null
    scp $internalIP:/capture.pcap /tmp/captures/$internalIP.pcap
done < /nodes.txt

while read internalIP; do
    echo "SHH $internalIP"
    ssh -o StrictHostKeyChecking=no $internalIP "sudo sh -c 'killall tcpdump'" < /dev/null
    scp $internalIP:/capture.pcap /tmp/captures/$internalIP.pcap
done < /client.txt

while read internalIP; do
    echo "SHH $internalIP"
    ssh -o StrictHostKeyChecking=no $internalIP "sudo sh -c 'killall tcpdump'" < /dev/null
    scp $internalIP:/capture.pcap /tmp/captures/$internalIP.pcap
done < /server.txt

mv *.timings /tmp/captures/

apt install zip -y
cd /tmp/captures && zip -r /captures.zip ./*