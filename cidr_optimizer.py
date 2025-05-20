import boto3
import ipaddress
import json
import sys

def get_ec2_client(region):
    try:
        return boto3.client('ec2', region_name=region)
    except Exception as e:
        sys.exit(f"Failed to connect to region '{region}': {e}")

def fetch_vpc_cidrs(ec2):
    vpcs = ec2.describe_vpcs()['Vpcs']
    vpc_map = {}
    for vpc in vpcs:
        vpc_id = vpc['VpcId']
        cidr = vpc['CidrBlock']
        vpc_map[vpc_id] = cidr
    return vpc_map

def fetch_used_subnets(ec2, vpc_id):
    subnets = ec2.describe_subnets(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])['Subnets']
    return [subnet['CidrBlock'] for subnet in subnets]

def calculate_available_blocks(vpc_cidr, used_cidrs):
    vpc_network = ipaddress.ip_network(vpc_cidr)
    used_networks = [ipaddress.ip_network(c) for c in used_cidrs if ipaddress.ip_network(c).subnet_of(vpc_network)]

    available = [vpc_network]
    for used in used_networks:
        temp = []
        for block in available:
            if used.subnet_of(block):
                temp.extend(block.address_exclude(used))
            else:
                temp.append(block)
        available = temp

    return available

def assign_subnets(available_blocks, total_count, prefix):
    subnets = []
    for block in available_blocks:
        subnets.extend(list(block.subnets(new_prefix=prefix)))
        if len(subnets) >= total_count:
            return subnets[:total_count]
    raise ValueError("Insufficient available CIDRs to assign requested subnets.")

def distribute_subnets(subnets, public_count, azs):
    public = []
    private = []

    for i, subnet in enumerate(subnets):
        assignment = {
            "CIDR": str(subnet),
            "AZ": azs[i % len(azs)]
        }
        if i < public_count:
            public.append(assignment)
        else:
            private.append(assignment)

    return public, private

def validate_inputs(vpc_id, prefix, subnet_count, vpc_map):
    if vpc_id not in vpc_map:
        raise ValueError("Invalid VPC ID.")
    if not (16 <= prefix <= 28):
        raise ValueError("Prefix must be between /16 and /28.")
    if subnet_count <= 0:
        raise ValueError("Subnet count must be greater than 0.")

def main():
    region = input("Enter AWS region (e.g., us-east-1): ").strip()
    ec2 = get_ec2_client(region)

    print("\n Fetching VPC CIDRs...")
    vpc_map = fetch_vpc_cidrs(ec2)
    for i, (vpc_id, cidr) in enumerate(vpc_map.items(), 1):
        print(f"{i}. {vpc_id} -> {cidr}")

    selected = input("\nSelect VPC ID from above: ").strip()
    try:
        prefix = int(input("Enter new subnet prefix (e.g., 28 for /28): "))
        total_subnets = int(input("Enter total number of subnets to assign: "))
        public_count = int(input("Enter number of public subnets: "))

        validate_inputs(selected, prefix, total_subnets, vpc_map)

        private_count = total_subnets - public_count
        if private_count < 0:
            raise ValueError("Public subnets cannot exceed total subnets.")
    except ValueError as ve:
        sys.exit(f" Input Error: {ve}")

    used_cidrs = fetch_used_subnets(ec2, selected)
    available_blocks = calculate_available_blocks(vpc_map[selected], used_cidrs)

    print(f"\n Available CIDR ranges in {vpc_map[selected]}:")
    for block in available_blocks:
        print(f"- {block}")

    subnets = assign_subnets(available_blocks, total_subnets, prefix)
    azs = [az['ZoneName'] for az in ec2.describe_availability_zones()['AvailabilityZones']]

    public, private = distribute_subnets(subnets, public_count, azs)

    output = {
        "Region": region,
        "VpcId": selected,
        "VpcCIDR": vpc_map[selected],
        "RequestedPrefix": f"/{prefix}",
        "TotalSubnets": total_subnets,
        "PublicSubnets": public,
        "PrivateSubnets": private
    }

    print("\n Final JSON output:\n")
    print(json.dumps(output, indent=4))

if __name__ == "__main__":
    main()
