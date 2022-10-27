printjson("listDatabases").forEach((db) => {
  printjson(db.getName());
});
