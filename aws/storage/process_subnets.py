#!/usr/bin/env python3

import json

# Opening JSON file
f = open('subnets.json',)
 
# returns JSON object as
# a dictionary
subnets = json.load(f)

for subnet in subnets:
  print(subnet['SubnetId'])