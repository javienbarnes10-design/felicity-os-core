import os
import hashlib

def inspect_source():
    source_path = __file__
    with open(source_path, 'r') as file:
        content = file.read()
        lines_count = len(content.splitlines())
        functions_count = sum(1 for line in content.splitlines() if line.strip().startswith('def '))
    
    sha256_hash = hashlib.sha256(content.encode()).hexdigest()

    metrics = {
        'source_path': source_path,
        'lines_count': lines_count,
        'functions_count': functions_count,
        'sha256_hash': sha256_hash
    }

    with open(os.path.join(os.path.dirname(source_path), 'self_metrics.json'), 'w') as json_file:
        json.dump(metrics, json_file)

inspect_source()
