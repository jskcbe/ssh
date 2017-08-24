from netaddr import *
import pprint
import json

subnet_zone_mappings = \
{
    8:19,
    4:18,
    2:17
}

clients = \
{
	'bonobos':{
		'us-east-1':{
			'ops':{
				'cidr_block':'10.0.0.0/16',
				'azs':['a', 'b', 'c', 'e'],
				'subnet_val':4
			},
			'web':{
				'cidr_block':'10.1.0.0/16',
				'azs':['a', 'b', 'c', 'e'],
				'subnet_val':4
			},
			'com':{
				'cidr_block':'10.2.0.0/16',
				'azs':['a', 'b', 'c', 'e'],
				'subnet_val':4
			}
		}
	}
}

subnets_config = \
{
	'bonobos':{
		'web':{
			'us-east-1':{
				'a':{
					'public':True,
					'route':{
						'add_to':'internet_gateway'
					}
				},
				'b':{
					'public':True,
					'route':{
						'add_to':'internet_gateway'
					}
				},
				'c':{
					'public':True,
					'route':False,
				},
				'e':{
					'public':True,
					'route':False
				},
			}
		},
		'com':{
			'us-east-1':{
				'a':{
					'public':False
				},
				'b':{
					'public':False
				},
				'c':{
					'public':False
				},
				'e':{
					'public':False
				},
			}
		},
		'ops':{
			'us-east-1':{
				'a':{
					'public':False
				},
				'b':{
					'public':False
				},
				'c':{
					'public':False
				},
				'e':{
					'public':False
				},
			}
		}
	}
}


sep = '_X_'
res = {}
bonobo_clients = clients.keys()
for client in bonobo_clients:
	res[client] = {}
	client_vpcs_by_region = clients.get(client)
	for region in client_vpcs_by_region:
		res[client][region] = {}
		client_region_vpc_config = client_vpcs_by_region.get(region)
		for vpc_name in client_region_vpc_config:
			vpc_config = client_region_vpc_config.get(vpc_name)
			_vpc_name = client + sep + vpc_name
			cidr_block = vpc_config.get('cidr_block')
			azs = vpc_config.get('azs')
			subnet_val = vpc_config.get('subnet_val')#subnet_zone_mappings.get(len(azs))
			res[client][region][_vpc_name] = {
				'cidr_block':cidr_block,
				'subnets':{}
			}
			vpc_network = IPNetwork(cidr_block)
			subnets = list(vpc_network.subnet(subnet_zone_mappings[subnet_val]))
			for i, az in enumerate(azs):
				az_name = _vpc_name+sep+region.replace('-', '_')+az
				res[client][region][_vpc_name]['subnets'][az_name] = {}
				res[client][region][_vpc_name]['subnets'][az_name]['cidr_block'] = str(subnets[i-1])
				is_public = subnets_config.get(client).get(vpc_name).get(region).get(az).get('public')
				res[client][region][_vpc_name]['subnets'][az_name]['is_public'] = is_public
				if is_public:
					route = subnets_config.get(client).get(vpc_name).get(region).get(az).get('route')
					if route:
						res[client][region][_vpc_name]['subnets'][az_name]['route'] = route
			##print client, vpc_name, vpc_network, [str(x) for x in subnets]
print json.dumps(res, indent=2, sort_keys=True)

#if __name__ == '__main__':
#	from netaddr import *
#	ip = IPNetwork('10.0.0.0/16')
#	subnets = list(ip.subnet(18))
#	print subnets
#	print len(subnets)
