printjson(db.adminCommand("listDatabases")["databases"]).forEach((db) => {
  printjson(db.getName());
});
