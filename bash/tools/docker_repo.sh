#!/bin/bash

# Comprehensive Container Registry Performance Tester
# Tests the same images from multiple registries for performance comparison

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Create results directory
RESULTS_DIR="registry_test_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Common images available across multiple registries
declare -A TEST_IMAGES=(
    ["hello-world"]="hello-world:latest"
    ["nginx"]="nginx:alpine"
    ["redis"]="redis:alpine"
    ["postgres"]="postgres:15-alpine"
    ["node"]="node:18-alpine"
    ["python"]="python:3.11-alpine"
)

# Registry configurations with their image prefixes
declare -A REGISTRIES=(
    ["Docker Hub"]="docker.io"
    ["Google Container Registry (US)"]="us.gcr.io"
    ["Google Container Registry (EU)"]="eu.gcr.io"
    ["Google Container Registry (Asia)"]="asia.gcr.io"
    ["GitHub Container Registry"]="ghcr.io"
    ["Azure Container Registry (Public)"]="mcr.microsoft.com"
    ["Quay.io"]="quay.io"
    ["AWS ECR Public"]="public.ecr.aws"
)

# Alternative image sources for specific registries
declare -A REGISTRY_SPECIFIC_IMAGES=(
    ["us.gcr.io"]="gcr.io/google-containers/pause:3.8"
    ["eu.gcr.io"]="gcr.io/google-containers/pause:3.8"
    ["asia.gcr.io"]="gcr.io/google-containers/pause:3.8"
    ["ghcr.io"]="ghcr.io/actions/runner:latest"
    ["mcr.microsoft.com"]="mcr.microsoft.com/dotnet/runtime:6.0-alpine"
    ["quay.io"]="quay.io/prometheus/node-exporter:latest"
    ["public.ecr.aws"]="public.ecr.aws/docker/library/hello-world:latest"
)

echo -e "${BLUE}=== Comprehensive Container Registry Performance Test ===${NC}"
echo -e "Testing from: ${GREEN}$(curl -s ifconfig.me 2>/dev/null || echo "Unknown IP")${NC}"
echo -e "Location: ${GREEN}Dublin, Ireland${NC}"
echo -e "Results will be saved to: ${CYAN}$RESULTS_DIR${NC}"
echo ""

# Function to log results
log_result() {
    local test_type="$1"
    local registry="$2"
    local metric="$3"
    local value="$4"
    echo "$test_type,$registry,$metric,$value,$(date -Iseconds)" >> "$RESULTS_DIR/results.csv"
}

# Initialize CSV
echo "TestType,Registry,Metric,Value,Timestamp" > "$RESULTS_DIR/results.csv"

# Function to test network latency with multiple methods
test_comprehensive_latency() {
    local name="$1"
    local endpoint="$2"
    local registry_host="$3"
    
    echo -e "${YELLOW}Testing latency to $name...${NC}"
    
    # Ping test
    local ping_result=$(ping -c 5 -W 3 "$endpoint" 2>/dev/null | tail -1 | awk -F '/' '{print $5}' 2>/dev/null || echo "FAIL")
    if [[ "$ping_result" != "FAIL" ]]; then
        echo -e "  Ping (avg): ${GREEN}${ping_result}ms${NC}"
        log_result "latency" "$name" "ping_avg_ms" "$ping_result"
    fi
    
    # HTTP latency test
    local http_times=()
    for i in {1..3}; do
        local http_time=$(curl -o /dev/null -s -w "%{time_total}" --max-time 10 "https://$endpoint/v2/" 2>/dev/null || echo "FAIL")
        if [[ "$http_time" != "FAIL" ]]; then
            http_times+=("$http_time")
        fi
    done
    
    if [[ ${#http_times[@]} -gt 0 ]]; then
        local avg_http=$(echo "${http_times[@]}" | tr ' ' '\n' | awk '{sum+=$1} END {print sum/NR*1000}')
        echo -e "  HTTP (avg): ${GREEN}$(printf "%.0f" "$avg_http")ms${NC}"
        log_result "latency" "$name" "http_avg_ms" "$(printf "%.0f" "$avg_http")"
    fi
    
    # DNS resolution test
    if [[ -n "$DNS_TOOL" ]]; then
        local dns_start=$(date +%s.%N)
        case "$DNS_TOOL" in
            "dig")
                dig +short "$endpoint" >/dev/null 2>&1
                ;;
            "host")
                host "$endpoint" >/dev/null 2>&1
                ;;
            "getent")
                getent hosts "$endpoint" >/dev/null 2>&1
                ;;
        esac
        local dns_exit=$?
        local dns_end=$(date +%s.%N)
        
        if [[ $dns_exit -eq 0 ]]; then
            local dns_time=$(echo "($dns_end - $dns_start) * 1000" | bc -l)
            local dns_ms=$(printf "%.0f" "$dns_time")
            echo -e "  DNS ($DNS_TOOL): ${GREEN}${dns_ms}ms${NC}"
            log_result "latency" "$name" "dns_ms" "$dns_ms"
        fi
    fi
}

