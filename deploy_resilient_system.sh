#!/bin/bash
set -e

cd /home/claudedev/resilient_system

echo "=== Creating Circuit Breaker ==="
cat > circuit_breaker.py << 'CIRCUIT_EOF'
import threading
import time
from datetime import datetime
from enum import Enum

class CircuitState(Enum):
    CLOSED = "CLOSED"
    OPEN = "OPEN"
    HALF_OPEN = "HALF_OPEN"

class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
        self.lock = threading.Lock()
        self.log_file = "/home/claudedev/resilient_system/circuit_breaker.log"

    def log_state_change(self, old_state, new_state, reason=""):
        with open(self.log_file, "a") as f:
            timestamp = datetime.now().isoformat()
            f.write(f"{timestamp} | {old_state.value} -> {new_state.value} | {reason}\n")

    def get_state(self):
        with self.lock:
            if self.state == CircuitState.OPEN:
                if self.last_failure_time and (time.time() - self.last_failure_time) > self.timeout:
                    old_state = self.state
                    self.state = CircuitState.HALF_OPEN
                    self.log_state_change(old_state, self.state, "Timeout expired")
            return self.state

    def record_success(self):
        with self.lock:
            if self.state == CircuitState.HALF_OPEN:
                old_state = self.state
                self.state = CircuitState.CLOSED
                self.failure_count = 0
                self.log_state_change(old_state, self.state, "Success in HALF_OPEN")
            self.failure_count = 0

    def record_failure(self):
        with self.lock:
            self.failure_count += 1
            self.last_failure_time = time.time()

            if self.state == CircuitState.HALF_OPEN:
                old_state = self.state
                self.state = CircuitState.OPEN
                self.log_state_change(old_state, self.state, "Failure in HALF_OPEN")
            elif self.failure_count >= self.failure_threshold:
                if self.state == CircuitState.CLOSED:
                    old_state = self.state
                    self.state = CircuitState.OPEN
                    self.log_state_change(old_state, self.state, f"Threshold reached: {self.failure_count}")

    def call(self, func, *args, **kwargs):
        state = self.get_state()

        if state == CircuitState.OPEN:
            raise Exception("Circuit breaker is OPEN")

        try:
            result = func(*args, **kwargs)
            self.record_success()
            return result
        except Exception as e:
            self.record_failure()
            raise e
CIRCUIT_EOF

echo "=== Creating External Service ==="
cat > external_service.py << 'EXTERNAL_EOF'
from fastapi import FastAPI
import random
import asyncio
import uvicorn
from datetime import datetime

app = FastAPI()

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "external"}

@app.get("/api/data")
async def get_data():
    # Variable latency
    delay = random.uniform(0.1, 5.0)
    await asyncio.sleep(delay)

    # Random failures (40% chance)
    if random.random() < 0.4:
        print(f"{datetime.now().isoformat()} | FAIL | Latency: {delay:.2f}s")
        return {"error": "Internal Server Error"}, 500

    print(f"{datetime.now().isoformat()} | SUCCESS | Latency: {delay:.2f}s")
    return {"data": "Success response", "latency": delay}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8081, log_level="info")
EXTERNAL_EOF

echo "=== Creating Resilient API ==="
cat > resilient_api.py << 'RESILIENT_EOF'
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
import aiohttp
import asyncio
from tenacity import retry, stop_after_attempt, wait_exponential
from circuit_breaker import CircuitBreaker, CircuitState
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import uvicorn
from datetime import datetime

app = FastAPI()
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

# Circuit breaker for external service
external_circuit = CircuitBreaker(failure_threshold=5, timeout=60)

# Connection pool
connector = aiohttp.TCPConnector(limit=50)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={"error": "Rate limit exceeded"}
    )

