import json
with open("/tmp/top_processes.txt") as f:
    data = f.read().splitlines()
processes = [{"command": line.split()[-1], "cpu_usage": float(line.split()[8])} for line in data if line.startswith("COMMAND")]
sorted_process = sorted(processes, key=lambda x: -x["cpu_usage"])
import os
os.makedirs("/Users/javienbarnes/felicity_forge/system_audit", exist_ok=True)
with open("/Users/javienbarnes/felicity_forge/system_audit/system_audit.json", "w") as json_file:
    json.dump(sorted_process[:5], json_file)
