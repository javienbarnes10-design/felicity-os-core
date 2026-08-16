import json
from collections import defaultdict

with open("/Users/javienbarnes/felicity_forge/system_audit/cpu_load.csv", "r") as f:
    data = [{k: v for k, v in zip(["pid", "process"], row.split(","))} for row in f]

top_cpu_processes = sorted(data, key=lambda x: int(x["pid"]), reverse=True)[:5]
with open("/Users/javienbarnes/felicity_forge/system_audit/system_audit.json", "w") as json_file:
    json.dump(top_cpu_processes, json_file)
