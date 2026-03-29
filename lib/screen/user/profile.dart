import 'dart:async';
import 'dart:io';
import 'package:dadu/data/district_upozila.dart';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/screen/authentication/sign_up_2nd.dart';
import 'package:dadu/screen/product/home.dart';
import 'package:dadu/screen/user/reword_ad.dart';
import 'package:dadu/services/app_version_service.dart';
import 'package:dadu/services/auth.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/firebase.dart';
import '../authentication/sign_up_first.dart';
import 'order_list_screen.dart';

const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.sayedulmarsalin.dadu';

class Profile extends StatefulWidget {
  const Profile({super.key});
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String Name = '';
  String Phone = '';
  String Email = '';
  String District = '';
  String Thana = '';
  String Address = '';
  String profilePic = '';
  double freeDeliveryInfo = 0;
  List<dynamic>? toReceive = null;
  List<dynamic>? toShip = null;
  List<dynamic>? toVerify = null;
  List<dynamic>? Completed = null;
  int toReceiveCount = 0;
  int toShipCount = 0;
  int toVerifyCount = 0;
  int completedCount = 0;
  double freeDelivery = 0;

  final DistrictUpozila districtUpozila = DistrictUpozila();
  final Auth _auth = Auth();
  final ImageService imageService = ImageService();
  final dataBase db = new dataBase();

