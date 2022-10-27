printjson(adminCommand("listDatabases")).forEach((db) => {
  printjson(db.getName());
});
