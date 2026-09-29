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
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _CheckOutState extends State<CheckOut>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final dataBase db = new dataBase();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _refundPhoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final GlobalKey _refundSectionKey = GlobalKey();
  late AnimationController _proofBlinkController;
  late Animation<double> _proofBlinkAnimation;
  final GlobalKey _proofSectionKey = GlobalKey();
  final TextEditingController _transactionIdController =
      TextEditingController();
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
  bool _hasPendingOrder = false;

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
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _proofBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _proofBlinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _proofBlinkController, curve: Curves.easeInOut),
    );
    _transactionIdController.addListener(_onTransactionIdChanged);
    _calculateDeliveryCharge();
    _loadUserAddress();
    _loadPaymentNumber();
    _refreshVersionRequirement();
    _checkPendingOrderStatus();
  }

  Future<void> _checkPendingOrderStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser?.email != null) {
        final hasPending = await db.hasPendingOrder(currentUser!.email!);
        if (mounted) {
          setState(() {
            _hasPendingOrder = hasPending;
          });
        }
      }
    } catch (_) {}
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
        final extractedTrx = await TransactionIdExtractor.extractTransactionId(
          image.path,
        );
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
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.textOnPrimary,
                  ),
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
      final extractedTrx = await TransactionIdExtractor.extractTransactionId(
        _paymentProofImage!.path,
      );
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
                Expanded(child: Text('Transaction ID detected: $extractedTrx')),
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
    double baseFee =
        (maxSingleFee > minimumCharge)
            ? maxSingleFee
            : minimumCharge.toDouble();
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

  void _scrollToAndHighlightRefund() {
    if (_refundSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _refundSectionKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }

    _blinkController.reset();
    _blinkController.repeat(
      reverse: true,
      period: const Duration(milliseconds: 300),
    );

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _blinkController.stop();
        _blinkController.reset();
      }
    });
  }

  void _scrollToAndHighlightProof() {
    if (_proofSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _proofSectionKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }

    _proofBlinkController.reset();
    _proofBlinkController.repeat(
      reverse: true,
      period: const Duration(milliseconds: 300),
    );

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _proofBlinkController.stop();
        _proofBlinkController.reset();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blinkController.dispose();
    _proofBlinkController.dispose();
    _trxDebounceTimer?.cancel();
    _transactionIdController.removeListener(_onTransactionIdChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _refundPhoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (_refundPhoneController.text.trim().isEmpty) {
      _scrollToAndHighlightRefund();
      _formKey.currentState!.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      if (_refundPhoneController.text.trim().length != 11) {
        _scrollToAndHighlightRefund();
      }
      return;
    }

    if (!_freeDeliverySelected &&
        (_paymentMethod == 'bkash' ||
            _paymentMethod == 'nagad' ||
            _paymentMethod == 'rocket')) {
      if (_paymentProofImage == null) {
        _scrollToAndHighlightProof();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please upload the transaction screenshot (পেমেন্ট প্রুফের স্ক্রিনশট আপলোড করুন)',
            ),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final trxId = _transactionIdController.text.trim();
      if (trxId.isEmpty) {
        _scrollToAndHighlightProof();
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

    final currentUserForCheck = _auth.currentUser;
    if (currentUserForCheck?.email != null) {
      final hasPending = await db.hasPendingOrder(currentUserForCheck!.email!);
      if (hasPending) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Order In Progress'),
                  content: const Text(
                    'You currently have an active order in progress (Preparing, Shipping, or To Receive).\n\nYou cannot place a new order until your current order is delivered.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception("User not authenticated");
      }

      if (_paymentProofImage != null) {
        paymentProof = await _imageService.uploadPaymentImage(
          _paymentProofImage!,
        );
      }
      final double usedPoints =
          (_freeDeliverySelected ? _freeDeliveryCost : 0.0) +
          (_coinDiscountSelected ? _coinDiscountAmount : 0.0);

      final double remainingDeliveryPoints =
          (deliveryPoints - usedPoints).clamp(0.0, double.infinity).toDouble();

      final userUpdateData = {
        "to_verify": FieldValue.arrayUnion([
          {
            'order_id': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
            'customerName': _nameController.text,
            'customerEmail': currentUser.email,
            'phone': _phoneController.text,
            'refundPhone': _refundPhoneController.text.trim(),
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
            'totalFreeCoins': widget.cartItems.fold(
              0.0,
              (sum, item) => sum + (item.freeCoin * item.quantity),
            ),
            'order_status': "preparing",
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
              'Your order has been placed successfully!\n\nYour order is now preparing.',
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
                            status: 'Preparing',
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

  InputDecoration _modernInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 22),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
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
            decoration: _modernInputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icons.person_outline_rounded,
              hintText: 'Enter your full name',
            ),
            validator:
                (value) =>
                    value == null || value.isEmpty
                        ? 'Please enter your name'
                        : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: _modernInputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icons.phone_outlined,
              hintText: 'e.g. 01700000000',
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
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _blinkAnimation,
            builder: (context, child) {
              final blinkVal = _blinkAnimation.value;
              final borderColor =
                  Color.lerp(
                    Colors.amber.shade700,
                    Colors.red.shade600,
                    blinkVal,
                  )!;
              final bgColor =
                  Color.lerp(
                    Colors.amber.shade50.withValues(alpha: 0.9),
                    Colors.red.shade50,
                    blinkVal,
                  )!;

              return Container(
                key: _refundSectionKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: 2.0 + (blinkVal * 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (blinkVal > 0 ? Colors.red : Colors.amber)
                          .withValues(alpha: 0.15 + (blinkVal * 0.2)),
                      blurRadius: 8 + (blinkVal * 4),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              Colors.amber.shade700,
                              Colors.red.shade700,
                              blinkVal,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.currency_exchange_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'IMPORTANT: REFUND NUMBER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color.lerp(
                              Colors.amber.shade900,
                              Colors.red.shade900,
                              blinkVal,
                            ),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              Colors.amber.shade700,
                              Colors.red.shade700,
                              blinkVal,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'টাকা ফেরত নম্বর',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _refundPhoneController,
                      decoration: InputDecoration(
                        labelText: 'Refund Number (টাকা ফেরতের নম্বর)',
                        hintText: 'e.g. 01700000000',
                        prefixIcon: Icon(
                          Icons.phone_android_rounded,
                          color: Color.lerp(
                            Colors.amber.shade900,
                            Colors.red.shade900,
                            blinkVal,
                          ),
                          size: 22,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: Color.lerp(
                            Colors.amber.shade900,
                            Colors.red.shade900,
                            blinkVal,
                          ),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                Color.lerp(
                                  Colors.amber.shade400,
                                  Colors.red.shade400,
                                  blinkVal,
                                )!,
                            width: 1.5 + blinkVal,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.amber.shade800,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.error,
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter refund number (রিফান্ড নম্বর দিন)';
                        }
                        if (value.trim().length != 11) {
                          return "Please enter a valid 11-digit number";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Color.lerp(
                              Colors.amber.shade900,
                              Colors.red.shade900,
                              blinkVal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'পণ্য স্টকে না থাকলে এই নম্বরে সরাসরি টাকা ফেরত দেওয়া হবে।',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color.lerp(
                                  Colors.amber.shade900,
                                  Colors.red.shade900,
                                  blinkVal,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedDistrict,
            decoration: _modernInputDecoration(
              labelText: 'District',
              prefixIcon: Icons.location_city_outlined,
              hintText: 'Select your district',
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
          if (thanaList.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedThana,
              decoration: _modernInputDecoration(
                labelText: 'Thana / Upozila',
                prefixIcon: Icons.location_on_outlined,
                hintText: 'Select your thana',
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
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
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: _modernInputDecoration(
              labelText: 'Address',
              prefixIcon: Icons.home_outlined,
              hintText: 'House no., street, area details',
            ),
            validator:
                (value) =>
                    value == null || value.isEmpty
                        ? 'Please enter your address'
                        : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: _modernInputDecoration(
              labelText: 'Order Note (Optional)',
              prefixIcon: Icons.edit_note_rounded,
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
    if (!_canUseCoinDiscount) return const SizedBox.shrink();

    final bool selected = _coinDiscountSelected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient:
              selected
                  ? const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                  : const LinearGradient(
                    colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.amber.shade700,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? Colors.green : Colors.amber).withValues(
                alpha: 0.2,
              ),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleCoinDiscount,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.amber.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.monetization_on_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected
                              ? 'Dadu Coin Discount Applied!'
                              : 'Use Dadu Coins for Discount',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color:
                                selected ? Colors.white : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected
                              ? '-৳${_coinDiscountAmount.toStringAsFixed(2)} savings'
                              : 'Balance: ${deliveryPoints.toStringAsFixed(0)} coins',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                selected
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.brown.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.amber.shade800.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.done_all_rounded
                          : Icons.add_circle_outline_rounded,
                      color: selected ? Colors.white : Colors.amber.shade900,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreeDeliveryButton() {
    if (!_canUseFreeDelivery) return const SizedBox.shrink();

    final bool selected = _freeDeliverySelected;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient:
              selected
                  ? const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                  : const LinearGradient(
                    colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.green.shade700,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleFreeDelivery,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.green.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.verified_rounded
                          : Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected
                              ? 'Free Delivery Applied!'
                              : 'Use Free Delivery',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color:
                                selected ? Colors.white : Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected
                              ? 'Remaining Points: ${(deliveryPoints - _freeDeliveryCost).toStringAsFixed(2)}'
                              : 'Cost: ${_freeDeliveryCost.toStringAsFixed(0)} points',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                selected
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.green.shade800.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.done_all_rounded
                          : Icons.add_circle_outline_rounded,
                      color: selected ? Colors.white : Colors.green.shade900,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    final methods = [
      {
        'id': 'bkash',
        'name': 'bKash',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFFE2136E),
      },
      {
        'id': 'nagad',
        'name': 'Nagad',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFFF7921E),
      },
      {
        'id': 'rocket',
        'name': 'Rocket',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF8C3494),
      },
    ];

    return Row(
      children:
          methods.map((method) {
            final bool isSelected = _paymentMethod == method['id'];
            final Color brandColor = method['color'] as Color;

            return Expanded(
              child: GestureDetector(
                onTap:
                    () =>
                        setState(() => _paymentMethod = method['id'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? brandColor.withValues(alpha: 0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? brandColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: brandColor.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                            : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : (method['icon'] as IconData),
                        color: isSelected ? brandColor : Colors.grey.shade600,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        method['name'] as String,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? brandColor : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Color _getPaymentBrandColor([String? method]) {
    final m = method ?? _paymentMethod;
    switch (m) {
      case 'bkash':
        return const Color(0xFFE2136E);
      case 'nagad':
        return const Color(0xFFF7921E);
      case 'rocket':
        return const Color(0xFF8C3494);
      default:
        return AppColors.primary;
    }
  }

  LinearGradient _getPaymentBrandGradient([String? method]) {
    final m = method ?? _paymentMethod;
    switch (m) {
      case 'bkash':
        return const LinearGradient(
          colors: [Color(0xFFE2136E), Color(0xFFC2185B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case 'nagad':
        return const LinearGradient(
          colors: [Color(0xFFF7921E), Color(0xFFE65100)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case 'rocket':
        return const LinearGradient(
          colors: [Color(0xFF8C3494), Color(0xFF6A1B9A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }

  String _getPaymentBrandName([String? method]) {
    final m = method ?? _paymentMethod;
    switch (m) {
      case 'bkash':
        return 'bKash';
      case 'nagad':
        return 'Nagad';
      case 'rocket':
        return 'Rocket';
      default:
        return 'Payment';
    }
  }

  String _getPaymentBrandBengaliName([String? method]) {
    final m = method ?? _paymentMethod;
    switch (m) {
      case 'bkash':
        return 'বিকাশ';
      case 'nagad':
        return 'নগদ';
      case 'rocket':
        return 'রকেট';
      default:
        return '';
    }
  }

  Future<void> _openPaymentApp() async {
    final String paymentNumber = _getDisplayNumber();
    if (paymentNumber.isNotEmpty && paymentNumber != "Not available") {
      await Clipboard.setData(ClipboardData(text: paymentNumber));
    }

    String androidPackage = '';
    String iosScheme = '';
    String appStoreLink = '';
    final String appName = _getPaymentBrandName();
    final String bengaliName = _getPaymentBrandBengaliName();

    switch (_paymentMethod) {
      case 'bkash':
        androidPackage = 'com.bKash.customerapp';
        iosScheme = 'bkash://';
        appStoreLink = 'https://apps.apple.com/app/bkash/id1435012987';
        break;
      case 'nagad':
        androidPackage = 'com.konasl.nagad';
        iosScheme = 'nagad://';
        appStoreLink = 'https://apps.apple.com/app/nagad/id1471844877';
        break;
      case 'rocket':
        androidPackage = 'com.dbbl.mbs.apps.main';
        iosScheme = 'dbblrocket://';
        appStoreLink = 'https://apps.apple.com/app/rocket/id1006574971';
        break;
      default:
        return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  paymentNumber.isNotEmpty && paymentNumber != "Not available"
                      ? '$bengaliName নম্বর ($paymentNumber) কপি হয়েছে! $appName অ্যাপ খোলা হচ্ছে...'
                      : '$appName অ্যাপ খোলা হচ্ছে...',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _getPaymentBrandColor(),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    try {
      if (Platform.isAndroid) {
        await LaunchApp.openApp(
          androidPackageName: androidPackage,
          openStore: true,
        );
      } else if (Platform.isIOS) {
        await LaunchApp.openApp(
          iosUrlScheme: iosScheme,
          appStoreLink: appStoreLink,
          openStore: true,
        );
      } else {
        final uri = Uri.parse(
          'https://play.google.com/store/apps/details?id=$androidPackage',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // Fallback with url_launcher
      try {
        final Uri storeUri = Uri.parse(
          Platform.isIOS
              ? appStoreLink
              : 'https://play.google.com/store/apps/details?id=$androidPackage',
        );
        if (await canLaunchUrl(storeUri)) {
          await launchUrl(storeUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$appName অ্যাপটি ওপেন করা সম্ভব হয়নি।'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildPayNowButton() {
    final String brandName = _getPaymentBrandName();
    final String bengaliName = _getPaymentBrandBengaliName();
    final Color brandColor = _getPaymentBrandColor();
    final LinearGradient brandGradient = _getPaymentBrandGradient();

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: brandGradient,
              boxShadow: [
                BoxShadow(
                  color: brandColor.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openPaymentApp,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Pay Now with $brandName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'OPEN APP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'নম্বর অটো কপি হবে এবং $bengaliName অ্যাপ ওপেন হবে',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: brandColor,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: brandColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: brandColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'পেমেন্ট করার পর ট্রানজেকশন আইডি (TrxID) বা স্ক্রিনশট নিচে দিন।',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: brandColor,
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
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close,
                        size: 18,
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
                          CircularProgressIndicator(color: Colors.white),
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
            : AnimatedBuilder(
              animation: _proofBlinkAnimation,
              builder: (context, child) {
                final blinkVal = _proofBlinkAnimation.value;
                final borderColor =
                    Color.lerp(
                      AppColors.textSecondary.withValues(alpha: 0.2),
                      Colors.red.shade600,
                      blinkVal,
                    )!;
                final bgColor =
                    Color.lerp(
                      AppColors.surfaceGrey,
                      Colors.red.shade50,
                      blinkVal,
                    )!;

                return InkWell(
                  key: _proofSectionKey,
                  onTap: _pickPaymentProof,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: borderColor,
                        width: 1.5 + (blinkVal * 1.5),
                      ),
                      boxShadow:
                          blinkVal > 0
                              ? [
                                BoxShadow(
                                  color: Colors.red.withValues(
                                    alpha: 0.25 * blinkVal,
                                  ),
                                  blurRadius: 10 * blinkVal,
                                  spreadRadius: 1 * blinkVal,
                                ),
                              ]
                              : null,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              AppColors.placeholderBackground,
                              Colors.red.shade100,
                              blinkVal,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.document_scanner_outlined,
                            color: Color.lerp(
                              AppColors.iconAccent,
                              Colors.red.shade700,
                              blinkVal,
                            ),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Upload Screenshot (পেমেন্ট স্ক্রিনশট আপলোড করুন)',
                          style: TextStyle(
                            color: Color.lerp(
                              AppColors.textPrimary,
                              Colors.red.shade900,
                              blinkVal,
                            ),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          blinkVal > 0
                              ? '⚠️ Please upload transaction screenshot'
                              : 'Tap to pick image and auto-fill TrxID below',
                          style: TextStyle(
                            color: Color.lerp(
                              AppColors.textSecondary,
                              Colors.red.shade700,
                              blinkVal,
                            ),
                            fontSize: 13,
                            fontWeight:
                                blinkVal > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                    icon:
                        _isScanningProof
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
            helperText:
                _trxAutoDetected
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
      final amount =
          _trxVerificationResult.amount != null
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
            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 22),
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
                          horizontal: 6,
                          vertical: 2,
                        ),
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
            Icon(Icons.cancel, color: Color(0xFFC62828), size: 22),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(
                        Icons.refresh,
                        size: 15,
                        color: Color(0xFFE65100),
                      ),
                      label: const Text(
                        'Check Again',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                        ),
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

  Widget _buildPendingOrderBanner() {
    if (!_hasPendingOrder) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have an active order in progress (Preparing / Shipping / To Receive). You cannot place a new order until your current order is delivered.',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
            _buildPendingOrderBanner(),
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
                    const SizedBox(width: 8),
                    InkWell(
                      onTap:
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
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
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
              _buildPayNowButton(),
              if (!_freeDeliverySelected &&
                  (_paymentMethod == 'bkash' ||
                      _paymentMethod == 'nagad' ||
                      _paymentMethod == 'rocket'))
                _buildPaymentProofSection(),
            ],

            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final bool isDisabled =
                    _isProcessing ||
                    _versionCheckLoading ||
                    needupdate ||
                    _hasPendingOrder;
                final String buttonText =
                    needupdate
                        ? 'UPDATE APP TO ORDER'
                        : _hasPendingOrder
                        ? 'ORDER IN PROGRESS'
                        : _versionCheckLoading
                        ? 'CHECKING APP VERSION...'
                        : 'PLACE ORDER';

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient:
                        isDisabled
                            ? null
                            : const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                    color: isDisabled ? Colors.grey.shade300 : null,
                    boxShadow:
                        isDisabled
                            ? []
                            : [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isDisabled ? null : _submitOrder,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child:
                            _isProcessing
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.textOnPrimary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      needupdate
                                          ? Icons.system_update_rounded
                                          : Icons.shopping_bag_outlined,
                                      color:
                                          isDisabled
                                              ? Colors.grey.shade600
                                              : AppColors.textOnPrimary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      buttonText,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color:
                                            isDisabled
                                                ? Colors.grey.shade600
                                                : AppColors.textOnPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
