import 'package:cloud_firestore/cloud_firestore.dart';

class dataBase{

Future<List<Map<String, dynamic>>> getProduct(
    {DocumentSnapshot? startAfterDoc}) async {
  try {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(6);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      return {
        "id": doc.id,
        "name": data['name'],
        "price": data['price'],
        "details": data['details'],
        "videoLink": data['videoLink'],
        "image20": data['image20'],
        "image5": data['image5'],
        "brand": data['brand'] ?? 'Others',
        "clicked": data['clicked'] ?? 0,
        "createdAt": data['createdAt'],
        "docSnapshot": doc,
      };
    })
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (e) {
    print("Failed to load products: $e");
    return [];
  }
}


Future<List<Map<String, dynamic>>> getBrandedProduct(String brand,
    {DocumentSnapshot? startAfterDoc}) async {
  try {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('brand', isEqualTo: brand)
        .orderBy('createdAt', descending: true)
        .limit(6);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      return {
        "id": doc.id,
        "name": data['name'],
        "price": data['price'],
        "details": data['details'],
        "videoLink": data['videoLink'],
        "image20": data['image20'],
        "image5": data['image5'],
        "brand": data['brand'] ?? 'Others',
        "clicked": data['clicked'] ?? 0,
        "createdAt": data['createdAt'],
        "docSnapshot": doc,
      };
    })
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (e) {
    print("Failed to load brand products: $e");
    return [];
  }
}



Future<List<String>> getProductNames() async {
  try {
    final doc =
    await FirebaseFirestore.instance
        .collection('product_names')
        .doc('all_product_names') // Fixed document ID
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['names'] ?? []);
    }
    return []; // Return empty list if document doesn't exist
  } catch (e) {
    print("Error getting product names: $e");
    return [];
  }
}

Future<void> incrementClickCount(String productId) async {
  try {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({'clicked': FieldValue.increment(1)});
  } catch (e) {
    print("Error incrementing click count: $e");
  }
}

Future<List<Map<String, dynamic>>> getSearchedProduct(
    List<String> names) async {
  List<Map<String, dynamic>> allResults = [];

  for (String name in names) {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('name', isEqualTo: name)
        .get();

    final List<Map<String, dynamic>> loadedProducts = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "id": doc.id,
        "name": data['name'],
        "price": data['price'],
        "details": data['details'],
        "videoLink": data['videoLink'],
        "image20": data['image20'],
        "image5": data['image5'],
        "brand": data['brand'] ?? 'Others',
        "clicked": data['clicked'] ?? 0,
      };
    }).toList();

    allResults.addAll(loadedProducts);
  }

  return allResults;
}

Future<Map<String, dynamic>?> getUserDetails(String email) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    }

    return null; // No user found
  } catch (e) {
    print("Error getting user details: $e");
    return null;
  }
}

Future<bool> updateUserDetails(String email,
    Map<String, dynamic> updatedData) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final docId = querySnapshot.docs.first.id;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .update(updatedData);
      return true;
    }
    return false;
  } catch (e) {
    print("Error updating user details: $e");
    return false;
  }
}

Future<Map<String, dynamic>?> getProductById(String productId) async {
  try {
    DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection('products') // <-- Replace with your actual collection name
        .doc(productId)
        .get();

    if (snapshot.exists) {
      return snapshot.data(); // Returns a Map<String, dynamic>
    } else {
      print('No product found with ID: $productId');
      return null;
    }
  } catch (e) {
    print('Error fetching product: $e');
    return null;
  }
}


Future<void> submitOrder({
  required Map<String, dynamic> orderData,
  required String userEmail,
}) async {
  try {
    orderData['timestamp'] = FieldValue.serverTimestamp();
    // Save order to Firestore
    await FirebaseFirestore.instance.collection('orders').add(orderData);

    // Clear user's cart
    await updateUserDetails(userEmail, {'cart_item': {}});
  } catch (e) {
    print("Order submission error: $e");
    rethrow;
  }
}

  Future<bool> updateUserDetailsAfterBuy(String email, Map<String, dynamic> updatedData) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docRef = querySnapshot.docs.first.reference;
        await docRef.update(updatedData);
        return true;
      }
      return false;
    } catch (e) {
      print("Error updating user details: $e");
      return false;
    }
  }


// Add this method to your dataBase class in services/firebase.dart
  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('banners')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'imageUrl': data['imageUrl'],
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
      print("Error fetching active banners: $e");
      return [];
    }
  }


  Stream<String?> getVersionStream() {
    return FirebaseFirestore.instance
        .collection('version')
        .doc('jL4qHQOWC9wGMKyBGMAT')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return snapshot.get('version').toString();
      }
      return null;
    });
  }
}