  bool _isLoading = true;
  String _error = '';
  bool _isUpdatingProfilePic = false;
  bool _isRedirecting = false;
  bool _rewardAdUpdateRequired = false;
  bool _rewardAdVersionLoading = true;
  StreamSubscription<String?>? _versionSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _listenForVersionUpdates();
  }

  void _listenForVersionUpdates() {
    _versionSubscription = db.getVersionStream().listen(
      (remoteVersion) async {
        final requiresUpdate = remoteVersion != null &&
            await AppVersionService.isUpdateRequired(remoteVersion);

        if (!mounted) return;

        setState(() {
          _rewardAdUpdateRequired = requiresUpdate;
          _rewardAdVersionLoading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _rewardAdUpdateRequired = false;
          _rewardAdVersionLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _versionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        await _redirectToAuth(SignUpScreen(), showNoAccountMessage: true);
        return;
      }

      if (currentUser.isAnonymous) {
        await _redirectToAuth(SignUpScreen());
        return;
      }
      Map<String, dynamic>? userDetails = await db.getUserDetails(
        currentUser.email.toString(),
      );

      Address = userDetails?['address'] ?? '';
      if (Address.isEmpty || Address == '') {
        await _redirectToAuth(SignUpScreen2());
        return;
      }

      if (mounted) {
        setState(() {
          Name = userDetails?['name'] ?? '';
          Email = userDetails?['email'] ?? '';
          District = userDetails?['district'] ?? '';
          Thana = userDetails?['thana'] ?? '';
          Phone = userDetails?['phone'] ?? '';
          profilePic = userDetails?['profile_pic'] ?? '';
          freeDeliveryInfo =
              (userDetails?["free_delivery_info"] as num?)?.toDouble() ?? 0.0;
          toReceive = userDetails?["to_receive"];
          toShip = userDetails?["to_ship"];
          toVerify = userDetails?["to_verify"];
          Completed = userDetails?["completed"];
          toReceiveCount = userDetails?["to_receive_count"] ?? 0;
          toShipCount = userDetails?["to_ship_count"] ?? 0;
          toVerifyCount = userDetails?["to_verify_count"] ?? 0;
          completedCount = userDetails?["completed_count"] ?? 0;
          _isLoading = false;
          freeDelivery = (freeDeliveryInfo / 130);
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load profile: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _redirectToAuth(
    Widget page, {
    bool showNoAccountMessage = false,
  }) async {
    if (!mounted || _isRedirecting) return;
    _isRedirecting = true;

    if (showNoAccountMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have an account please create one'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    if (mounted) {
      _isRedirecting = false;
    }
  }

  Future<String?> _updateProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return null;

      File imageFile = File(pickedFile.path);
      return await imageService.uploadProfileImage(imageFile);
    } catch (e) {
      print("Error updating profile picture: $e");
      return null;
    }
  }

  void _showEditProfileDialog() {
    final BuildContext mainContext = context;
    String tempName = Name;
    String tempPhone = Phone;
    String tempProfilePic = profilePic;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool _isSaving = false;

            return AlertDialog(
              title: const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        setDialogState(() => _isUpdatingProfilePic = true);
                        final newUrl = await _updateProfilePicture();
                        setDialogState(() {
                          _isUpdatingProfilePic = false;
                          if (newUrl != null) {
                            tempProfilePic = newUrl;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.surfaceGrey,
                                  backgroundImage: tempProfilePic.isNotEmpty
                                      ? NetworkImage(tempProfilePic)
                                      : null,
                                  child: tempProfilePic.isEmpty
                                      ? const Icon(Icons.person, size: 50)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () async {
                                setDialogState(
                                  () => _isUpdatingProfilePic = true,
                                );
                                final newUrl = await _updateProfilePicture();
                                setDialogState(() {
                                  _isUpdatingProfilePic = false;
                                  if (newUrl != null) {
                                    tempProfilePic = newUrl;
                                  }
                                });
                              },
                              child: const Text(
                                'Change Profile Picture',
                                style: TextStyle(color: AppColors.textLink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: tempName,
                      onChanged: (value) => tempName = value,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: tempPhone,
                      onChanged: (value) => tempPhone = value,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: Email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email (cannot be changed)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setDialogState(() => _isSaving = true);

                          try {
                            Map<String, dynamic> updatedData = {
                              'name': tempName,
                              'phone': tempPhone,
                              'profile_pic': tempProfilePic,
                            };

                            bool success = await db.updateUserDetails(
                              Email,
                              updatedData,
                            );

                            if (success) {
                              setState(() {
                                Name = tempName;
                                Phone = tempPhone;
                                profilePic = tempProfilePic;
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(mainContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Profile updated successfully',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              throw Exception('Failed to update Firestore');
                            }
                          } catch (e) {
                            setDialogState(() => _isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error saving data: $e"),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.profileAccent,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.textOnPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SAVE',
                          style: TextStyle(color: AppColors.textOnPrimary),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditAddressDialog() {
    final BuildContext mainContext = context;
    String tempDistrict = District;
    String tempThana = Thana;
    String tempAddress = Address;
    List<String> thanaList =
        districtUpozila.districtToThanas[tempDistrict] ?? [];

    if (!thanaList.contains(tempThana)) {
      if (thanaList.isNotEmpty) {
        tempThana = thanaList.first;
      } else {
        tempThana = '';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool _isSaving = false;

            return AlertDialog(
              title: const Text(
                'Edit Address',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tempDistrict,
                      items:
                          districtUpozila.districtToThanas.keys.map((district) {
                        return DropdownMenuItem(
                          value: district,
                          child: Text(district),
                        );
                      }).toList(),
                      onChanged: (newDistrict) {
                        if (newDistrict != null) {
                          setDialogState(() {
                            tempDistrict = newDistrict;
                            thanaList =
                                districtUpozila.districtToThanas[newDistrict] ??
                                    [];
                            tempThana =
                                thanaList.isNotEmpty ? thanaList.first : '';
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'District',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: thanaList.isNotEmpty ? tempThana : null,
                      items: thanaList.map((thana) {
                        return DropdownMenuItem(
                          value: thana,
                          child: Text(thana),
                        );
                      }).toList(),
                      onChanged: thanaList.isNotEmpty
                          ? (newThana) {
                              if (newThana != null) {
                                setDialogState(() {
                                  tempThana = newThana;
                                });
                              }
                            }
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Thana/Upazila',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      disabledHint: const Text('No thanas available'),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: tempAddress,
                      onChanged: (value) => tempAddress = value,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Full Address',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setDialogState(() => _isSaving = true);

                          try {
                            Map<String, dynamic> updatedData = {
                              'district': tempDistrict,
                              'thana': tempThana,
                              'address': tempAddress,
                            };

                            bool success = await db.updateUserDetails(
                              Email,
                              updatedData,
                            );

                            if (success) {
                              setState(() {
                                District = tempDistrict;
                                Thana = tempThana;
                                Address = tempAddress;
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(mainContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Address updated successfully',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              throw Exception('Failed to update Firestore');
                            }
                          } catch (e) {
                            setDialogState(() => _isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error saving address: $e"),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.profileAccent,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.textOnPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SAVE',
                          style: TextStyle(color: AppColors.textOnPrimary),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFullScreenProfilePicture() {
    if (profilePic.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(profilePic, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _changePassword() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    bool _isChangingPassword = false;
    String? _errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      _isChangingPassword ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isChangingPassword
                      ? null
                      : () async {
                          setDialogState(() => _isChangingPassword = true);

                          final currentPassword =
                              currentPasswordController.text;
                          final newPassword = newPasswordController.text;
                          final confirmPassword =
                              confirmPasswordController.text;

                          if (currentPassword.isEmpty ||
                              newPassword.isEmpty ||
                              confirmPassword.isEmpty) {
                            setDialogState(() {
                              _errorMessage = 'All fields are required';
                              _isChangingPassword = false;
                            });
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            setDialogState(() {
                              _errorMessage = 'New passwords do not match';
                              _isChangingPassword = false;
                            });
                            return;
                          }

                          if (newPassword.length < 6) {
                            setDialogState(() {
                              _errorMessage =
                                  'Password must be at least 6 characters';
                              _isChangingPassword = false;
                            });
                            return;
                          }

                          try {
                            final result = await _auth.changePassword(
                              currentPassword,
                              newPassword,
                            );

                            if (result == null) {
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password changed successfully',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                _errorMessage = result;
                                _isChangingPassword = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              _errorMessage = 'Password change failed: $e';
                              _isChangingPassword = false;
                            });
                          }
                        },
                  child: _isChangingPassword
                      ? const CircularProgressIndicator()
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            'My Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text(
            'My Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadProfileData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildOrderSection(),
            const SizedBox(height: 24),
            _buildAddressSection(),
            const SizedBox(height: 24),
            _buildLoyaltySection(),
            const SizedBox(height: 24),
            _buildSettingsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            if (!_isUpdatingProfilePic) {
              _showFullScreenProfilePicture();
            }
          },
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.surfaceGrey,
                backgroundImage:
                    profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                child: profilePic.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              if (_isUpdatingProfilePic)
                const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Email,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                Phone,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: _showEditProfileDialog,
        ),
      ],
    );
  }

  Widget _buildOrderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Orders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _navigateToOrderPage(context, 'To Verify', toVerify),
              child: _buildOrderStatus(
                'To Verify',
                Icons.verified_outlined,
                toVerifyCount,
              ),
            ),
            GestureDetector(
              onTap: () => _navigateToOrderPage(context, 'To Ship', toShip),
              child: _buildOrderStatus(
                'To Ship',
                Icons.local_shipping,
                toShipCount,
              ),
            ),
            GestureDetector(
              onTap: () =>
                  _navigateToOrderPage(context, 'To Receive', toReceive),
              child: _buildOrderStatus(
                'To Receive',
                Icons.shopping_bag,
                toReceiveCount,
              ),
            ),
            GestureDetector(
              onTap: () =>
                  _navigateToOrderPage(context, 'Completed', Completed),
              child: _buildOrderStatus(
                'Completed',
                Icons.check_circle,
                completedCount,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _navigateToOrderPage(
    BuildContext context,
    String status,
    List<dynamic>? orders,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderListScreen(status: status, orders: orders),
      ),
    );
  }

  Widget _buildOrderStatus(String title, IconData icon, int count) {
    return Column(
      children: [
        Stack(
          children: [
            Icon(icon, size: 28, color: AppColors.profileAccent),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saved Addresses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.textSecondary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.home, size: 20, color: AppColors.iconAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Home',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(color: AppColors.success, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAddressRow('District : ', District),
              const SizedBox(height: 8),
              _buildAddressRow('Thana/Upazila : ', Thana),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Address : ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      Address,
                      style: const TextStyle(height: 1.5, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _showEditAddressDialog,
                    icon: const Icon(
                      Icons.edit,
                      size: 18,
                      color: AppColors.iconAccent,
                    ),
                    label: const Text(
                      'Edit Address',
                      style: TextStyle(color: AppColors.textLink),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  ButtonStyle _buildLoyaltyButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.textOnPrimary,
      foregroundColor: AppColors.profileAccent,
    );
  }

  Widget _buildRewardAdAction() {
    if (_rewardAdVersionLoading) {
      return const Text(
        'Checking reward access...',
        style: TextStyle(color: AppColors.textOnPrimary, fontSize: 12),
      );
    }

    if (_rewardAdUpdateRequired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update the app to keep earning coins from ads.',
            style: TextStyle(color: AppColors.textOnPrimary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _launchUrl(_playStoreUrl),
            style: _buildLoyaltyButtonStyle(),
            child: const Text('Update App'),
          ),
        ],
      );
    }

    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RewordAd()),
        );
      },
      style: _buildLoyaltyButtonStyle(),
      child: const Text('Watch Ad to earn more coins'),
    );
  }

  Widget _buildLoyaltySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.loyaltyGradientStart,
            AppColors.loyaltyGradientEnd,
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_membership,
            color: AppColors.textOnPrimary,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium Member',
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: freeDelivery,
                  backgroundColor: AppColors.textOnPrimary.withOpacity(0.3),
                  color: AppColors.coinGold,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Text(
                  freeDeliveryInfo >= 130
                      ? 'You can have free delivery! you have: $freeDeliveryInfo coins '
                      : '${(130 - freeDeliveryInfo).toStringAsFixed(2)} coins need to get next free delivery',
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRewardAdAction(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    final List<Map<String, dynamic>> accountSettings = [
      {'icon': Icons.password, 'title': 'Change password'},
      {'icon': Icons.help_outline, 'title': 'Help Center'},
    ];

    final List<Map<String, dynamic>> legalSettings = [
      {'icon': Icons.privacy_tip, 'title': 'Privacy Policy'},
      {'icon': Icons.description, 'title': 'Terms & Conditions'},
      {'icon': Icons.person_outline, 'title': 'Developer Info'},
    ];

    final List<Map<String, dynamic>> dangerSettings = [
      {
        'icon': Icons.delete_forever,
        'title': 'Delete Account',
        'color': AppColors.error,
      },
      {'icon': Icons.logout, 'title': 'Logout', 'color': AppColors.error},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...accountSettings.map((item) => _buildSettingTile(item)),
        const SizedBox(height: 20),
        const Text(
          'Legal',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const Divider(),
        ...legalSettings.map((item) => _buildSettingTile(item)),
        const SizedBox(height: 20),
        const Text(
          'Danger Zone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        ),
        const Divider(),
        ...dangerSettings.map((item) => _buildSettingTile(item)),
      ],
    );
  }

  Widget _buildSettingTile(Map<String, dynamic> item) {
    final Color? customColor = item['color'];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item['icon'],
        color: customColor ?? AppColors.profileAccent,
      ),
      title: Text(
        item['title'],
        style: TextStyle(
          color: customColor ?? AppColors.textPrimary,
          fontWeight: customColor != null ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _handleSettingsTap(item['title']),
    );
  }

  void _handleSettingsTap(String title) {
    switch (title) {
      case 'Change password':
        _changePassword();
        break;

      case 'Help Center':
        _showHelpCenter();
        break;

      case 'Privacy Policy':
        _launchUrl(
          "https://sites.google.com/view/dadu-app/privacy-policy-page",
        );
        break;

      case 'Terms & Conditions':
        _launchUrl("https://sites.google.com/view/dadu-app/terms-conditions");
        break;

      case 'Delete Account':
        _deleteAccount();
        break;

      case 'Logout':
        _logout();
        break;
      case 'Developer Info':
        _showDeveloperInfo();
        break;
    }
  }

  void _showDeveloperInfo() {
    const String phoneDisplay = "+880 1775-876544";
    const String phoneRaw = "+8801775876544";
    const String email = "sayadulmorsalin123@gmail.com";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Developer Information"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "App Name : DADU",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Developer : Md. Sayedul Marsalin"),
              const SizedBox(height: 14),
              const Text(
                "Phone",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(child: Text(phoneDisplay)),
                  IconButton(
                    tooltip: "Copy",
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: phoneRaw));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Phone copied"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: "Call",
                    icon: const Icon(Icons.call, color: AppColors.iconSuccess),
                    onPressed: () async {
                      final Uri uri = Uri.parse("tel:$phoneRaw");

                      await launchUrl(uri);
                    },
                  ),
                  IconButton(
                    tooltip: "WhatsApp",
                    icon: const Icon(Icons.chat, color: AppColors.iconSuccess),
                    onPressed: () async {
                      final Uri uri = Uri.parse(
                        "https://wa.me/${phoneRaw.replaceAll('+', '')}",
                      );

                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Email",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Expanded(child: Text(email)),
                  IconButton(
                    tooltip: "Copy",
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: email));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Email copied"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: "Send Email",
                    icon: const Icon(Icons.email, color: AppColors.iconAccent),
                    onPressed: () async {
                      final Uri uri = Uri.parse("mailto:$email");

                      await launchUrl(uri);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _showHelpCenter() {
    final List<Map<String, dynamic>> helpItems = [
      {
        'title': 'How to place an order?',
        'icon': Icons.shopping_cart,
        'url':
            'https://sites.google.com/view/dadu-help-center/home/how-to-place-order',
      },
      {
        'title': 'Payment methods',
        'icon': Icons.payment,
        'url':
            'https://sites.google.com/view/dadu-help-center/home/payment-methods',
      },
      {
        'title': 'Delivery information',
        'icon': Icons.local_shipping,
        'url':
            'https://sites.google.com/view/dadu-help-center/home/delivery-information',
      },
      {
        'title': 'Return policy',
        'icon': Icons.assignment_return,
        'url':
            'https://sites.google.com/view/dadu-help-center/home/return-policy',
      },
      {
        'title': 'Contact support',
        'icon': Icons.support_agent,
        'url':
            'https://sites.google.com/view/dadu-help-center/home/contact-support',
      },
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Help Center')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: helpItems
                .map(
                  (item) => _buildHelpItem(
                    item['title'] as String,
                    item['icon'] as IconData,
                    item['url'] as String,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, IconData icon, String url) {
    return ListTile(
      leading: Icon(icon, color: AppColors.iconAccent),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _launchUrl(url),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  void _deleteAccount() {
    bool isDeleting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action will permanently delete your account and cannot be undone.',
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                            errorMessage = null;
                          });

                          try {
                            final result = await _auth.deleteAccount();

                            if (result == null) {
                              if (!mounted) return;
                              Navigator.pop(dialogContext);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Home(),
                                ),
                                (route) => false,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Account deleted successfully',
                                  ),
                                ),
                              );
                            } else {
                              setDialogState(() {
                                errorMessage = result;
                                isDeleting = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorMessage = 'Account deletion failed: $e';
                              isDeleting = false;
                            });
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _auth.signOut();
                if (Get.isRegistered<HomeController>()) {
                  Get.find<HomeController>().resetToHomeTab();
                }

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                  (route) => false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Logout failed: $e")),
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
