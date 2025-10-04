#!/usr/bin/env bash

# Benchmark script for whisp-away
# Tests three modes: direct whisper.cpp, daemon fallback, and daemon mode

set -e

# Configuration
ITERATIONS=5
MODELS=("small.en" "base.en")  # Test small and base models
RESULTS_FILE="benchmark_results.csv"
TEST_AUDIO="$(pwd)/jfk.wav"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

# Function to calculate average time using awk
calculate_average() {
    echo "$@" | awk '{sum=0; for(i=1;i<=NF;i++)sum+=$i; print sum/NF}'
}

# Function to get milliseconds since epoch
get_time_ms() {
    echo $(($(date +%s%N)/1000000))
}

# Function to run benchmark
run_benchmark() {
    local mode="$1"
    local model="$2"
    local times=""
    
    print_color "  Running $ITERATIONS iterations..." "$YELLOW"
    
    for i in $(seq 1 $ITERATIONS); do
        echo -n "  Iteration $i/$ITERATIONS: "
        
        start_time=$(get_time_ms)
        
        if [[ "$mode" == "direct" ]]; then
            # Direct whisper.cpp mode - use pre-recorded audio
            whisp-away stop -m "$model" --audio-file "$TEST_AUDIO" >/dev/null 2>&1
        elif [[ "$mode" == "daemon-fallback" ]]; then
            # Daemon fallback mode (daemon not running) - use pre-recorded audio
            whisp-away stop-cpp-daemon --model "$model" --audio-file "$TEST_AUDIO" >/dev/null 2>&1
        elif [[ "$mode" == "daemon" ]]; then
            # Daemon mode (daemon running) - use pre-recorded audio
            whisp-away stop-cpp-daemon --audio-file "$TEST_AUDIO" >/dev/null 2>&1
        fi
        
        end_time=$(get_time_ms)
        elapsed=$(awk "BEGIN {print ($end_time - $start_time) / 1000}")
        
        times="$times $elapsed"
        echo "$elapsed seconds"
    done
    
    # Calculate average
    avg=$(calculate_average $times)
    print_color "  Average: ${avg} seconds" "$GREEN"
    
    # Save to results file
    echo "$mode,$model,$avg" >> "$RESULTS_FILE"
    
    echo "$avg"
}

# Main benchmark function
main() {
    print_color "=== WHISP-AWAY BENCHMARK ===" "$GREEN"
    print_color "Testing whisp-away performance across different modes" "$BLUE"
    print_color "Note: This will record 2 seconds of audio for each test iteration" "$YELLOW"
    print_color "      Total iterations: $((${#MODELS[@]} * 3 * $ITERATIONS))" "$YELLOW"
    echo ""
    
    # Clear previous results
    > "$RESULTS_FILE"
    echo "mode,model,avg_time_seconds" > "$RESULTS_FILE"
    
    # Check if whisp-away is available
    if ! command -v whisp-away &> /dev/null; then
        print_color "Error: whisp-away not found in PATH" "$RED"
        exit 1
    fi
    
    # Check if test audio file exists
    if [ ! -f "$TEST_AUDIO" ]; then
        print_color "Error: Test audio file not found: $TEST_AUDIO" "$RED"
        exit 1
    fi
    print_color "Using test audio: $TEST_AUDIO" "$YELLOW"
    
    # Check and kill any existing daemons
    print_color "Checking for existing daemons..." "$YELLOW"
    if pgrep -f "whisp-away daemon" > /dev/null; then
        print_color "  Found existing daemon - stopping it" "$YELLOW"
        pkill -f "whisp-away daemon"
        sleep 1
    else
        print_color "  No existing daemon found" "$YELLOW"
    fi
    
    for model in "${MODELS[@]}"; do
        print_color "\n========================================" "$GREEN"
        print_color "Testing model: $model" "$GREEN"
        print_color "========================================" "$GREEN"
        
        # Mode 1: Direct whisper.cpp
        print_color "\n[1/3] Direct whisper.cpp mode (start/stop)" "$BLUE"
        print_color "      This uses whisper.cpp directly without daemon" "$NC"
        direct_time=$(run_benchmark "direct" "$model")
        
        # Mode 2: Daemon fallback (daemon not running)
        print_color "\n[2/3] Daemon fallback mode (daemon NOT running)" "$BLUE"
        print_color "      This uses start-cpp-daemon but daemon is not running" "$NC"
        # Ensure no daemon is running
        pkill -f "whisp-away daemon" 2>/dev/null || true
        sleep 1
        fallback_time=$(run_benchmark "daemon-fallback" "$model")
        
        # Mode 3: Daemon mode (daemon running)
        print_color "\n[3/3] Daemon mode (daemon IS running)" "$BLUE"
        print_color "      This uses start-cpp-daemon with daemon already running" "$NC"
        # Kill any existing daemon
        pkill -f "whisp-away daemon" 2>/dev/null || true
        sleep 1
        # Start the daemon fresh with the correct model
        print_color "      Starting daemon with model: $model" "$YELLOW"
        whisp-away daemon --model "$model" > /tmp/whisper-daemon.log 2>&1 &
        DAEMON_PID=$!
        sleep 3  # Give daemon time to fully start and initialize
        # Verify daemon is running
        if kill -0 $DAEMON_PID 2>/dev/null; then
            print_color "      Daemon started successfully (PID: $DAEMON_PID)" "$GREEN"
        else
            print_color "      Warning: Daemon may not have started properly" "$RED"
            cat /tmp/whisper-daemon.log
        fi
        daemon_time=$(run_benchmark "daemon" "$model")
        
        # Kill the daemon after testing
        kill $DAEMON_PID 2>/dev/null || true
        sleep 1
        
        
        # Print comparison for this model
        print_color "\n--- Results for $model ---" "$GREEN"
        echo "  Direct mode:        ${direct_time}s"
        echo "  Daemon fallback:    ${fallback_time}s"
        echo "  Daemon running:     ${daemon_time}s"
        
        # Calculate speedup using awk
        if [ $(awk "BEGIN {print ($direct_time > 0)}") -eq 1 ]; then
            speedup_fallback=$(awk "BEGIN {printf \"%.2f\", $direct_time / $fallback_time}")
            speedup_daemon=$(awk "BEGIN {printf \"%.2f\", $direct_time / $daemon_time}")
            echo ""
            echo "  Speedup vs direct:"
            echo "    Daemon fallback: ${speedup_fallback}x"
            echo "    Daemon running:  ${speedup_daemon}x"
        fi
    done
    
    print_color "\n========================================" "$GREEN"
    print_color "BENCHMARK COMPLETE" "$GREEN"
    print_color "========================================" "$GREEN"
    
    # Display final summary
    print_color "\nFinal Results Summary:" "$YELLOW"
    echo ""
    column -t -s',' "$RESULTS_FILE" 2>/dev/null || cat "$RESULTS_FILE"
    
    # Create a markdown summary
    cat > benchmark_summary.md <<EOF
# Whisp-Away Benchmark Results

## Test Configuration
- Iterations per test: $ITERATIONS
- Models tested: ${MODELS[@]}
- Date: $(date)

## Results

| Mode | Model | Average Time (seconds) |
|------|-------|------------------------|
EOF
    
    tail -n +2 "$RESULTS_FILE" | while IFS=',' read -r mode model time; do
        echo "| $mode | $model | $time |" >> benchmark_summary.md
    done
    
    print_color "\nResults saved to:" "$YELLOW"
    echo "  - $RESULTS_FILE (CSV)"
    echo "  - benchmark_summary.md (Markdown)"
}

# Run the benchmark
main "$@"