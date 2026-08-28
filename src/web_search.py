import urllib.request
import json

query = 'current logistics freight spot rates'
url = f'https://api.duckduckgo.com/?q={query}&format=json&t=python&pretty=1'

try:
    response = urllib.request.urlopen(url)
    data = json.loads(response.read().decode('utf-8'))
    print(data)
except Exception as e:
    print(f'An error occurred: {e}')
