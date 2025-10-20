import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:dadu/services/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/district_upozila.dart';
import '../../model/cart_model.dart';
import '../../services/auth.dart';
import '../../services/firebase.dart';

class CheckOut extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;

  const CheckOut({
    super.key,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<CheckOut> createState() => _CheckOutState();
}

class _CheckOutState extends State<CheckOut> {
  final dataBase db = new dataBase();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _paymentMethod = 'bkash';
  bool _isProcessing = false;
  String? selectedDistrict;
  String? selectedThana;
  List<String> thanaList = [];
  File? _paymentProofImage;
  final ImagePicker _picker = ImagePicker();
  bool _imageSelected = false;
  String? paymentProof;
  int deliveryPoints = 0;
  bool _freeDeliverySelected = false;
  bool freeDeliveryUsed = false;
  int baseDeliveryCharge = 0;
  int deliveryCharge = 0;
  double _total = 0;

  final Auth _auth = Auth();
  final ImageService _imageService = ImageService();

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) return;

      final userDetails = await db.getUserDetails(currentUser.email!);
      if (userDetails != null) {
        setState(() {
          _nameController.text = userDetails['name'] ?? '';
          _phoneController.text = userDetails['phone'] ?? '';
          _addressController.text = userDetails['address'] ?? '';
          selectedDistrict = userDetails['district'];
          selectedThana = userDetails['thana'];
          deliveryPoints = userDetails['free_delivery_info'] ?? 0;
          freeDeliveryUsed = userDetails['freeDeliveryUsed'] ?? false;

          if (selectedDistrict != null) {
            thanaList =
                DistrictUpozila().districtToThanas[selectedDistrict] ?? [];
          }
          _calculateDeliveryCharge();
        });
      }
    } catch (e) {
      print("Error loading user address: $e");
    }
  }

  Future<void> _pickPaymentProof() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _paymentProofImage = File(image.path);
        _imageSelected = true;
      });
    }
  }

  void _removePaymentProof() {
    setState(() {
      _paymentProofImage = null;
      _imageSelected = false;
    });
  }

  int get totalQuantity {
    return widget.cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  void _calculateDeliveryCharge() {
    int glovesCount = widget.cartItems
        .where((item) => item.brand == 'Gloves')
        .fold(0, (sum, item) => sum + item.quantity);

    int othersCount = widget.cartItems
        .where((item) => item.brand == 'Others')
        .fold(0, (sum, item) => sum + item.quantity);

    int discountItems = glovesCount + othersCount;
    int totalQuantity = widget.cartItems.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
    int normalItems = totalQuantity - discountItems;

    int calculatedCharge = 100 + (normalItems * 30) + (discountItems * 10);
    baseDeliveryCharge = calculatedCharge < 130 ? 130 : calculatedCharge;
    deliveryCharge = _freeDeliverySelected ? 0 : baseDeliveryCharge;
    _total = widget.totalAmount + deliveryCharge;
  }

  void _toggleFreeDelivery() {
    setState(() {
      _freeDeliverySelected = !_freeDeliverySelected;
      if (_freeDeliverySelected) {
        _paymentProofImage = null;
        _imageSelected = false;
      }
      _calculateDeliveryCharge();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate payment proof
    if (!_freeDeliverySelected &&
        (_paymentMethod == 'bkash' ||
            _paymentMethod == 'nagad' ||
            _paymentMethod == 'rocket') &&
        !_imageSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload payment proof screenshot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception("User not authenticated");
      }

      // Upload payment proof if needed
      if (!_freeDeliverySelected && _paymentProofImage != null) {
        paymentProof = await _imageService.uploadProfileImage(_paymentProofImage!);
      }

      // Create order data to save in user collection
      final userUpdateData = {
        "to_verify": FieldValue.arrayUnion([
          {
            'order_id': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
            'customerName': _nameController.text,
            'customerEmail': currentUser.email,
            'phone': _phoneController.text,
            'address': _addressController.text,
            'district': selectedDistrict ?? '',
            'thana': selectedThana ?? '',
            'paymentMethod': _paymentMethod,
            'paymentProof': paymentProof ?? '',
            'items': widget.cartItems.map((item) => {
              'id': item.id,
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'imageUrl': item.imageUrl,
              'order_uid': '${DateTime.now().millisecondsSinceEpoch}-${item.id}',
              'size': item.size,
            }).toList(),
            'subtotal': widget.totalAmount,
            'deliveryCharge': deliveryCharge,
            'total': _total,
            'order_status': "verify",
            'freeDeliveryUsed': _freeDeliverySelected,
            'baseDeliveryCharge': baseDeliveryCharge,
            'deliveryPoints': deliveryPoints,
            'order_date': DateTime.now().millisecondsSinceEpoch,
          }
        ]),
        'freeDeliveryUsed': _freeDeliverySelected,
        'cart_item': {}, // Clear cart
      };

      await db.updateUserDetailsAfterBuy(currentUser.email!, userUpdateData);

      _showConfirmationDialog();
    } catch (e) {
      print("Error submitting order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Order failed: ${e.toString().split(':').last}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Order Confirmed'),
            content: const Text('Your order has been placed successfully!'),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Continue Shopping'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => Profile()),
                  );
                },
                child: const Text('View Orders'),
              ),
            ],
          ),
    );
  }

  Widget _buildShippingForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator:
                (value) =>
                    value == null || value.isEmpty
                        ? 'Please enter your name'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.length != 11) {
                return "Please enter a valid 11-digit phone number";
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedDistrict,
            decoration: const InputDecoration(
              labelText: 'District',
              prefixIcon: Icon(Icons.location_city),
              border: OutlineInputBorder(),
            ),
            validator:
                (value) =>
                    value == null || value.isEmpty
                        ? 'Please select a district'
                        : null,
            items:
                DistrictUpozila().districtToThanas.keys.map((district) {
                  return DropdownMenuItem(
                    value: district,
                    child: Text(district),
                  );
                }).toList(),
            onChanged:
                (newValue) => setState(() {
                  selectedDistrict = newValue;
                  selectedThana = null;
                  thanaList =
                      DistrictUpozila().districtToThanas[newValue] ?? [];
                }),
          ),
          const SizedBox(height: 12),
          if (thanaList.isNotEmpty)
            DropdownButtonFormField<String>(
              value: selectedThana,
              decoration: const InputDecoration(
                labelText: 'Thana/Upozila',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator:
                  (value) =>
                      value == null || value.isEmpty
                          ? 'Please select a thana'
                          : null,
              items:
                  thanaList.map((thana) {
                    return DropdownMenuItem(value: thana, child: Text(thana));
                  }).toList(),
              onChanged:
                  (newValue) => setState(() {
                    selectedThana = newValue;
                  }),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.home),
              border: OutlineInputBorder(),
            ),
            validator:
                (value) =>
                    value == null || value.isEmpty
                        ? 'Please enter your address'
                        : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDeliveryButton() {
    if (deliveryPoints >= baseDeliveryCharge && !freeDeliveryUsed) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: ElevatedButton(
          onPressed: _toggleFreeDelivery,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _freeDeliverySelected
                    ? Colors.green
                    : Theme.of(context).primaryColor,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text(
            _freeDeliverySelected
                ? 'Free Delivery Applied! Remaining Points: ${deliveryPoints - baseDeliveryCharge}'
                : 'Use Free Delivery (Cost: $baseDeliveryCharge points)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      children: [
        RadioListTile(
          title: const Text('Bkash'),
          value: 'bkash',
          groupValue: _paymentMethod,
          onChanged:
              (value) => setState(() => _paymentMethod = value.toString()),
        ),
        RadioListTile(
          title: const Text('Nagad'),
          value: 'nagad',
          groupValue: _paymentMethod,
          onChanged:
              (value) => setState(() => _paymentMethod = value.toString()),
        ),
        RadioListTile(
          title: const Text('Rocket'),
          value: 'rocket',
          groupValue: _paymentMethod,
          onChanged:
              (value) => setState(() => _paymentMethod = value.toString()),
        ),
      ],
    );
  }

  Widget _buildPaymentProofSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Proof( upload screenshoot of your send money ) (আপনার পাঠানো টাকার স্ক্রিনশট আপলোড করুন)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _paymentProofImage != null
            ? Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Image.file(_paymentProofImage!, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: _removePaymentProof,
                    ),
                  ),
                ),
              ],
            )
            : ElevatedButton(
              onPressed: _pickPaymentProof,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Upload Screenshot',
                style: TextStyle(color: Colors.white),
              ),
            ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOrderSummaryItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Qty: ${item.quantity}',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  'Size: ${item.size}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '৳${(item.price * item.quantity).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '৳${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal ? Theme.of(context).primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...widget.cartItems.map(_buildOrderSummaryItem),
            const Divider(),
            _buildSummaryRow('Subtotal', widget.totalAmount),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Shipping', style: TextStyle(fontSize: 14)),
                  Text(
                    _freeDeliverySelected
                        ? 'FREE (৳0.00)'
                        : '৳${deliveryCharge.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          _freeDeliverySelected ? Colors.green : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildSummaryRow('Total', _total, isTotal: true),
          ],
        ),
      ),
    );
  }

  int colorr = 0xFFf2f2ce;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(colorr),
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shipping Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildShippingForm(),
            _buildFreeDeliveryButton(),

            if (!_freeDeliverySelected) ...[
              const SizedBox(height: 24),
              ListTile(
                title: const Text(
                  "Number to Pay(send money)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Row(
                  children: [
                    const SelectableText(
                      "01793011106",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(text: "01793011106"),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Number copied')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPaymentMethodSection(),
              if (!_freeDeliverySelected &&
                  (_paymentMethod == 'bkash' ||
                      _paymentMethod == 'nagad' ||
                      _paymentMethod == 'rocket'))
                _buildPaymentProofSection(),
            ],

            const SizedBox(height: 24),
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildOrderSummary(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'PLACE ORDER',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
