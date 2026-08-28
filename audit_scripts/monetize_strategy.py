import sqlite3
from felicity_v2_blueprint import FELICITY_CORE
conn = sqlite3.connect('/Users/javienbarnes/felicity_forge/sovereign.db')
c = conn.cursor()
c.execute("SELECT * FROM felicity_v2_blueprint")
blueprint = c.fetchone()
FELICITY_CORE(blueprint[0], blueprint[1], blueprint[2])