# Function to test registry authentication and connectivity
test_registry_access() {
    local name="$1"
    local endpoint="$2"
    
    echo -n "Testing $name connectivity... "
    
    local start_time=$(date +%s.%N)
    local response=$(curl -s -w "%{http_code}|%{time_total}|%{size_download}" --max-time 15 "https://$endpoint/v2/" 2>/dev/null || echo "000|0|0")
    local end_time=$(date +%s.%N)
    
    IFS='|' read -r http_code time_total size_download <<< "$response"
    
    case $http_code in
        200) echo -e "${GREEN}OK${NC}" ;;
        401|403) echo -e "${YELLOW}AUTH REQUIRED${NC}" ;;
        404) echo -e "${YELLOW}API v2 NOT FOUND${NC}" ;;
        000) echo -e "${RED}TIMEOUT/ERROR${NC}" ;;
        *) echo -e "${YELLOW}HTTP $http_code${NC}" ;;
    esac
    
    log_result "connectivity" "$name" "http_code" "$http_code"
    log_result "connectivity" "$name" "response_time_ms" "$(echo "$time_total * 1000" | bc -l | cut -d'.' -f1)"
}

# Function to clean up images
cleanup_image() {
    local image="$1"
    docker rmi "$image" 2>/dev/null || true
    docker system prune -f >/dev/null 2>&1 || true
}

# Function to test pull performance with detailed metrics
test_pull_performance() {
    local registry_name="$1"
    local image="$2"
    local test_round="$3"
    
    echo -e "${PURPLE}[$test_round] Testing pull from $registry_name: $image${NC}"
    
    # Clean up first
    cleanup_image "$image"
    
    # Warm up DNS cache
    if [[ -n "$DNS_TOOL" ]]; then
        case "$DNS_TOOL" in
            "dig")
                dig +short "$(echo "$image" | cut -d'/' -f1)" >/dev/null 2>&1 || true
                ;;
            "host")
                host "$(echo "$image" | cut -d'/' -f1)" >/dev/null 2>&1 || true
                ;;
            "getent")
                getent hosts "$(echo "$image" | cut -d'/' -f1)" >/dev/null 2>&1 || true
                ;;
        esac
    fi
    
    # Test pull with detailed timing
    local start_time=$(date +%s.%N)
    local pull_output=$(docker pull "$image" 2>&1)
    local exit_code=$?
    local end_time=$(date +%s.%N)
    
    if [[ $exit_code -eq 0 ]]; then
        local duration=$(echo "$end_time - $start_time" | bc -l)
        local duration_formatted=$(printf "%.2f" "$duration")
        
        # Get image size
        local image_size=$(docker inspect "$image" --format='{{.Size}}' 2>/dev/null || echo "0")
        local image_size_mb=$(echo "scale=2; $image_size / 1024 / 1024" | bc -l)
        
        # Calculate download speed
        local speed_mbps="0"
        if (( $(echo "$duration > 0" | bc -l) )); then
            speed_mbps=$(echo "scale=2; $image_size_mb / $duration" | bc -l)
        fi
        
        echo -e "  ✓ Success: ${GREEN}${duration_formatted}s${NC} | Size: ${CYAN}$(printf "%.1f" "$image_size_mb")MB${NC} | Speed: ${CYAN}$(printf "%.1f" "$speed_mbps")MB/s${NC}"
        
        # Log detailed metrics
        log_result "pull_performance" "$registry_name" "duration_seconds" "$duration_formatted"
        log_result "pull_performance" "$registry_name" "image_size_mb" "$(printf "%.1f" "$image_size_mb")"
        log_result "pull_performance" "$registry_name" "speed_mbps" "$(printf "%.1f" "$speed_mbps")"
        log_result "pull_performance" "$registry_name" "image_name" "$image"
        
        # Extract layer information if available
        local layer_count=$(echo "$pull_output" | grep -c "Pull complete" || echo "0")
        if [[ "$layer_count" -gt 0 ]]; then
            log_result "pull_performance" "$registry_name" "layer_count" "$layer_count"
        fi
        
        return 0
    else
        echo -e "  ✗ ${RED}Failed${NC}: $(echo "$pull_output" | tail -1)"
        log_result "pull_performance" "$registry_name" "status" "failed"
        return 1
    fi
}

