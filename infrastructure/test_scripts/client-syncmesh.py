#!/usr/bin/env python3
#
# Example:
# python3 test.py --repetitions 11 --requestType "list" --startTime "2017-06-30T00:00:00Z" --endTime "2017-07-01T00:00:00Z"
#
#

from time import time, sleep
import requests
import argparse
import sys
import json


# Defaults
repetitions = 10
filepath = '/nodes.txt'
request_type = 'aggregate'


def get_request_body(limit: int, start_time: str, end_time: str, external_nodes_list: [str], request_type=str):
    # TODO: Add limit
    query = f"{{sensors(start_time: \"{start_time}\", end_time: \"{end_time}\"){{temperature humidity pressure}}}}"
    return json.dumps({
        "query": query,
        "database": "syncmesh",
        "collection": "sensor_data",
        "request_type": request_type,
        "external_nodes": external_nodes_list
    })


def main(args):
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument('-f', '--file', help="IP list file",
                        default=filepath, type=str)
    parser.add_argument('-r', '--repetitions',
                        help="Repetitions for the request", default=repetitions, type=int)
    parser.add_argument(
        '-l', '--limit', help="Document limit per node", default=0, type=int)
    parser.add_argument('-t', '--requestType',
                        help="The Request Type for Syncmesh Function (e.g. collect, aggregate)", default=request_type, type=str)
    parser.add_argument('--startTime', help="Start time for the query",
                        default="2017-06-30T00:00:00Z", type=str)
    parser.add_argument('--endTime', help="End time for the query",
                        default="2017-07-01T00:00:00Z", type=str)

    args = parser.parse_args(args)

    with open(args.file) as f:
        ip_addresses = f.readlines()
        ips = ["http://" + ip.strip() + ":8080" +
               "/function/syncmesh-fn" for ip in ip_addresses]

        ip = ips[0]
        ip_list = ips[1:]
        print(f"Starting Measurement with args: ")
        print(args)

        print(f"Sending Request:")
        body = get_request_body(limit=args.limit, start_time=args.startTime,
                                end_time=args.endTime,
                                external_nodes_list=ip_list,
                                request_type=args.requestType)
        print(body)
        for i in range(args.repetitions):
            r = requests.post(ip, data=body)
            print(r.status_code, r.reason)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
