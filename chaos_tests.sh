#!/bin/bash
# Chaos Engineering Test Suite

cd /home/claudedev/resilient_system

echo "=== CHAOS ENGINEERING TEST SUITE ==="
echo "Testing resilience patterns on deployed system"
echo ""

# Create chaos test Python script
cat > chaos_test.py << 'CHAOS_EOF'
import asyncio
import aiohttp
import time
import psutil
import subprocess
import sys
from datetime import datetime

class ChaosTests:
    def __init__(self):
        self.api_url = "http://localhost:8080"
        self.external_url = "http://localhost:8081"
        self.results = []

    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {message}")

    async def test_1_kill_external_service(self):
        """Test 1: Kill external service mid-operation"""
        self.log("TEST 1: Kill external service during requests")

        # Find and kill external service
        killed = False
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = ' '.join(proc.info['cmdline'] or [])
                if 'external_service.py' in cmdline:
                    self.log(f"Killing external service PID: {proc.info['pid']}")
                    proc.kill()
                    killed = True
                    break
            except:
                pass

        if not killed:
            return {"test": "test_1", "status": "FAIL", "reason": "Could not find external service process"}

        # Wait a moment
        await asyncio.sleep(2)

        # Make requests - should get fallback responses
        async with aiohttp.ClientSession() as session:
            success_count = 0
            fallback_count = 0

            for i in range(5):
                try:
                    async with session.get(f"{self.api_url}/api/fetch", timeout=aiohttp.ClientTimeout(total=10)) as resp:
                        data = await resp.json()
                        if data.get("source") == "fallback":
                            fallback_count += 1
                            success_count += 1
                        elif data.get("source") == "external":
                            success_count += 1
                except Exception as e:
                    self.log(f"Request {i+1} failed: {e}")

        # Restart external service
        subprocess.Popen([
            "nohup", "venv/bin/python", "external_service.py"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        result = {
            "test": "test_1_kill_external_service",
            "status": "PASS" if success_count == 5 and fallback_count >= 3 else "PARTIAL",
            "metrics": {
                "successful_requests": success_count,
                "fallback_responses": fallback_count,
                "total_requests": 5
            }
        }
        self.log(f"Test 1 Result: {result['status']} - {fallback_count}/5 fallback responses")
        return result

    async def test_2_request_flood(self):
        """Test 2: Flood with concurrent requests"""
        self.log("TEST 2: Flooding API with concurrent requests")

        start_time = time.time()

        async def make_request(session, i):
            try:
                async with session.get(f"{self.api_url}/api/fetch", timeout=aiohttp.ClientTimeout(total=10)) as resp:
                    return {"id": i, "status": resp.status, "success": True}
            except asyncio.TimeoutError:
                return {"id": i, "status": "timeout", "success": False}
            except Exception as e:
                return {"id": i, "status": str(e), "success": False}

        async with aiohttp.ClientSession() as session:
            tasks = [make_request(session, i) for i in range(50)]
            results = await asyncio.gather(*tasks)

        elapsed = time.time() - start_time
        success_count = sum(1 for r in results if r["success"])
        timeout_count = sum(1 for r in results if r["status"] == "timeout")

        result = {
            "test": "test_2_request_flood",
            "status": "PASS" if success_count >= 40 else "PARTIAL",
            "metrics": {
                "total_requests": 50,
                "successful": success_count,
                "timeouts": timeout_count,
                "elapsed_seconds": round(elapsed, 2)
            }
        }
        self.log(f"Test 2 Result: {result['status']} - {success_count}/50 successful in {elapsed:.2f}s")
        return result

    async def test_3_circuit_breaker_activation(self):
        """Test 3: Force circuit breaker to open"""
        self.log("TEST 3: Testing circuit breaker activation")

        # Wait for circuit to close if open
        await asyncio.sleep(35)

        # Make rapid requests to trigger failures
        async with aiohttp.ClientSession() as session:
            for i in range(15):
                try:
                    await session.get(f"{self.api_url}/api/fetch", timeout=aiohttp.ClientTimeout(total=10))
                except:
                    pass
                await asyncio.sleep(0.5)

        # Now make a request and check if circuit is open
        await asyncio.sleep(2)

        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(f"{self.api_url}/health", timeout=aiohttp.ClientTimeout(total=5)) as resp:
                    health = await resp.json()
                    circuit_state = health.get("dependencies", {}).get("external_service", {}).get("circuit_breaker", {}).get("state")

                    result = {
                        "test": "test_3_circuit_breaker",
                        "status": "PASS" if circuit_state == "OPEN" else "PARTIAL",
                        "metrics": {
                            "circuit_state": circuit_state,
                            "requests_made": 15
                        }
                    }
                    self.log(f"Test 3 Result: {result['status']} - Circuit state: {circuit_state}")
                    return result
            except Exception as e:
                return {"test": "test_3_circuit_breaker", "status": "FAIL", "error": str(e)}

    async def test_4_recovery_after_restoration(self):
        """Test 4: Verify circuit closes after service recovery"""
        self.log("TEST 4: Testing circuit recovery")

        # Wait for circuit timeout
        self.log("Waiting 35 seconds for circuit timeout...")
        await asyncio.sleep(35)

        # Make a few successful requests
        async with aiohttp.ClientSession() as session:
            success_count = 0
            for i in range(5):
                try:
                    async with session.get(f"{self.api_url}/api/fetch", timeout=aiohttp.ClientTimeout(total=10)) as resp:
                        if resp.status == 200:
                            success_count += 1
                except:
                    pass
                await asyncio.sleep(1)

        # Check circuit state
        await asyncio.sleep(2)
        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(f"{self.api_url}/health") as resp:
                    health = await resp.json()
                    circuit_state = health.get("dependencies", {}).get("external_service", {}).get("circuit_breaker", {}).get("state")

                    result = {
                        "test": "test_4_recovery",
                        "status": "PASS" if circuit_state == "CLOSED" or circuit_state == "HALF_OPEN" else "PARTIAL",
                        "metrics": {
                            "circuit_state": circuit_state,
                            "successful_requests": success_count
                        }
                    }
                    self.log(f"Test 4 Result: {result['status']} - Circuit recovered to: {circuit_state}")
                    return result
            except Exception as e:
                return {"test": "test_4_recovery", "status": "FAIL", "error": str(e)}

    async def test_5_timeout_handling(self):
        """Test 5: Verify timeout handling"""
        self.log("TEST 5: Testing timeout handling")

        start_time = time.time()
        async with aiohttp.ClientSession() as session:
            timeout_count = 0
            success_count = 0

            for i in range(10):
                try:
                    request_start = time.time()
                    async with session.get(f"{self.api_url}/api/fetch", timeout=aiohttp.ClientTimeout(total=5)) as resp:
                        request_time = time.time() - request_start
                        if resp.status == 200:
                            success_count += 1
                        # Check if request completed within reasonable time
                        if request_time > 10:
                            timeout_count += 1
                except asyncio.TimeoutError:
                    timeout_count += 1
                except:
                    pass

        elapsed = time.time() - start_time

        result = {
            "test": "test_5_timeout_handling",
            "status": "PASS" if timeout_count <= 2 and success_count >= 5 else "PARTIAL",
            "metrics": {
                "total_requests": 10,
                "successful": success_count,
                "timeouts": timeout_count,
                "elapsed_seconds": round(elapsed, 2)
            }
        }
        self.log(f"Test 5 Result: {result['status']} - {success_count}/10 successful, {timeout_count} timeouts")
        return result

    async def test_6_graceful_degradation(self):
        """Test 6: Verify graceful degradation under load"""
        self.log("TEST 6: Testing graceful degradation")

        # Make sustained requests under various conditions
        async with aiohttp.ClientSession() as session:
            fallback_count = 0
            external_count = 0
            error_count = 0

            for i in range(20):
                try:
                    async with session.get(f"{self.api_url}/api/fetch", timeout=aiohttp.ClientTimeout(total=10)) as resp:
                        data = await resp.json()
                        if data.get("source") == "fallback":
                            fallback_count += 1
                        elif data.get("source") == "external":
                            external_count += 1
                except:
                    error_count += 1

                await asyncio.sleep(0.5)

        total_success = fallback_count + external_count

        result = {
            "test": "test_6_graceful_degradation",
            "status": "PASS" if total_success >= 15 and error_count <= 2 else "PARTIAL",
            "metrics": {
                "total_requests": 20,
                "fallback_responses": fallback_count,
                "external_responses": external_count,
                "errors": error_count,
                "success_rate": f"{(total_success/20)*100:.1f}%"
            }
        }
        self.log(f"Test 6 Result: {result['status']} - {total_success}/20 responses ({fallback_count} fallback)")
        return result

    async def run_all_tests(self):
        """Run all chaos tests"""
        self.log("=" * 60)
        self.log("STARTING CHAOS ENGINEERING TEST SUITE")
        self.log("=" * 60)

        tests = [
            self.test_1_kill_external_service,
            self.test_2_request_flood,
            self.test_3_circuit_breaker_activation,
            self.test_4_recovery_after_restoration,
            self.test_5_timeout_handling,
            self.test_6_graceful_degradation
        ]

        for test_func in tests:
            try:
                result = await test_func()
                self.results.append(result)
            except Exception as e:
                self.log(f"ERROR in {test_func.__name__}: {e}")
                self.results.append({
                    "test": test_func.__name__,
                    "status": "FAIL",
                    "error": str(e)
                })

            self.log("")

        self.log("=" * 60)
        self.log("CHAOS TEST RESULTS SUMMARY")
        self.log("=" * 60)

        for result in self.results:
            status_symbol = "✓" if result["status"] == "PASS" else ("⚠" if result["status"] == "PARTIAL" else "✗")
            print(f"{status_symbol} {result['test']}: {result['status']}")
            if "metrics" in result:
                for key, value in result["metrics"].items():
                    print(f"    {key}: {value}")

        passed = sum(1 for r in self.results if r["status"] == "PASS")
        partial = sum(1 for r in self.results if r["status"] == "PARTIAL")
        failed = sum(1 for r in self.results if r["status"] == "FAIL")

        self.log("=" * 60)
        self.log(f"TOTAL: {passed} PASSED, {partial} PARTIAL, {failed} FAILED")
        self.log("=" * 60)

        return self.results

if __name__ == "__main__":
    tester = ChaosTests()
    asyncio.run(tester.run_all_tests())
CHAOS_EOF

# Create watchdog script
cat > watchdog.py << 'WATCHDOG_EOF'
import time
import psutil
import subprocess
import sys
from datetime import datetime
import requests

class ServiceWatchdog:
    def __init__(self):
        self.check_interval = 10
        self.restart_count = {}
        self.max_restarts = 3
        self.log_file = "/home/claudedev/resilient_system/watchdog.log"

    def log(self, message):
        timestamp = datetime.now().isoformat()
        msg = f"[{timestamp}] {message}\n"
        print(msg, end="")
        with open(self.log_file, "a") as f:
            f.write(msg)

    def is_service_running(self, service_name):
        """Check if service process is running"""
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = ' '.join(proc.info['cmdline'] or [])
                if service_name in cmdline:
                    return True, proc.info['pid']
            except:
                pass
        return False, None

    def check_service_health(self, port, name):
        """Check if service responds to health check"""
        try:
            resp = requests.get(f"http://localhost:{port}/health", timeout=5)
            return resp.status_code == 200
        except:
            return False

    def restart_service(self, service_file, service_name):
        """Restart a crashed service"""
        if service_name not in self.restart_count:
            self.restart_count[service_name] = 0

        self.restart_count[service_name] += 1

        if self.restart_count[service_name] > self.max_restarts:
            self.log(f"ALERT: {service_name} has been restarted {self.max_restarts} times. Manual intervention required.")
            return False

        self.log(f"Restarting {service_name} (attempt {self.restart_count[service_name]}/{self.max_restarts})...")

        try:
            subprocess.Popen([
                "nohup", "venv/bin/python", service_file
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd="/home/claudedev/resilient_system")
            time.sleep(5)
            return True
        except Exception as e:
            self.log(f"Failed to restart {service_name}: {e}")
            return False

    def run(self):
        self.log("Watchdog started - monitoring services...")

        services = [
            ("external_service.py", "external_service", 8081),
            ("resilient_api.py", "resilient_api", 8080)
        ]

        while True:
            for service_file, service_name, port in services:
                running, pid = self.is_service_running(service_file)

                if not running:
                    self.log(f"ALERT: {service_name} is not running!")
                    self.restart_service(service_file, service_name)
                else:
                    healthy = self.check_service_health(port, service_name)
                    if not healthy:
                        self.log(f"WARNING: {service_name} (PID {pid}) is running but unhealthy")
                        # Could implement health-based restart here
                    else:
                        # Reset restart count on successful health check
                        if service_name in self.restart_count:
                            self.restart_count[service_name] = 0

            time.sleep(self.check_interval)

if __name__ == "__main__":
    watchdog = ServiceWatchdog()
    try:
        watchdog.run()
    except KeyboardInterrupt:
        print("\nWatchdog stopped by user")
        sys.exit(0)
WATCHDOG_EOF

echo "=== Installing additional dependencies ==="
source venv/bin/activate
pip install psutil > /dev/null 2>&1

echo "=== Running Chaos Tests ==="
venv/bin/python chaos_test.py

echo ""
echo "=== Starting Watchdog (background) ==="
nohup venv/bin/python watchdog.py > watchdog_output.log 2>&1 &
WATCHDOG_PID=$!
echo "Watchdog started with PID: $WATCHDOG_PID"

echo ""
echo "=== Chaos Testing Complete ==="
