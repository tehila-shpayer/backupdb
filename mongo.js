conn = new Mongo();
dbadmin = conn.getDB("admin");
printjson(adminCommand("listDatabases")).forEach((db) => {
  printjson(db.getName());
});
