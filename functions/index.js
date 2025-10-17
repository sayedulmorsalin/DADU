const functions = require("firebase-functions");
const admin = require("firebase-admin");
const algoliasearch = require("algoliasearch");

admin.initializeApp();

const ALGOLIA_APP_ID = "K37GZ9H4S0";
const ALGOLIA_ADMIN_KEY = "ffaeb7080209cd956c78a78c37c1794e";
const ALGOLIA_INDEX_NAME = "products"; // Make sure this matches your Algolia index

const client = algoliasearch(ALGOLIA_APP_ID, ALGOLIA_ADMIN_KEY);
const index = client.initIndex(ALGOLIA_INDEX_NAME);

exports.syncProductToAlgolia = functions.firestore
  .document("products/{productId}")
  .onWrite(async (change, context) => {
    const productId = context.params.productId;

    if (!change.after.exists) {
      // If document is deleted
      return index.deleteObject(productId);
    }

    const data = change.after.data();

    const record = {
      objectID: productId,
      name: data.name,
      category: data.category,
      brand: data.brand,
      price: data.price,
      // Add more fields if needed
    };

    return index.saveObject(record);
  });
