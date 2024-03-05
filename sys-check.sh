#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
os=$(uname)
# Function to check if a list of ports is in use
check_ports() {
	local ports=("$@")
	local in_use_ports=()

	for port in "${ports[@]}"; do
		if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
			in_use_ports+=($port)
			echo -e "Port ${RED}$port${NC} is already in use."
		else
			echo -e "Port ${GREEN}$port${NC} is available."
		fi
	done

	if [ ${#in_use_ports[@]} -eq 0 ]; then
		echo -e "${GREEN}All specified ports are available.${NC}"
	else
		echo -e "The following ports are already in use: ${RED}${in_use_ports[*]}${NC}"
	fi
}

# Function to check Docker Hub connection
check_docker_hub() {
	echo -e "${YELLOW}----Checking connection to Docker Hub...${NC}"
	if docker pull hello-world >/dev/null 2>&1; then
		echo -e "Connection to Docker Hub ${GREEN}successful.${NC}"
	else
		echo -e "Unable to connect to Docker Hub. ${RED}Connection failed.${NC}"
	fi
}

# Function to check if a user belongs to a group
check_user_in_group() {
	local user="$1"
	local group="$2"
	if getent group "$group" | grep -q "\b$user\b"; then
		echo -e "$user belongs to group $group"
	else
		echo -e "$user does not belong to group $group"
	fi
}

# Function to check Docker group permissions
check_docker_group_permissions() {
	local group="docker"
	if getent group "$group" >/dev/null 2>&1; then
		echo -e "Group $group ${GREEN}exists.${NC}"
		check_user_in_group "$USER" "$group"
	else
		echo -e "Group $group ${RED}does not exist.${NC}"
	fi
}

check_docker() {
	echo -e "${YELLOW}----Checking Docker installation and accessibility...${NC}"
	if ! command -v docker &>/dev/null; then
		echo -e "${RED}Error:${NC} Docker is not installed."
		exit 1
	fi

	if ! docker info &>/dev/null; then
		echo -e "${RED}Error:${NC} Unable to access Docker socket."
		exit 1
	fi

	echo -e "${GREEN}Docker is installed and Docker socket is accessible.${NC}"
}

# Function to print Docker information
print_docker_info() {
	echo -e "${YELLOW}----Printing Docker information...${NC}"
	echo -e "Docker Version:"
	docker version --format '{{.Server.Version}}'

	echo -e "Number of Running Containers:"
	docker ps -q | wc -l

	echo -e "Number of Stopped Containers:"
	docker ps -aq --filter status=exited | wc -l

	echo -e "${YELLOW}Logs Information:${NC}"

	# Loop through each running container
	# for container_id in $(docker ps -aq); do
	#     log_path=$(docker inspect --format='{{.LogPath}}' "$container_id")

	#     # Check if the log file exists
	#     if [ -f "$log_path" ]; then
	#         echo "Container $container_id Log Path: $log_path"
	#         echo "Total Size of Logs:"
	#         du -ch "$log_path" | grep total$
	#     else
	#         echo "Container $container_id Log File does not exist."
	#     fi
	# done

	echo -e "Number of Log Files:"
	docker inspect --format='{{.LogPath}}' $(docker ps -q) | wc -l
	docker_info=$(docker info)

	# Check if log driver is json-file and max size is 100m
	if [[ $docker_info =~ "Logging Driver: json-file" ]]; then
		echo -e "Log driver is set to ${GREEN}json-file.${NC}"
	else
		echo -e "Log driver is not set to ${RED}json-file.${NC}"
	fi

	echo -e "${YELLOW}Docker File system${NC}"
	docker system df
}

# Function to get the hostname
get_host_info() {
	echo -e "${YELLOW}----Hostname and IP verification${NC}"
	hostname=$(hostname)
	ip_address_public=$(curl -s ifconfig.me)
	ip_address_private=$(hostname -i)

	echo -e "Hostname: ${GREEN}$hostname${NC}"
	echo -e "Public IP Address: ${GREEN}$ip_address_public${NC}"
	echo -e "Private IP Address: ${GREEN}$ip_address_private${NC}"
}

check_ssl_certificate() {
	local domain="$1"
	echo -e "${YELLOW}Checking SSL certificate for domain: $domain${NC}"

	if ! command -v curl &>/dev/null; then
		echo -e "${RED}Error:${NC} curl is not installed. Unable to check SSL certificate."
		exit 1
	fi

	local response=$(curl -s -o /dev/null -w "%{http_code}" --ssl https://"$domain" 2>/dev/null)

	if [ "$response" == "200" ] || [ "$response" == "301" ] || [ "$response" == "307" ]; then
		echo -e "${GREEN}SSL certificate for domain $domain is valid.${NC}"
	else
		echo -e "${RED}SSL certificate for domain $domain is not valid or could not be checked.${NC}"
	fi
}

check_nginx_conf() {
	local project="$1"
	# Get the container ID of the running NGINX container
	container_id=$(docker ps | grep "${project}_nginx" | awk '{print $1}' | head -n 1)

	# Extract NGINX configuration from the container
	nginx_config=$(docker exec $container_id nginx -T)

	# Extract client_max_body_size from NGINX configuration
	client_max_body_size=$(echo "$nginx_config" | awk '/client_max_body_size/ {print $2}')
	# Print the value of client_max_body_size
	echo -e "${YELLOW}client_max_body_size${NC}: $client_max_body_size"
}

# Function to check communication between containers
check_communication() {
	echo -e "${YELLOW}----Checking docker internal communication"
	local project="$1"
	nextjs_container_id=$(docker ps --format "{{.ID}} {{.Names}}" | grep "${project}_next" | awk '{print $1}')
	drupal_container_id=$(docker ps --format "{{.ID}} {{.Names}}" | grep "${project}_drupal" | awk '{print $1}')
	proxy_front_container_id=$(docker ps --format "{{.ID}} {{.Names}}" | grep "${project}_nginx" | awk '{print $1}')
	traefik_container_id=$(docker ps --format "{{.ID}} {{.Names}}" | grep "traefik" | awk '{print $1}')

	# nextjs_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}:{{.IPAddress}}{{end}}' "$nextjs_container_id")
	# drupal_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}:{{.IPAddress}}{{end}}' "$drupal_container_id")
	# proxy_front_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}:{{.IPAddress}}{{end}}' "$proxy_front_container_id")
	# traefik_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}:{{.IPAddress}}{{end}}' "$traefik_container_id")

	echo -e "${GREEN}Next.js Container ID : $nextjs_container_id${NC}"
	echo -e "${GREEN}Drupal Container ID : $drupal_container_id${NC}"
	echo -e "${GREEN}Nginx Container ID : $proxy_front_container_id${NC}"
	echo -e "${GREEN}Traefik Container ID : $traefik_container_id${NC}"

	nextsjs_ports=$(docker port "$nextjs_container_id")
	drupal_ports=$(docker port "$drupal_container_id")
	proxy_front_ports=$(docker port "$proxy_front_container_id")
	traefik_ports=$(docker port "$traefik_container_id")

	echo -e "${YELLOW}Next.js Ports : \n${NC}$nextsjs_ports"
	echo -e "${YELLOW}Drupal Ports : \n${NC}$drupal_ports"
	echo -e "${YELLOW}Nginx Ports : \n${NC}$proxy_front_ports"
	echo -e "${YELLOW}Traefik Ports : \n${NC}$traefik_ports"

	response=$(docker exec "$nextjs_container_id" sh -c "if command -v curl &>/dev/null; then curl -s -o /dev/null -w \"%{http_code}\" http://\"${project}_drupal\":8080; else wget -q -O /dev/null --server-response http://\"${project}_drupal\":8080 2>&1 | awk \"/HTTP\// {print \$2}\"; fi")
	if [ "$response" == "200" ] || [ "$response" == "301" ]; then
		echo -e "${GREEN}Communication between containers was successful.${NC}"
	else
		echo -e "${RED}Failed to communicate between containers. Communication failed.${NC}"
	fi
}

# Function to print CPU and memory information
print_system_info() {
	echo -e "${YELLOW}----Printing system information...${NC}"
	echo -e "${YELLOW}Memory and CPU Load:${NC}"
	if [ "$os" == "Darwin" ]; then
		top -l 1 -s 0 | awk '/Processes/ || /PhysMem/ || /Load Avg/{print}'
	else
		echo -e "${YELLOW}CPU Cores:${NC} $(nproc)"

		# For non-macOS systems (assuming Linux)
		echo -e "${YELLOW}Processes:${NC}"
		ps -e -o stat= | awk '{
            if ($1 ~ /^[RSDT]/) running++;
            else if ($1 ~ /^[Z]/) zombie++;
            else if ($1 ~ /^[S]/) sleeping++;
        } END {
            print "Running:", running;
            print "Sleeping:", sleeping;
            print "Zombie:", zombie;
        }'
		echo

		num_threads=$(ps -eLf | wc -l)
		echo -e "${YELLOW}Number of threads:${NC} $((num_threads - 1))"
		echo -e "${YELLOW}Physical Memory:${NC}"
		free -h
		echo

		echo -e "${YELLOW}Load Average:${NC}"
		uptime
	fi
}

# Function to curl subdomains
curl_subdomains() {
	local domain="$1"
	shift
	local subdomains=("$@")

	echo -e "${YELLOW}----Curling subdomains for domain: $domain${NC}"

	for subdomain in "${subdomains[@]}"; do
		echo -e "Curling: http://$subdomain.$domain${NC}"
		curl -sI "http://$subdomain.$domain" >/dev/null
		if [ $? -eq 0 ]; then
			echo -e "${GREEN}Subdomain $subdomain.$domain is reachable.${NC}"
		else
			echo -e "${RED}Subdomain $subdomain.$domain is not reachable.${NC}"
		fi
	done
}

check_swarm_communication() {
	echo -e "${YELLOW}----Checking Docker internal communication using Docker Swarm${NC}"
	local project="$1"

	# Retrieve the IDs of the services
	nextjs_service=$(docker service ps --format "{{.Name}} {{.ID}}" -f "name=${project}_nextjs" "${project}_nextjs" -q --no-trunc | head -n 1)
	drupal_service=$(docker service ps --format "{{.Name}} {{.ID}}" -f "name=${project}_drupal" "${project}_drupal" -q --no-trunc | head -n 1)
	proxy_front_service=$(docker service ps --format "{{.Name}} {{.ID}}" -f "name=${project}_nginx" "${project}_nginx" -q --no-trunc | head -n 1)
	traefik_service=$(docker service ps --format "{{.Name}} {{.ID}}" -f "name=traefik" -q --no-trunc | head -n 1)


	nextjs_service_name=$(echo "$nextjs_service" | awk '{print $1}')
	nextjs_service_id=$(echo "$nextjs_service" | awk '{print $2}')
	drupal_service_name=$(echo "$drupal_service" | awk '{print $1}')
	drupal_service_id=$(echo "$drupal_service" | awk '{print $2}')
	proxy_front_service_name=$(echo "$proxy_front_service" | awk '{print $1}')
	proxy_front_service_id=$(echo "$proxy_front_service" | awk '{print $2}')
	traefik_service_name=$(echo "$traefik_service" | awk '{print $1}')
	traefik_service_id=$(echo "$traefik_service" | awk '{print $2}')

	# Retrieve the tasks (containers) associated with each service
	nextjs_container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' "$nextjs_service_id")
	drupal_container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' "$drupal_service_id")
	proxy_front_container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' "$proxy_front_service_id")
	traefik_container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' "$traefik_service_id")

	# Retrieve the IPs of the containers
	# nextjs_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$nextjs_container_id")
	# drupal_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$drupal_container_id")
	# proxy_front_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$proxy_front_container_id")
	# traefik_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$traefik_container_id")

	echo -e "${GREEN}Next.js Container ID : $nextjs_container_id${NC}"
	echo -e "${GREEN}Drupal Container ID : $drupal_container_id${NC}"
	echo -e "${GREEN}Nginx Container ID : $proxy_front_container_id${NC}"
	echo -e "${GREEN}Traefik Container ID : $traefik_container_id${NC}"

	# Print the container ports
	nextjs_ports=$(docker port "$nextjs_container_id")
	drupal_ports=$(docker port "$drupal_container_id")
	proxy_front_ports=$(docker port "$proxy_front_container_id")
	traefik_ports=$(docker port "$traefik_container_id")

	echo -e "${YELLOW}Next.js Ports : \n${NC}$nextjs_ports"
	echo -e "${YELLOW}Drupal Ports : \n${NC}$drupal_ports"
	echo -e "${YELLOW}Nginx Ports : \n${NC}$proxy_front_ports"
	echo -e "${YELLOW}Traefik Ports : \n${NC}$traefik_ports"

	# Check communication between Next.js and Drupal
	response=$(docker exec "$nextjs_container_id" sh -c "if command -v curl &>/dev/null; then curl -s -o /dev/null -w \"%{http_code}\" http://\"$drupal_service_name\":8080; else wget -q -O /dev/null --server-response http://\"$drupal_service_name\":8080 2>&1 | awk \"/HTTP\// {print \$2}\"; fi")
	if [ "$response" == "200" ] || [ "$response" == "301" ]; then
		echo -e "${GREEN}Communication between containers was successful.${NC}"
	else
		echo -e "${RED}Failed to communicate between containers. Communication failed.${NC}"
	fi
}
# Main function
main() {

	check_docker

	# Call the function to check Docker group permissions
	check_docker_group_permissions docker

	# Call the port check function with the list of ports
	check_ports 8080 443 80 3000

	# Call the Docker Hub connection check function
	check_docker_hub
	get_host_info
	if [ -z "$2" ]; then
		echo -e "{$RED}Domain name not provided. Skipping all domain related checks {$NC}"
		echo -e "Usage: $0 <project_name> <domain>"
	else
		curl_subdomains "$2" "www" "backend" "media"
		check_ssl_certificate "$2"
	fi

	if [ -z "$1" ]; then
    echo "Usage: $0 <project_name> <domain>"
	else
		# Check if Docker Swarm is running
		docker info | grep -q "Swarm: active"
		if [ $? -ne 0 ]; then
			check_communication "$1"
			check_nginx_conf "$1"

		else
			check_swarm_communication $"1"
			check_nginx_conf "$1"
		fi
	fi

	# Call the function to print Docker information
	print_docker_info
	print_system_info
}

# Execute the main function
main "$@"
