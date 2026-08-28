import sqlite3
from typing import List, Tuple

# Function to retrieve and log the last 5 entries from reflex_history table
def fetch_recent_reflexes(db_path: str) -> List[Tuple[str, str, int]]:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM reflex_history ORDER BY timestamp DESC LIMIT 5;")
    recent_reflexes = cursor.fetchall()
    for reflex in recent_reflexes:
        print(reflex)
    conn.close()
    return recent_reflexes

# Usage example
if __name__ == "__main__":
    db_path = "/Users/javienbarnes/felicity_forge/sovereign.db"
    fetch_recent_reflexes(db_path)
