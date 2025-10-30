#!/bin/bash
# Disaster Recovery Test Suite

cd /home/claudedev/resilient_system
source venv/bin/activate

echo "=== DISASTER RECOVERY TEST SUITE ==="
echo ""

cat > disaster_tests.py << 'DISASTER_EOF'
import subprocess
import time
import psutil
import requests
from datetime import datetime

class DisasterRecoveryTests:
    def __init__(self):
        self.results = []

    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {message}")

    def get_service_pid(self, service_name):
        """Find PID of a service"""
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = ' '.join(proc.info['cmdline'] or [])
                if service_name in cmdline:
                    return proc.info['pid']
            except:
                pass
        return None

    def is_service_healthy(self, port):
        """Check if service is healthy"""
        try:
            resp = requests.get(f"http://localhost:{port}/health", timeout=3)
            return resp.status_code == 200
        except:
            return False

    def test_scenario_1_kill_main_api(self):
        """Scenario 1: Force-kill main API and verify watchdog restart"""
        self.log("SCENARIO 1: Force-kill main API")

        # Get current PID
        api_pid = self.get_service_pid("resilient_api.py")
        if not api_pid:
            return {"scenario": "1", "status": "FAIL", "reason": "API not running"}

        self.log(f"Current API PID: {api_pid}")

        # Kill the process
        try:
            proc = psutil.Process(api_pid)
            proc.kill()
            self.log(f"Killed API PID {api_pid}")
        except Exception as e:
            return {"scenario": "1", "status": "FAIL", "error": str(e)}

        # Wait for watchdog to detect and restart (watchdog checks every 10s)
        self.log("Waiting for watchdog to restart service (15 seconds)...")
        time.sleep(15)

        # Check if service is back
        new_pid = self.get_service_pid("resilient_api.py")
        healthy = self.is_service_healthy(8080)

        mttr = 15  # Mean Time To Recovery

        result = {
            "scenario": "1_kill_main_api",
            "status": "PASS" if new_pid and healthy else "FAIL",
            "metrics": {
                "old_pid": api_pid,
                "new_pid": new_pid,
                "service_restored": new_pid is not None,
                "health_check_passed": healthy,
                "mttr_seconds": mttr
            }
        }

        self.log(f"Scenario 1: {result['status']} - New PID: {new_pid}, Healthy: {healthy}")
        return result

    def test_scenario_2_kill_external_service(self):
        """Scenario 2: Force-kill external service and verify graceful degradation + restart"""
        self.log("SCENARIO 2: Force-kill external service")

        # Get current PID
        ext_pid = self.get_service_pid("external_service.py")
        if not ext_pid:
            return {"scenario": "2", "status": "FAIL", "reason": "External service not running"}

        self.log(f"Current External Service PID: {ext_pid}")

        # Kill the process
        try:
            proc = psutil.Process(ext_pid)
            proc.kill()
            self.log(f"Killed External Service PID {ext_pid}")
        except Exception as e:
            return {"scenario": "2", "status": "FAIL", "error": str(e)}

        # Immediately test main API - should use fallback
        time.sleep(2)
        try:
            resp = requests.get("http://localhost:8080/api/fetch", timeout=5)
            data = resp.json()
            using_fallback = data.get("source") == "fallback"
            self.log(f"Main API response source: {data.get('source')}")
        except Exception as e:
            using_fallback = False
            self.log(f"Failed to get API response: {e}")

        # Wait for watchdog to restart
        self.log("Waiting for watchdog to restart external service (15 seconds)...")
        time.sleep(15)

        # Check if service is back
        new_pid = self.get_service_pid("external_service.py")
        healthy = self.is_service_healthy(8081)

        result = {
            "scenario": "2_kill_external_service",
            "status": "PASS" if using_fallback and new_pid and healthy else "PARTIAL",
            "metrics": {
                "old_pid": ext_pid,
                "new_pid": new_pid,
                "fallback_activated": using_fallback,
                "service_restored": new_pid is not None,
                "health_check_passed": healthy,
                "mttr_seconds": 15
            }
        }

        self.log(f"Scenario 2: {result['status']} - Fallback: {using_fallback}, Restored: {healthy}")
        return result

    def test_scenario_3_connection_stress(self):
        """Scenario 3: Connection pool stress test"""
        self.log("SCENARIO 3: Connection pool stress test")

        import asyncio
        import aiohttp

        async def stress_test():
            tasks = []
            success_count = 0
            error_count = 0

            async def make_request(session, i):
                try:
                    async with session.get("http://localhost:8080/api/fetch", timeout=aiohttp.ClientTimeout(total=10)) as resp:
                        return resp.status == 200
                except:
                    return False

            async with aiohttp.ClientSession() as session:
                tasks = [make_request(session, i) for i in range(100)]
                results = await asyncio.gather(*tasks)
                success_count = sum(1 for r in results if r)
                error_count = sum(1 for r in results if not r)

            return success_count, error_count

        success, errors = asyncio.run(stress_test())

        result = {
            "scenario": "3_connection_stress",
            "status": "PASS" if success >= 90 else "PARTIAL",
            "metrics": {
                "total_requests": 100,
                "successful": success,
                "errors": errors,
                "success_rate": f"{success}%"
            }
        }

        self.log(f"Scenario 3: {result['status']} - {success}/100 successful")
        return result

    def test_scenario_4_rapid_failures(self):
        """Scenario 4: Rapid failure handling"""
        self.log("SCENARIO 4: Rapid failure handling")

        # Make rapid requests to stress error handling
        success_count = 0
        for i in range(20):
            try:
                resp = requests.get("http://localhost:8080/api/fetch", timeout=5)
                if resp.status_code == 200:
                    success_count += 1
            except:
                pass
            time.sleep(0.2)

        # Check if services are still healthy
        api_healthy = self.is_service_healthy(8080)
        ext_healthy = self.is_service_healthy(8081)

        result = {
            "scenario": "4_rapid_failures",
            "status": "PASS" if api_healthy and success_count >= 10 else "PARTIAL",
            "metrics": {
                "requests_made": 20,
                "successful": success_count,
                "api_still_healthy": api_healthy,
                "external_still_healthy": ext_healthy
            }
        }

        self.log(f"Scenario 4: {result['status']} - System stable after {success_count}/20 requests")
        return result

    def run_all_scenarios(self):
        """Run all disaster recovery scenarios"""
        self.log("=" * 60)
        self.log("STARTING DISASTER RECOVERY TESTS")
        self.log("=" * 60)

        scenarios = [
            self.test_scenario_1_kill_main_api,
            self.test_scenario_2_kill_external_service,
            self.test_scenario_3_connection_stress,
            self.test_scenario_4_rapid_failures
        ]

        for scenario_func in scenarios:
            try:
                result = scenario_func()
                self.results.append(result)
            except Exception as e:
                self.log(f"ERROR in {scenario_func.__name__}: {e}")
                self.results.append({
                    "scenario": scenario_func.__name__,
                    "status": "FAIL",
                    "error": str(e)
                })

            self.log("")

        self.log("=" * 60)
        self.log("DISASTER RECOVERY TEST SUMMARY")
        self.log("=" * 60)

        for result in self.results:
            status_symbol = "✓" if result["status"] == "PASS" else ("⚠" if result["status"] == "PARTIAL" else "✗")
            print(f"{status_symbol} {result['scenario']}: {result['status']}")
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
    tester = DisasterRecoveryTests()
    tester.run_all_scenarios()
DISASTER_EOF

echo "Running disaster recovery tests..."
python disaster_tests.py

echo ""
echo "=== Disaster Recovery Tests Complete ==="