@app.get("/health")
async def health():
    circuit_state = external_circuit.get_state().value
    return {
        "status": "healthy",
        "service": "resilient_api",
        "circuit_breaker": circuit_state,
        "timestamp": datetime.now().isoformat()
    }

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=10))
async def call_external_service():
    timeout = aiohttp.ClientTimeout(total=6)
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        async with session.get("http://localhost:8081/api/data") as response:
            if response.status != 200:
                raise Exception(f"External service returned {response.status}")
            data = await response.json()
            return data

@app.get("/api/fetch")
@limiter.limit("100/minute")
async def fetch_data(request: Request):
    try:
        # Check circuit breaker state
        state = external_circuit.get_state()

        if state == CircuitState.OPEN:
            return {
                "source": "fallback",
                "data": "Circuit breaker is OPEN - using cached response",
                "circuit_state": state.value
            }

        # Try to call external service through circuit breaker
        try:
            result = await external_circuit.call(call_external_service)
            return {
                "source": "external",
                "data": result,
                "circuit_state": state.value
            }
        except Exception as e:
            # Fallback response
            return {
                "source": "fallback",
                "data": "External service unavailable - using fallback",
                "error": str(e),
                "circuit_state": external_circuit.get_state().value
            }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
RESILIENT_EOF

echo "=== Creating Requirements ==="
cat > requirements.txt << 'REQ_EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
aiohttp==3.9.1
tenacity==8.2.3
slowapi==0.1.9
REQ_EOF

echo "=== Creating Health Checker ==="
cat > health_checker.py << 'HEALTH_EOF'
import requests
import json

def check_health():
    results = {}

    # Check external service
    try:
        resp = requests.get("http://localhost:8081/health", timeout=5)
        results["external_service"] = {
            "status": "UP" if resp.status_code == 200 else "DOWN",
            "code": resp.status_code
        }
    except Exception as e:
        results["external_service"] = {"status": "DOWN", "error": str(e)}

    # Check main API
    try:
        resp = requests.get("http://localhost:8080/health", timeout=5)
        results["main_api"] = {
            "status": "UP" if resp.status_code == 200 else "DOWN",
            "code": resp.status_code,
            "data": resp.json() if resp.status_code == 200 else None
        }
    except Exception as e:
        results["main_api"] = {"status": "DOWN", "error": str(e)}

    # Check circuit breaker state from logs
    try:
        with open("/home/claudedev/resilient_system/circuit_breaker.log", "r") as f:
            lines = f.readlines()
            results["circuit_breaker"] = {
                "log_lines": len(lines),
                "last_5_events": lines[-5:] if lines else []
            }
    except Exception as e:
        results["circuit_breaker"] = {"error": str(e)}

    return results

if __name__ == "__main__":
    print(json.dumps(check_health(), indent=2))
HEALTH_EOF

echo "=== Setting up Virtual Environment ==="
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Starting Services ==="
# Start external service
nohup venv/bin/python external_service.py > external_service.log 2>&1 &
EXTERNAL_PID=$!
echo "External service started with PID: $EXTERNAL_PID"

# Wait for external service
sleep 5

# Start resilient API
nohup venv/bin/python resilient_api.py > resilient_api.log 2>&1 &
API_PID=$!
echo "Resilient API started with PID: $API_PID"

# Wait for API to start
sleep 5

echo "=== Verifying Services ==="
curl -s http://localhost:8081/health
echo ""
curl -s http://localhost:8080/health
echo ""

echo "=== Testing Circuit Breaker (10 requests) ==="
for i in {1..10}; do
    echo "Request $i:"
    curl -s http://localhost:8080/api/fetch | jq -c '{source, circuit_state}'
    sleep 1
done

echo ""
echo "=== Health Check ==="
venv/bin/python health_checker.py

echo ""
echo "=== Services Running ==="
echo "External Service PID: $EXTERNAL_PID"
echo "Resilient API PID: $API_PID"
ps aux | grep -E "(external_service|resilient_api)" | grep -v grep

echo ""
echo "=== Deployment Complete ==="