# Function to test bandwidth with large image
test_bandwidth() {
    local registry_name="$1"
    local large_image="$2"
    
    echo -e "${CYAN}Testing bandwidth with larger image from $registry_name...${NC}"
    
    cleanup_image "$large_image"
    
    local start_time=$(date +%s.%N)
    if timeout 300 docker pull "$large_image" >/dev/null 2>&1; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        local image_size=$(docker inspect "$large_image" --format='{{.Size}}' 2>/dev/null || echo "0")
        local image_size_mb=$(echo "scale=2; $image_size / 1024 / 1024" | bc -l)
        local bandwidth=$(echo "scale=2; $image_size_mb / $duration" | bc -l)
        
        echo -e "  Bandwidth: ${GREEN}$(printf "%.1f" "$bandwidth")MB/s${NC} ($(printf "%.1f" "$image_size_mb")MB in $(printf "%.1f" "$duration")s)"
        log_result "bandwidth" "$registry_name" "bandwidth_mbps" "$(printf "%.1f" "$bandwidth")"
        log_result "bandwidth" "$registry_name" "test_image_size_mb" "$(printf "%.1f" "$image_size_mb")"
    else
        echo -e "  ${RED}Bandwidth test failed or timed out${NC}"
        log_result "bandwidth" "$registry_name" "status" "failed"
    fi
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in docker bc curl timeout; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}$cmd is not installed${NC}"
        exit 1
    fi
done

# Check for DNS resolution tools (prefer dig, fallback to host, then getent)
DNS_TOOL=""
if command -v dig &> /dev/null; then
    DNS_TOOL="dig"
elif command -v host &> /dev/null; then
    DNS_TOOL="host"
elif command -v getent &> /dev/null; then
    DNS_TOOL="getent"
else
    echo -e "${YELLOW}Warning: No DNS resolution tool found (dig/host/getent). DNS tests will be skipped.${NC}"
fi

if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Docker daemon is not running${NC}"
    exit 1
fi

echo -e "${GREEN}All prerequisites met${NC}"
echo ""

# Test 1: Network latency and connectivity
echo -e "${BLUE}=== Phase 1: Network Latency & Connectivity ===${NC}"
for name in "${!REGISTRIES[@]}"; do
    endpoint="${REGISTRIES[$name]}"
    # Extract hostname for ping
    ping_host=$(echo "$endpoint" | sed 's|docker.io|registry-1.docker.io|g')
    test_comprehensive_latency "$name" "$ping_host" "$endpoint"
    test_registry_access "$name" "$endpoint"
    echo ""
done

# Test 2: Pull performance with common images
echo -e "${BLUE}=== Phase 2: Pull Performance - Common Images ===${NC}"
for image_name in "${!TEST_IMAGES[@]}"; do
    image="${TEST_IMAGES[$image_name]}"
    echo -e "${YELLOW}Testing image: $image_name ($image)${NC}"
    
    # Test Docker Hub (baseline)
    test_pull_performance "Docker Hub" "$image" "1/1"
    
    # Test alternatives where the same image might be available
    if [[ "$image_name" == "hello-world" ]]; then
        test_pull_performance "AWS ECR Public" "public.ecr.aws/docker/library/hello-world:latest" "1/1"
    fi
    
    echo ""
done

# Test 3: Registry-specific images
echo -e "${BLUE}=== Phase 3: Registry-Specific Images ===${NC}"
for registry in "${!REGISTRY_SPECIFIC_IMAGES[@]}"; do
    registry_name=""
    for name in "${!REGISTRIES[@]}"; do
        if [[ "${REGISTRIES[$name]}" == *"$registry"* ]]; then
            registry_name="$name"
            break
        fi
    done
    
    if [[ -n "$registry_name" ]]; then
        image="${REGISTRY_SPECIFIC_IMAGES[$registry]}"
        test_pull_performance "$registry_name" "$image" "1/1"
    fi
