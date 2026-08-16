import os, json, hashlib

def count_metrics():
    with open(__file__, 'r') as file:
        code = file.readlines()
    return len(code), len([func for func in code if func.strip().startswith('def ')]), hashlib.sha256(open(__file__, 'rb').read()).hexdigest()

if __name__ == '__main__':
    lines, functions, sha_hash = count_metrics()
    json_data = {"lines": lines, "functions": functions, "hash": sha_hash}
    with open(f'{os.path.splitext(__file__)[0]}_metrics.json', 'w') as file:
        json.dump(json_data, file)

