import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu/screen/user/order_list_screen.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:dadu/services/api.dart';
import 'package:dadu/services/app_version_service.dart';
import 'package:dadu/services/transaction_id_extractor.dart';
import 'package:dadu/services/transaction_verification_service.dart';
import 'package:dadu/theme/app_colors.dart';
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

class _CheckOutState extends State<CheckOut> with WidgetsBindingObserver {
  final dataBase db = new dataBase();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();
  String _paymentMethod = 'bkash';
  bool _isProcessing = false;
  bool _isScanningProof = false;
  bool _trxAutoDetected = false;
  String? selectedDistrict;
  String? selectedThana;
  List<String> thanaList = [];
  File? _paymentProofImage;
  final ImagePicker _picker = ImagePicker();
  bool _imageSelected = false;
  String? paymentProof;
  double deliveryPoints = 0;
  bool _freeDeliverySelected = false;
  bool _coinDiscountSelected = false;
  double _coinDiscountAmount = 0;
  int baseDeliveryCharge = 0;
  int deliveryCharge = 0;
  double _total = 0;
  bool needupdate = false;
  bool _versionCheckLoading = true;
  Map<String, dynamic>? _paymentDetails;
  bool _paymentNumberLoading = false;

  final Auth _auth = Auth();
  final ImageService _imageService = ImageService();
  final TransactionVerificationService _transactionVerificationService =
      TransactionVerificationService();

