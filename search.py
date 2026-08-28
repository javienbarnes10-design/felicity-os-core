import sys
import os
import urllib.request
import urllib.parse
import re

# Handle broken pipes silently when piped into head/grep
try:
    sys.stdout.reconfigure(line_buffering=True)
except AttributeError:
    pass

if len(sys.argv) < 2:
    print("Usage: python3 search.py 'your query'")
    sys.exit(1)

query = sys.argv[1]
url = "https://html.duckduckgo.com/html/"
data = urllib.parse.urlencode({'q': query}).encode('utf-8')

headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5"
}

try:
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=10) as response:
        html = response.read().decode('utf-8', errors='ignore')

    titles = re.findall(r'<a class="result__a"[^>]*>(.*?)</a>', html, re.DOTALL)
    snippets = re.findall(r'<a class="result__snippet[^>]*>(.*?)</a>', html, re.DOTALL)

    if not titles:
        titles = re.findall(r'<h2 class="result__title">\s*<a[^>]*>(.*?)</a>', html, re.DOTALL)

    if titles:
        for i in range(min(5, len(titles))):
            clean_title = re.sub(r'<.*?>', '', titles[i]).strip()
            clean_snippet = re.sub(r'<.*?>', '', snippets[i]).strip() if i < len(snippets) else ""
            print(f"[{i+1}] {clean_title} - {clean_snippet}")
    else:
        print("No results found.")

except BrokenPipeError:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, sys.stdout.fileno())
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}")

