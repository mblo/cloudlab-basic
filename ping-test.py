#!/usr/bin/env python

import sys, subprocess

print('Number of arguments:', len(sys.argv), 'arguments.')
print('Argument List:', str(sys.argv))

HOSTS=sys.argv[1]
MYIP=sys.argv[2]

with open(HOSTS) as f:
  content = f.readlines()
  for l in content:
    for ip in l.split(" "):
      print(".. test host={0}".format(l))
      r = subprocess.call(["ssh", "ubuntu@{0}".format(ip), "ping -c 5 -i .2 {0} && iperf3 -c {0} -t 4".format(MYIP)])
      break
