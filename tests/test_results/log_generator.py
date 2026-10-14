import datetime
import random

# Configuration
TOTAL_LINES = 10_000
OUTPUT_FILE = "backend_simulation.log"

# Define log levels and their occurrence weights
levels = ["INFO", "DEBUG", "WARN", "ERROR", "CRITICAL"]
level_weights = [0.72, 0.08, 0.12, 0.06, 0.02]

# Event templates categorized by level to match the attached log files
log_templates = {
    "INFO": [
        "app: startup complete, version 2.3.1",
        "db: connection pool initialized, size=10",
        "cache: redis connected, latency {latency}ms",
        "api: /health returned 200",
        "api: /orders returned 200, count={count}",
        "api: /checkout returned 200, order_id={order_id}",
        "db: connection pool healthy, active={active}",
        "app: scheduled cleanup complete",
        "app: metrics exported to statsd",
        "cache: redis latency {latency}ms",
        "app: backup completed in 47s",
    ],
    "DEBUG": [
        "db: connection pool stats active={active}, idle={idle}",
        "db: query executed in {latency}ms, query_id={query_id}",
        "cache: hit ratio {ratio}",
    ],
    "WARN": [
        "cache: redis latency {latency}ms, threshold 200ms",
        "db: slow query {duration}s, query_id={query_id}",
        "disk: /var usage {usage}%, threshold 85%",
        "mem: usage {usage}%, threshold 85%",
    ],
    "ERROR": [
        "db: query timeout after 30s, query_id={query_id}",
        "api: /orders returned 500, trace={trace}",
        "api: /checkout returned 500, trace={trace}",
        "app: failed to write session file, errno=28 (No space left on device)",
        "cache: redis connection lost",
        "app: unhandled exception in worker thread",
    ],
    "CRITICAL": [
        "db: connection pool exhausted, active=10, waiting={waiting}",
        "disk: /var usage {usage}%, threshold 85%",
        "app: session store unavailable, logging out all users",
        "mem: usage {usage}%, OOM killer invoked, killed pid={pid} (python3)",
        "db: replication lag {lag}s, threshold 60s",
        "app: service degraded, returning 503 to all requests",
        "app: worker pool crashed, 0/8 workers alive",
    ],
}

print(f"Generating {TOTAL_LINES:,} log entries into '{OUTPUT_FILE}'...")

start_time = datetime.datetime.now()

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    current_time = start_time

    for i in range(TOTAL_LINES):
        # Advance time slightly between 1 to 5 seconds per log entry
        current_time += datetime.timedelta(seconds=random.randint(1, 5))
        timestamp_str = current_time.strftime("%Y-%m-%d %H:%M:%S")

        # Pick log level based on weights
        level = random.choices(levels, weights=level_weights)[0]

        # Pick a random template for that level and format it with dynamic variables
        template = random.choice(log_templates[level])
        log_message = template.format(
            ip=f"192.168.1.{random.randint(2, 254)}",
            user_id=random.randint(1000, 9999),
            order_id=random.randint(5000, 9999),
            conn_id=random.randint(10, 99),
            latency=random.randint(10, 1200),
            count=random.randint(2, 21),
            active=random.randint(2, 10),
            idle=random.randint(0, 8),
            waiting=random.randint(8, 47),
            trace="".join(random.choices("abcdef0123456789", k=6)),
            query_id=random.randint(1000, 9999),
            usage=random.randint(72, 98),
            pid=random.randint(4000, 5000),
            lag=random.randint(60, 1820),
            duration=round(random.uniform(0.8, 3.5), 1),
            ratio=round(random.uniform(0.80, 0.99), 2),
        )

        # Write formatted line matching: YYYY-MM-DD HH:MM:SS [LEVEL] message
        f.write(f"{timestamp_str} [{level}] {log_message}\n")

print(
    f"Successfully generated {TOTAL_LINES:,} log lines! You can now test your parsers or scripts with {OUTPUT_FILE}."
)