import sqlite3

# Connect to the database
conn = sqlite3.connect('db.sqlite3')
cursor = conn.cursor()

# Query the orders table
cursor.execute('SELECT id, status FROM api_order')
orders = cursor.fetchall()

print(f'Orders: {len(orders)}')
for order in orders:
    print(f'Order {order[0]}: {order[1]}')

conn.close()
