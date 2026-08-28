import sqlite3
import re

# Connect to the database
conn = sqlite3.connect('/Users/javienbarnes/felicity_forge/sovereign.db')
c = conn.cursor()

# Fetch all rows from reflex_history
c.execute("SELECT * FROM reflex_history")
rows = c.fetchall()

# Print the fetched data
for row in rows:
    print(row)

# Open error_sense.log and error_patterns.log
with open('/Users/javienbarnes/felicity_forge/error_sense.log', 'r') as sense_file:
    sense_content = sense_file.readlines()

with open('/Users/javienbarnes/felicity_forge/error_patterns.log', 'r') as pattern_file:
    pattern_content = pattern_file.readlines()

# Close the database connection
conn.close()
