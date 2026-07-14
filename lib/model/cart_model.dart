
class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final String catagory;
  final String size;
  final double deliveryFee;
  final double freeCoin;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.catagory,
    required this.size,
    this.deliveryFee = 0.0,
    this.freeCoin = 0.0,
  });
}