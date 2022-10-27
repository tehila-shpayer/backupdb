// db.adminCommand("listDatabases")["databases"].forEach((db) => {
//   printjson(db["name"]);
// });
db = db.getSiblingDB("hilma101");
printjson(db.getCollectionNames());
