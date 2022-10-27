// conn = new Mongo();
// dbadmin = conn.getDB("admin");
// printjson(dbadmin.adminCommand("listDatabases")).forEach((db) => {
//   printjson(db.getName());
// });
printjson(db.adminCommand("listDatabases"));
