import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class dataBase {
  Future<List<Map<String, dynamic>>> getProduct({
    DocumentSnapshot? startAfterDoc,
  }) async {
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
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBrandedProduct(
    String brand, {
    DocumentSnapshot? startAfterDoc,
  }) async {
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
      return [];
    }
  }

  Future<List<String>> getProductNames() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('product_names')
              .doc('all_product_names') 
              .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['names'] ?? []);
      }
      return []; 
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getProductByName(String name) async {
    final snap =
        await FirebaseFirestore.instance
            .collection('products')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

    return {...snap.docs.first.data(), 'id': snap.docs.first.id};
  }

  Future<void> incrementClickCount(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'clicked': FieldValue.increment(1)});
    } catch (e) {
    }
  }

  Future<List<Map<String, dynamic>>> getSearchedProduct(
    List<String> names,
  ) async {
    List<Map<String, dynamic>> allResults = [];

    for (String name in names) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .where('name', isEqualTo: name)
              .get();

      final List<Map<String, dynamic>> loadedProducts =
          snapshot.docs.map((doc) {
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
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }

      return null; 
    } catch (e) {
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream(String email) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.first);
  }

  Future<bool> updateUserDetails(
    String email,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
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
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection(
                'products',
              ) 
              .doc(productId)
              .get();

      if (snapshot.exists) {
        return snapshot.data(); 
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> submitOrder({
    required Map<String, dynamic> orderData,
    required String userEmail,
  }) async {
    try {
      orderData['timestamp'] = FieldValue.serverTimestamp();
      
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      
      await updateUserDetails(userEmail, {'cart_item': {}});
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateUserDetailsAfterBuy(
    String email,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
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
      return false;
    }
  }

  
  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('banners').get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'imageUrl': data['imageUrl'],
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
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

  Future<List<Map<String, dynamic>>> getFlashSaleProducts() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('products')
            .where("flashSell", isEqualTo: true)
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        "id": doc.id,
        "name": data['name'] ?? "",
        "price": data['price'] ?? "",
        "oldPrice": data['oldPrice'] ?? "",
        "image5": data['image5'] ?? "",
        "image20": data['image20'] ?? "",
        "details": data['details'] ?? "",
        "videoLink": data['videoLink'] ?? "",
        "brand": data['brand'] ?? "Others",
        "flashSell": data['flashSell'] ?? false,
        "flash-expire": data['flash-expire'], 
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getFreeGiftProducts() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('products')
            .where("freeGift", isEqualTo: true)
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        "id": doc.id,
        "name": data['name'] ?? "",
        "price": data['price'] ?? "",
        "oldPrice": data['oldPrice'] ?? "",
        "image5": data['image5'] ?? "",
        "image20": data['image20'] ?? "",
        "details": data['details'] ?? "",
        "videoLink": data['videoLink'] ?? "",
        "brand": data['brand'] ?? "Others",
        "freeGift": data['freeGift'] ?? false,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getNewArrivalProducts() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('products')
            .where("newArrival", isEqualTo: true)
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        "id": doc.id,
        "name": data['name'] ?? "",
        "price": data['price'] ?? "",
        "oldPrice": data['oldPrice'] ?? "",
        "image5": data['image5'] ?? "",
        "image20": data['image20'] ?? "",
        "details": data['details'] ?? "",
        "videoLink": data['videoLink'] ?? "",
        "brand": data['brand'] ?? "Others",
        "newArrival": data['newArrival'] ?? false,
      };
    }).toList();
  }

  Future<List<String>> getFCMToken() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where("fcmToken", isNotEqualTo: null)
            .get();

    return snapshot.docs.map((doc) => doc['token'] as String).toList();

  }



  Future<void> updateFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collectionName =
    user.isAnonymous ? 'anonymous_users' : 'users';

    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(user.uid)
        .set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  Future<bool> getGiftStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    return doc.data()?['gift'] == true;
  }

  Future<void> setGiftStatus(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({
      'gift': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  Future<String?> getPaymentNumber() async {

    final doc = await FirebaseFirestore.instance
        .collection("paymentNumber")
        .doc('9O1UpVqUrdyuTqiA3YQH')
        .get();

    if (!doc.exists) return null;

    return doc.data()?['number']?.toString();
  }

  Future<Map<String, dynamic>?> getLastGiftWinner() async {

    final doc = await FirebaseFirestore.instance
        .collection("free_gift")
        .doc('winner')
        .get();

    if (!doc.exists) return null;

    return doc.data();
  }

  Future<void> updateSilverCoin(
      double silver) async {

    final user =
        FirebaseAuth.instance.currentUser;

    if(user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({

      "silver_coin": silver,

      "updatedAt":
      FieldValue.serverTimestamp(),

    },SetOptions(merge:true));
  }

  Future<void> updateGoldCoin(
      double gold) async {

    final user =
        FirebaseAuth.instance.currentUser;

    if(user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({

      "free_delivery_info": gold,

      "updatedAt":
      FieldValue.serverTimestamp(),

    },SetOptions(merge:true));
  }

  Future<Map<String,dynamic>?> getUserCoins() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if(user == null) return null;

    final doc =
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if(!doc.exists) return null;

    return doc.data();
  }

Future<Map<String, dynamic>?> getRewardAdInfo() async {

  final user =
      FirebaseAuth.instance.currentUser;

  if (user == null) return null;

  final doc =
  await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .get();

  if (!doc.exists) return null;

  final data = doc.data();

  return data?["reward_ad_info"];
}

Future<void> updateRewardAdInfo(
Map<String, dynamic> data) async {

  final user =
      FirebaseAuth.instance.currentUser;

  if (user == null) return;

  await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .set({

    "reward_ad_info": data,

    "updatedAt":
    FieldValue.serverTimestamp(),

  }, SetOptions(merge: true));
}



}