  bool _isValidatingTrx = false;
  TransactionVerificationResult _trxVerificationResult =
      TransactionVerificationResult.unverified();
  Timer? _trxDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transactionIdController.addListener(_onTransactionIdChanged);
    _calculateDeliveryCharge();
    _loadUserAddress();
    _loadPaymentNumber();
    _refreshVersionRequirement();
  }

  void _onTransactionIdChanged() {
    final text = _transactionIdController.text.trim();
    if (text.isEmpty) {
      _trxDebounceTimer?.cancel();
      if (!_trxVerificationResult.isUnverified || _isValidatingTrx) {
        setState(() {
          _isValidatingTrx = false;
          _trxVerificationResult = TransactionVerificationResult.unverified();
        });
      }
      return;
    }

    _trxDebounceTimer?.cancel();
    _trxDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _verifyTransactionId(text);
    });
  }

  Future<void> _verifyTransactionId(String trxId) async {
    final clean = trxId.trim();
    if (clean.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _isValidatingTrx = true;
    });

    try {
      final result = await _transactionVerificationService.verifyTransaction(
        clean,
        expectedProvider: _paymentMethod,
      );

      if (!mounted) return;

      if (_transactionIdController.text.trim().toLowerCase() ==
          clean.toLowerCase()) {
        setState(() {
          _isValidatingTrx = false;
          _trxVerificationResult = result;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingTrx = false;
        _trxVerificationResult = TransactionVerificationResult.error(
          'Verification failed: ${e.toString()}',
          trxId: clean,
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant CheckOut oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.totalAmount != widget.totalAmount ||
        oldWidget.cartItems != widget.cartItems) {
      _calculateDeliveryCharge();
    }
  }

  Future<void> _refreshVersionRequirement() async {
    final requiresUpdate = await AppVersionService.isUpdateRequired();

    if (!mounted) return;

    setState(() {
      needupdate = requiresUpdate;
      _versionCheckLoading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    setState(() {
      _versionCheckLoading = true;
    });

    _refreshVersionRequirement();
  }

  Future<void> _openUpdateFlow() async {
    final opened = await AppVersionService.openUpdateFlow();

    if (opened || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open update page'),
        backgroundColor: AppColors.warning,
      ),
    );
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
          deliveryPoints =
              (userDetails['free_delivery_info'] as num?)?.toDouble() ?? 0.0;

          if (selectedDistrict != null) {
            thanaList =
                DistrictUpozila().districtToThanas[selectedDistrict] ?? [];
          }
          _calculateDeliveryCharge();
        });
      }
    } catch (e) {
      // Failed to load checkout user data
    }
  }

  Future<void> _loadPaymentNumber() async {
    setState(() => _paymentNumberLoading = true);
    try {
      final details = await db.getPaymentNumber();
      if (!mounted) return;
      setState(() {
        _paymentDetails = details;
        _paymentNumberLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentDetails = null;
        _paymentNumberLoading = false;
      });
    }
  }

  String _getDisplayNumber() {
    if (_paymentDetails == null) return "Not available";

    String? specificNumber = _paymentDetails![_paymentMethod]?.toString();
    if (specificNumber != null && specificNumber.trim().isNotEmpty) {
      return specificNumber;
    }

    return _paymentDetails!['number']?.toString() ?? "Not available";
  }

  Future<void> _pickPaymentProof() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _paymentProofImage = File(image.path);
        _imageSelected = true;
        _isScanningProof = true;
        _trxAutoDetected = false;
      });

      try {
        final extractedTrx =
            await TransactionIdExtractor.extractTransactionId(image.path);
        if (!mounted) return;

        setState(() {
          _isScanningProof = false;
          if (extractedTrx != null && extractedTrx.isNotEmpty) {
            _transactionIdController.text = extractedTrx;
            _trxAutoDetected = true;
          }
        });

        if (extractedTrx != null && extractedTrx.isNotEmpty) {
          _verifyTransactionId(extractedTrx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.textOnPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Transaction ID detected: $extractedTrx'),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not auto-detect Transaction ID. You can enter it manually below.',
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isScanningProof = false;
        });
      }
    }
  }

  Future<void> _rescanPaymentProof() async {
    if (_paymentProofImage == null) return;

    setState(() {
      _isScanningProof = true;
      _trxAutoDetected = false;
    });

    try {
      final extractedTrx =
          await TransactionIdExtractor.extractTransactionId(_paymentProofImage!.path);
      if (!mounted) return;

      setState(() {
        _isScanningProof = false;
        if (extractedTrx != null && extractedTrx.isNotEmpty) {
          _transactionIdController.text = extractedTrx;
          _trxAutoDetected = true;
        }
      });

      if (extractedTrx != null && extractedTrx.isNotEmpty) {
        _verifyTransactionId(extractedTrx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.textOnPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Transaction ID detected: $extractedTrx'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not auto-detect Transaction ID. Please enter manually.',
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanningProof = false;
      });
    }
  }

  void _removePaymentProof() {
    _trxDebounceTimer?.cancel();
    setState(() {
      _paymentProofImage = null;
      _imageSelected = false;
      _isScanningProof = false;
      _trxAutoDetected = false;
      _isValidatingTrx = false;
      _trxVerificationResult = TransactionVerificationResult.unverified();
      _transactionIdController.clear();
    });
  }

  int get totalQuantity {
    return widget.cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  double get _freeDeliveryCost => baseDeliveryCharge.toDouble();

  bool get _canUseFreeDelivery =>
      baseDeliveryCharge > 0 && deliveryPoints >= _freeDeliveryCost;

  void _calculateDeliveryCharge() {
    double maxSingleFee = 0;
    double totalAllFees = 0;

    for (var item in widget.cartItems) {
      if (item.deliveryFee > maxSingleFee) {
        maxSingleFee = item.deliveryFee;
      }
      totalAllFees += (item.deliveryFee * item.quantity);
    }

    int minimumCharge = 130;
    bool isNaogaon = selectedDistrict?.trim().toLowerCase() == 'naogaon';
    bool isNiamatpur = selectedThana?.trim().toLowerCase() == 'niamatpur';

    if (isNaogaon) {
      minimumCharge = isNiamatpur ? 30 : 70;
    }

    // Logic: Max(minimumCharge, highest single delivery fee) + (Sum of all fees - that highest single fee)
    double baseFee = (maxSingleFee > minimumCharge) ? maxSingleFee : minimumCharge.toDouble();
    double extraFees = totalAllFees - maxSingleFee;
    
    baseDeliveryCharge = (baseFee + extraFees).toInt();
    deliveryCharge = _freeDeliverySelected ? 0 : baseDeliveryCharge;

    double pointsForFreeDelivery =
        _freeDeliverySelected ? _freeDeliveryCost : 0.0;
    double availablePoints = (deliveryPoints - pointsForFreeDelivery).clamp(
      0.0,
      double.infinity,
    );

    if (_coinDiscountSelected && availablePoints >= 10) {
      _coinDiscountAmount = availablePoints;
    } else {
      _coinDiscountAmount = 0;
    }

    // Cap discount at subtotal
    if (_coinDiscountAmount > widget.totalAmount) {
      _coinDiscountAmount = widget.totalAmount;
    }

    _total = widget.totalAmount + deliveryCharge - _coinDiscountAmount;
  }

  void _toggleCoinDiscount() {
    setState(() {
      _coinDiscountSelected = !_coinDiscountSelected;
      _calculateDeliveryCharge();
    });
  }

  void _toggleFreeDelivery() {
    _trxDebounceTimer?.cancel();
    setState(() {
      _freeDeliverySelected = !_freeDeliverySelected;
      if (_freeDeliverySelected) {
        _paymentProofImage = null;
        _imageSelected = false;
        _isScanningProof = false;
        _trxAutoDetected = false;
        _isValidatingTrx = false;
        _trxVerificationResult = TransactionVerificationResult.unverified();
        _transactionIdController.clear();
      }
      _calculateDeliveryCharge();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trxDebounceTimer?.cancel();
    _transactionIdController.removeListener(_onTransactionIdChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_freeDeliverySelected &&
        (_paymentMethod == 'bkash' ||
            _paymentMethod == 'nagad' ||
            _paymentMethod == 'rocket')) {
      final trxId = _transactionIdController.text.trim();
      if (trxId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter or scan the Transaction ID'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      setState(() => _isProcessing = true);

      // Verify transaction against database
      final verifyRes = await _transactionVerificationService.verifyTransaction(
        trxId,
        expectedProvider: _paymentMethod,
      );

      if (!mounted) return;

      setState(() {
        _trxVerificationResult = verifyRes;
      });

      if (!verifyRes.isValid) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verifyRes.message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (needupdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please update your app first'),
          backgroundColor: AppColors.warning,
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

      final double usedPoints =
          (_freeDeliverySelected ? _freeDeliveryCost : 0.0) +
          (_coinDiscountSelected ? _coinDiscountAmount : 0.0);

      final double remainingDeliveryPoints = (deliveryPoints - usedPoints)
          .clamp(0.0, double.infinity)
          .toDouble();

      final userUpdateData = {
        "to_verify": FieldValue.arrayUnion([
          {
            'order_id': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
            'customerName': _nameController.text,
            'customerEmail': currentUser.email,
            'phone': _phoneController.text,
            'address': _addressController.text,
            'note': _noteController.text.trim(),
            'district': selectedDistrict ?? '',
            'thana': selectedThana ?? '',
            'paymentMethod': _paymentMethod,
            'paymentProof': '',
            'transaction_id': _transactionIdController.text.trim(),
            'items':
                widget.cartItems
                    .map(
                      (item) => {
                        'id': item.id,
                        'name': item.name,
                        'price': item.price,
                        'quantity': item.quantity,
                        'imageUrl': item.imageUrl,
                        'catagory': item.catagory,
                        'deliveryFee': item.deliveryFee,
                        'freeCoin': item.freeCoin,
                        'order_uid':
                            '${DateTime.now().millisecondsSinceEpoch}-${item.id}',
                        'size': item.size,
                      },
                    )
                    .toList(),
            'subtotal': widget.totalAmount,
            'deliveryCharge': deliveryCharge,
            'coinDiscount': _coinDiscountAmount,
            'total': _total,
            'totalFreeCoins': widget.cartItems.fold(0.0, (sum, item) => sum + (item.freeCoin * item.quantity)),
            'order_status': "verify",
            'freeDeliveryUsed': _freeDeliverySelected,
            'coinDiscountUsed': _coinDiscountSelected,
            'baseDeliveryCharge': baseDeliveryCharge,
            'deliveryPoints': deliveryPoints,
            'deliveryPointsUsed': usedPoints,
            'remainingDeliveryPoints': remainingDeliveryPoints,
            'order_date': DateTime.now().millisecondsSinceEpoch,
          },
        ]),
        'free_delivery_info': remainingDeliveryPoints,
        'freeDeliveryUsed': false,
        'cart_item': {},
      };

      await db.updateUserDetailsAfterBuy(currentUser.email!, userUpdateData);

      // Mark the transaction as used in Cloudflare D1 database so it cannot be reused
      if (!_freeDeliverySelected &&
          (_paymentMethod == 'bkash' ||
              _paymentMethod == 'nagad' ||
              _paymentMethod == 'rocket')) {
        final trxId = _transactionIdController.text.trim();
        if (trxId.isNotEmpty) {
          _transactionVerificationService.markTransactionUsed(trxId);
        }
      }

      // Fetch updated user details to get the to_verify list for the next screen
      final updatedDetails = await db.getUserDetails(currentUser.email!);
      final toVerifyOrders = updatedDetails?['to_verify'] as List<dynamic>?;

      if (mounted) {
        _showConfirmationDialog(toVerifyOrders);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Order failed: ${e.toString().split(':').last}"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showConfirmationDialog(List<dynamic>? toVerifyOrders) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Order Confirmed'),
            content: const Text(
              'Your order has been placed successfully!\n\nPlease wait until owner verify your payment information.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // First close the dialog
                  Navigator.pop(context);

                  // Then navigate: Home -> Profile -> OrderListScreen
                  // This ensures the back button behavior is correct
                  Navigator.popUntil(this.context, (route) => route.isFirst);

                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (context) => const Profile()),
                  );

                  Navigator.push(
                    this.context,
                    MaterialPageRoute(
                      builder:
                          (context) => OrderListScreen(
                            status: 'To Verify',
                            orders: toVerifyOrders,
                          ),
                    ),
                  );
                },
                child: const Text('OK'),
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
                  _calculateDeliveryCharge();
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
                    _calculateDeliveryCharge();
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
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Order Note (Optional)',
              prefixIcon: Icon(Icons.note_add),
              border: OutlineInputBorder(),
              hintText: 'Add instructions (e.g., color, preferred time)',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  bool get _canUseCoinDiscount => deliveryPoints >= 10;

  Widget _buildCoinDiscountButton() {
    if (_canUseCoinDiscount) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton(
          onPressed: _toggleCoinDiscount,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _coinDiscountSelected
                    ? AppColors.success
                    : Theme.of(context).primaryColor,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text(
            _coinDiscountSelected
                ? 'Dadu Coin Discount Applied! (-৳${_coinDiscountAmount.toStringAsFixed(2)})'
                : 'Use Dadu Coins for Discount (Balance: ${deliveryPoints.toStringAsFixed(0)} coins)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildFreeDeliveryButton() {
    if (_canUseFreeDelivery) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: ElevatedButton(
          onPressed: _toggleFreeDelivery,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _freeDeliverySelected
                    ? AppColors.success
                    : Theme.of(context).primaryColor,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text(
            _freeDeliverySelected
                ? 'Free Delivery Applied! Remaining Points: ${(deliveryPoints - _freeDeliveryCost).toStringAsFixed(2)}'
                : 'Use Free Delivery (Cost: ${_freeDeliveryCost.toStringAsFixed(0)} points)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnPrimary,
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
          'Transaction ID / Payment Verification (ট্রানজেকশন আইডি)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter Transaction ID manually, or upload a screenshot to auto-scan it.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _paymentProofImage != null
            ? Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_paymentProofImage!, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.error,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textOnPrimary,
                      ),
                      onPressed: _removePaymentProof,
                    ),
                  ),
                ),
                if (_isScanningProof)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Reading screenshot...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Extracting Transaction ID with ML Kit',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
            : GestureDetector(
                onTap: _pickPaymentProof,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.placeholderBackground,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.document_scanner_outlined,
                          color: AppColors.iconAccent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Auto-Scan Screenshot',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to pick image and auto-fill TrxID below',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _transactionIdController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Transaction ID / TrxID (ট্রানজেকশন আইডি)',
            hintText: 'e.g. BL489QZX87 or 72K83M9A',
            prefixIcon: const Icon(Icons.receipt_long),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isValidatingTrx)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_trxVerificationResult.isValid)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.check_circle, color: AppColors.success),
                  )
                else if (_trxVerificationResult.isAlreadyUsed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.cancel, color: AppColors.error),
                  )
                else if (_trxVerificationResult.isNotFound)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.error_outline, color: AppColors.warning),
                  ),
                if (_paymentProofImage != null)
                  IconButton(
                    icon: _isScanningProof
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.document_scanner_outlined),
                    tooltip: 'Re-scan Screenshot',
                    onPressed: _isScanningProof ? null : _rescanPaymentProof,
                  ),
              ],
            ),
            helperText: _trxAutoDetected
                ? '✓ Auto-extracted from screenshot. Edit if needed.'
                : 'Enter manually or auto-filled from screenshot.',
            helperStyle: TextStyle(
              color:
                  _trxAutoDetected
                      ? AppColors.success
                      : AppColors.textSecondary,
              fontWeight:
                  _trxAutoDetected ? FontWeight.bold : FontWeight.normal,
            ),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (!_freeDeliverySelected &&
                (_paymentMethod == 'bkash' ||
                    _paymentMethod == 'nagad' ||
                    _paymentMethod == 'rocket')) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter or scan the Transaction ID';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        _buildTransactionStatusWidget(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTransactionStatusWidget() {
    if (_isValidatingTrx) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Checking transaction status in database...',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    if (_trxVerificationResult.isValid) {
      final provider = _trxVerificationResult.provider?.toUpperCase() ?? 'MFS';
      final amount = _trxVerificationResult.amount != null
          ? '৳${_trxVerificationResult.amount!.toStringAsFixed(2)}'
          : null;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF81C784)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF2E7D32),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Transaction Verified',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          provider,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (amount != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          amount,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '✓ Available and not used before. You can proceed with order!',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_trxVerificationResult.isAlreadyUsed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE57373)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cancel,
              color: Color(0xFFC62828),
              size: 22,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Already Used (ব্যবহৃত হয়ে গেছে)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This Transaction ID has already been redeemed for another order. Please provide a new payment TrxID.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_trxVerificationResult.isNotFound) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFB74D)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE65100),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Not Found (ডাটাবেজে পাওয়া যায়নি)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBF360C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This Transaction ID was not found in our database. Please double check that you typed the correct TrxID and sent payment to our official number.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final text = _transactionIdController.text.trim();
                        if (text.isNotEmpty) {
                          _verifyTransactionId(text);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: Color(0xFFE65100)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.refresh,
                          size: 15, color: Color(0xFFE65100)),
                      label: const Text(
                        'Check Again',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFE65100)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_trxVerificationResult.isError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _trxVerificationResult.message,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () {
                final text = _transactionIdController.text.trim();
                if (text.isNotEmpty) {
                  _verifyTransactionId(text);
                }
              },
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  'Size: ${item.size}',
                  style: const TextStyle(color: AppColors.textSecondary),
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
              color:
                  isTotal
                      ? Theme.of(context).primaryColor
                      : AppColors.textPrimary,
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
            if (_coinDiscountSelected)
              _buildSummaryRow('Dadu Coin Discount', -_coinDiscountAmount),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery charge', style: TextStyle(fontSize: 14)),
                  Text(
                    _freeDeliverySelected
                        ? 'FREE (৳0.00)'
                        : '৳${deliveryCharge.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          _freeDeliverySelected
                              ? AppColors.success
                              : AppColors.textPrimary,
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

  Widget _buildUpdateBanner() {
    if (_versionCheckLoading || !needupdate) {
      return const SizedBox.shrink();
    }

    return Container(
      color: AppColors.updateBanner,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.update),
              SizedBox(width: 8),
              Text("Update required to place orders"),
            ],
          ),
          TextButton(onPressed: _openUpdateFlow, child: const Text("UPDATE")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
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
              'Delivery Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildShippingForm(),

            const SizedBox(height: 24),
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildOrderSummary(),
            const SizedBox(height: 32),
            _buildUpdateBanner(),

            _buildFreeDeliveryButton(),
            _buildCoinDiscountButton(),

            if (!_freeDeliverySelected) ...[
              const SizedBox(height: 24),
              ListTile(
                title: const Text(
                  "Send delivery charge to this number (এই নাম্বারে ডেলিভারি চার্জ পাঠান)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Row(
                  children: [
                    SelectableText(
                      _paymentNumberLoading
                          ? "Loading..."
                          : _getDisplayNumber(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed:
                          (_paymentNumberLoading ||
                                  _getDisplayNumber() == "Not available")
                              ? null
                              : () {
                                Clipboard.setData(
                                  ClipboardData(text: _getDisplayNumber()),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Number copied'),
                                  ),
                                );
                              },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                ' Send money By',
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

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    (_isProcessing || _versionCheckLoading || needupdate)
                        ? null
                        : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isProcessing
                        ? const CircularProgressIndicator(
                          color: AppColors.textOnPrimary,
                        )
                        : Text(
                          needupdate
                              ? 'UPDATE APP TO ORDER'
                              : _versionCheckLoading
                              ? 'CHECKING APP VERSION...'
                              : 'PLACE ORDER',
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
