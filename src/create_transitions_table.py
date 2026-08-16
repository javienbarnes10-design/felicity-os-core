import sqlite3
conn = sqlite3.connect("/Users/javienbarnes/felicity_forge/sovereign.db")
cur = conn.cursor()
try:
    cur.execute("CREATE TABLE IF NOT EXISTS transitions (state TEXT, action TEXT, next_state TEXT, value REAL, visits INTEGER, PRIMARY KEY (state, action))")
except sqlite3.OperationalError as e:
    print(e)
conn.commit()
conn.close()