import sqlite3
import json
from datetime import datetime, timedelta

# Connect to database
conn = sqlite3.connect('/Users/javienbarnes/felicity_forge/sovereign.db')
c = conn.cursor()

# Function to convert string timestamp to datetime object
def convert_timestamp(timestamp_str):
    try:
        return datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None

# Fetch reflex history
c.execute("SELECT timestamp, command, exit_code FROM reflex_history")
reflex_data = c.fetchall()

# Initialize findings dictionary
findings = {}

# Process error logs
for log_file in ['error_sense.log', 'error_patterns.log']:
    with open(log_file, 'r') as f:
        for line in f:
            log_time, message = line.strip().split(' ', 1)
            log_timestamp = convert_timestamp(log_time)
            if log_timestamp:
                log_seconds = int(log_timestamp.timestamp())
                for record in reflex_data:
                    db_timestamp_str = record[0]
                    db_seconds = int(datetime.strptime(db_timestamp_str, "%Y-%m-%d %H:%M:%S").timestamp())
                    if abs(log_seconds - db_seconds) <= 5 and record[2] == 0:
                        if record not in findings:
                            findings[record] = message

# Update database with findings
for record, message in findings.items():
    c.execute("UPDATE reflex_history SET exit_code = 1 WHERE timestamp = ? AND command = ?", (record[0], record[1]))

# Save findings to JSON
with open('/Users/javienbarnes/felicity_forge/system_audit/discrepancy_report.json', 'w') as json_file:
    json.dump(findings, json_file, indent=4)

# Commit changes and close connection
conn.commit()
conn.close()