done

echo ""

# Test 4: Bandwidth testing with larger images
echo -e "${BLUE}=== Phase 4: Bandwidth Testing ===${NC}"
declare -A LARGE_IMAGES=(
    ["Docker Hub"]="ubuntu:22.04"
    ["Google Container Registry (EU)"]="eu.gcr.io/google-containers/ubuntu:22.04"
    ["Azure Container Registry (Public)"]="mcr.microsoft.com/dotnet/aspnet:6.0"
)

for registry_name in "${!LARGE_IMAGES[@]}"; do
    large_image="${LARGE_IMAGES[$registry_name]}"
    test_bandwidth "$registry_name" "$large_image"
done

# Test 5: Repeated pulls (cache testing)
echo -e "${BLUE}=== Phase 5: Cache Performance ===${NC}"
test_image="hello-world:latest"
echo -e "${YELLOW}Testing cache performance with $test_image${NC}"

for round in {1..3}; do
    echo -e "${CYAN}Round $round/3${NC}"
    test_pull_performance "Docker Hub" "$test_image" "$round/3"
done

# Generate summary report
echo -e "${BLUE}=== Generating Performance Report ===${NC}"

cat > "$RESULTS_DIR/summary.md" << 'EOF'
# Container Registry Performance Test Results

## Test Configuration
- **Location**: Dublin, Ireland
- **Test Date**: $(date)
- **VPS Provider**: [Your VPS Provider]

## Key Findings

### Fastest Registries (Pull Performance)
EOF

# Process results and generate summary
python3 << EOF
import csv
import sys
from collections import defaultdict
import statistics

try:
    results = defaultdict(list)
    
    with open('$RESULTS_DIR/results.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['TestType'] == 'pull_performance' and row['Metric'] == 'duration_seconds':
                try:
                    results[row['Registry']].append(float(row['Value']))
                except ValueError:
                    continue
    
    # Calculate averages and sort
    avg_times = {}
    for registry, times in results.items():
        if times:
            avg_times[registry] = statistics.mean(times)
    
    # Sort by performance
    sorted_registries = sorted(avg_times.items(), key=lambda x: x[1])
    
    print("\n### Performance Rankings:")
    for i, (registry, avg_time) in enumerate(sorted_registries, 1):
        print(f"{i}. **{registry}**: {avg_time:.2f}s average")
    
    # Best latency
    latency_results = defaultdict(list)
    with open('$RESULTS_DIR/results.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['TestType'] == 'latency' and row['Metric'] == 'ping_avg_ms':
                try:
                    latency_results[row['Registry']].append(float(row['Value']))
                except ValueError:
                    continue
    
    if latency_results:
        print("\n### Best Latency:")
        best_latency = min(latency_results.items(), key=lambda x: statistics.mean(x[1]) if x[1] else float('inf'))
        if best_latency[1]:
            print(f"**{best_latency[0]}**: {statistics.mean(best_latency[1]):.1f}ms average")

except Exception as e:
    print(f"Error generating summary: {e}")
EOF

# Final cleanup
echo -e "${YELLOW}Cleaning up test images...${NC}"
docker system prune -f >/dev/null 2>&1 || true

echo -e "${GREEN}=== Test Complete ===${NC}"
echo -e "Results saved to: ${CYAN}$RESULTS_DIR/${NC}"
echo -e "Summary: ${CYAN}$RESULTS_DIR/summary.md${NC}"
echo -e "Raw data: ${CYAN}$RESULTS_DIR/results.csv${NC}"

echo ""
echo -e "${BLUE}Quick Summary:${NC}"
echo -e "• Run ${GREEN}cat $RESULTS_DIR/summary.md${NC} to see the full report"
echo -e "• Check ${GREEN}$RESULTS_DIR/results.csv${NC} for detailed metrics"
echo -e "• Based on Dublin location, EU-based registries should perform best"

# Generate quick recommendations
echo ""
echo -e "${YELLOW}Recommendations for Dublin:${NC}"
echo -e "• For Google Cloud: Use ${GREEN}eu.gcr.io${NC}"
echo -e "• For Azure: Use ${GREEN}northeurope.azurecr.io${NC} or ${GREEN}westeurope.azurecr.io${NC}"
echo -e "• For general use: ${GREEN}Docker Hub${NC} usually has good European performance"
echo -e "• Consider setting up multiple registry mirrors for critical applications"
