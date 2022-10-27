// db.adminCommand("listDatabases")["databases"].forEach((db) => {
//   printjson(db["name"]);
// });
db = db.getSiblingDB("amigo-hadasa");
printjson(db.getCollectionNames());
