import sqlite3
import csv

# Replace this with your database path
db_path = "app.db"
# Replace this with your output file path, or set to None to print to console
output_file = "schema_info.csv"

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Get all tables and their types
cursor.execute("SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%'")
tables = cursor.fetchall()

# Prepare the results
results = []
headers = ["Schema", "Name", "Type", "Owner", "Persistence", "Access method", "Size", "Description"]

for table_name, table_type in tables:
    # Add table to results
    results.append([
        "main",               # Schema
        table_name,           # Name
        table_type,           # Type
        "sqlite",             # Owner
        "permanent",          # Persistence
        "heap",               # Access method
        "16 kB",              # Size (estimated)
        ""                    # Description
    ])
    
    # Find primary keys (similar to sequences)
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = cursor.fetchall()
    
    for column in columns:
        if column[5] == 1:  # Primary key
            results.append([
                "main",                           # Schema
                f"{table_name}_{column[1]}_seq",  # Name
                "sequence",                       # Type
                "sqlite",                         # Owner
                "permanent",                      # Persistence
                "",                               # Access method
                "8192 bytes",                     # Size
                ""                                # Description
            ])

conn.close()

# Write to CSV file or print to console
if output_file:
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(results)
    print(f"Schema information written to {output_file}")
else:
    import sys
    writer = csv.writer(sys.stdout)
    writer.writerow(headers)
    writer.writerows(results)