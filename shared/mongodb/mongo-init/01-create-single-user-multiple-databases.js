// Switch to admin database for authentication
db = db.getSiblingDB('admin');
db.auth(process.env.MONGO_INITDB_ROOT_USERNAME, process.env.MONGO_INITDB_ROOT_PASSWORD);

print('Creating single user with access to multiple databases...');

// Create single user in admin database with roles for multiple databases
db.createUser({
  user: process.env.APP_USER,
  pwd: process.env.APP_PASSWORD,
  roles: [
    {
      role: 'readWrite',
      db: process.env.LIBRECHAT_DB
    },
    {
      role: 'readWrite', 
      db: process.env.MADPIN_DB
    }
    // Add more databases here as needed:
    // {
    //   role: 'readWrite',
    //   db: 'future_database_name'
    // }
  ]
});

print('✓ Single user created with multi-database access');

// Create the actual databases with initial collections
db = db.getSiblingDB(process.env.LIBRECHAT_DB);
db.createCollection('conversations');
print('✓ LibreChat database created');

db = db.getSiblingDB(process.env.MADPIN_DB);
db.createCollection('pins');
print('✓ MadPin database created');

print('Database initialization completed successfully!');
