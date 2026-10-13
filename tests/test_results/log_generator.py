import datetime
import random

# Configuration
TOTAL_LINES = 10_000
OUTPUT_FILE = "backend_simulation.log"

# Define log levels and their occurrence weights (INFO is most common)
levels = ["INFO", "WARNING", "ERROR"]
level_weights = [0.75, 0.18, 0.07]

# Event templates categorized by level
log_templates = {
    "INFO": [
        "GET: /api/v1/health/ 200 OK - IP: {ip}",
        "User: authentication successful for user_id={user_id}",
        "POST: /api/v1/orders/ created successfully - Order ID: {order_id}",
        "User: logout initiated for user_id={user_id}",
        "Database: connection pool acquired connection ID #{conn_id}",
    ],
    "WARNING": [
        "High: latency detected on database query for order_id={order_id} (duration: {latency}ms)",
        "Rate: limit approaching for IP: {ip} (92 requests in last minute)",
        "Cache: miss for key user_profile_{user_id}, falling back to database",
        "Deprecated: API endpoint v0 accessed by IP: {ip}",
    ],
    "ERROR": [
        "OperationalError: connection to database server at '127.0.0.1' failed",
        "KeyError: 'user_token' missing from request headers for IP: {ip}",
        "Database: timeout after 5000ms executing query on table 'orders'",
        "Unhandled: exception in view apps.orders.views.checkout for user_id={user_id}",
    ],
}

print(f"Generating {TOTAL_LINES:,} log entries into '{OUTPUT_FILE}'...")

start_time = datetime.datetime.now()

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    current_time = start_time

    for i in range(TOTAL_LINES):
        # Advance time slightly between 1 to 5 seconds per log entry
        current_time += datetime.timedelta(seconds=random.randint(1, 5))
        timestamp_str = current_time.strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]

        # Pick log level based on weights
        level = random.choices(levels, weights=level_weights)[0]

        # Pick a random template for that level and format it with dynamic variables
        template = random.choice(log_templates[level])
        log_message = template.format(
            ip=f"192.168.1.{random.randint(2, 254)}",
            user_id=random.randint(1000, 9999),
            order_id=random.randint(5000, 9999),
            conn_id=random.randint(10, 99),
            latency=random.randint(400, 1200),
        )

        # Write formatted line
        f.write(f"{timestamp_str} [{level}] {log_message}\n")

print(
    f"Successfully generated {TOTAL_LINES:,} log lines! You can now test your parsers or scripts with {OUTPUT_FILE}."
)