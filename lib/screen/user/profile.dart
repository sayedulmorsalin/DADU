import 'dart:io';
import 'package:dadu/data/district_upozila.dart';
import 'package:dadu/screen/authentication/sign_up_2nd.dart';
import 'package:dadu/screen/product/home.dart';
import 'package:dadu/services/auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/firebase.dart';
import '../authentication/sign_up_first.dart';
import 'order_list_screen.dart';

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
  int freeDeliveryInfo = 0;
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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have an account please create one'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SignUpScreen()),
          );
        }
        return;
      }

      if (currentUser.isAnonymous) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have an account please create one'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SignUpScreen()),
          );
        }
        return;
      }
      Map<String, dynamic>? userDetails = await db.getUserDetails(
        currentUser.email.toString(),
      );

      // Check if address exists
      Address = userDetails?['address'] ?? '';
      if (Address.isEmpty || Address == '') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SignUpScreen2()),
          );
        }
        return;
      }

      // Update all profile data
      if (mounted) {
        setState(() {
          Name = userDetails?['name'] ?? '';
          Email = userDetails?['email'] ?? '';
          District = userDetails?['district'] ?? '';
          Thana = userDetails?['thana'] ?? '';
          Phone = userDetails?['phone'] ?? '';
          profilePic = userDetails?['profile_pic'] ?? '';
          freeDeliveryInfo = userDetails?["free_delivery_info"] ?? 0;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading profile: $e")));
      }
    }
  }

  Future<String?> _updateProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return null;

      File imageFile = File(pickedFile.path);
      return await imageService.uploadProfileImage(imageFile); // Return URL
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
            // State variables for the dialog
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
                    // Profile picture section
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
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage:
                                      tempProfilePic.isNotEmpty
                                          ? NetworkImage(tempProfilePic)
                                          : null,
                                  child:
                                      tempProfilePic.isEmpty
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
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name Field
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

                    // Phone Field
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

                    // Email (read-only)
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
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      _isSaving
                          ? null
                          : () async {
                            setDialogState(() => _isSaving = true);

                            try {
                              // Prepare updated data - using correct Firestore field names
                              Map<String, dynamic> updatedData = {
                                'name': tempName,
                                'phone': tempPhone,
                                'profile_pic':
                                    tempProfilePic, // Match Firestore field name
                              };

                              // Save to Firestore
                              bool success = await db.updateUserDetails(
                                Email,
                                updatedData,
                              );

                              if (success) {
                                // Update local state
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
                    backgroundColor: Colors.blue[700],
                  ),
                  child:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'SAVE',
                            style: TextStyle(color: Colors.white),
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
                    // District Dropdown
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

                    // Thana Dropdown
                    DropdownButtonFormField<String>(
                      value: thanaList.isNotEmpty ? tempThana : null,
                      items:
                          thanaList.map((thana) {
                            return DropdownMenuItem(
                              value: thana,
                              child: Text(thana),
                            );
                          }).toList(),
                      onChanged:
                          thanaList.isNotEmpty
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

                    // Address Text Field
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
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      _isSaving
                          ? null
                          : () async {
                            setDialogState(() => _isSaving = true);

                            try {
                              // Prepare updated address data
                              Map<String, dynamic> updatedData = {
                                'district': tempDistrict,
                                'thana': tempThana,
                                'address': tempAddress,
                              };

                              // Save to Firestore
                              bool success = await db.updateUserDetails(
                                Email,
                                updatedData,
                              );

                              if (success) {
                                // Update local state
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
                    backgroundColor: Colors.blue[700],
                  ),
                  child:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'SAVE',
                            style: TextStyle(color: Colors.white),
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
              child: Image.network(
                profilePic,
                fit: BoxFit.contain,
              ),
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
                        style: const TextStyle(color: Colors.red),
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
                  onPressed:
                      _isChangingPassword
                          ? null
                          : () async {
                            setDialogState(() => _isChangingPassword = true);

                            final currentPassword =
                                currentPasswordController.text;
                            final newPassword = newPasswordController.text;
                            final confirmPassword =
                                confirmPasswordController.text;

                            // Validation
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
                                // Success
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
                  child:
                      _isChangingPassword
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
    // Show loading indicator while data is loading
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFf2f2ce),
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
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Show error message if there was an error
    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFf2f2ce),
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
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
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

    // Normal profile view
    return Scaffold(
      backgroundColor: const Color(0xFFf2f2ce),
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
            // Show fullscreen image if we're not currently updating
            if (!_isUpdatingProfilePic) {
              _showFullScreenProfilePicture();
            }
          },
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
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
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Email,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                Phone,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
            // In _buildOrderSection
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
              onTap:
                  () => _navigateToOrderPage(context, 'To Receive', toReceive),
              child: _buildOrderStatus(
                'To Receive',
                Icons.shopping_bag,
                toReceiveCount,
              ),
            ),
            GestureDetector(
              onTap:
                  () => _navigateToOrderPage(context, 'Completed', Completed),
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

  // 4. Navigation function for orders
  // In _ProfileState class
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
            Icon(icon, size: 28, color: Colors.blue[700]),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
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
                  const Icon(Icons.home, size: 20, color: Colors.blue),
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
                      style: TextStyle(color: Colors.green, fontSize: 12),
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
                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                    label: const Text(
                      'Edit Address',
                      style: TextStyle(color: Colors.blue),
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

  Widget _buildLoyaltySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[800]!, Colors.blue[600]!],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_membership, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium Member',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: freeDelivery,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  color: Colors.amber,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Text(
                  freeDeliveryInfo >= 130
                      ? 'You can have free delivery! you have: $freeDeliveryInfo points '
                      : '${(130 - freeDeliveryInfo).toStringAsFixed(1)} point need to get next free delivery',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    final List<Map<String, dynamic>> settings = [
      {'icon': Icons.password, 'title': 'Change password'},
      {'icon': Icons.help_outline, 'title': 'Help Center'},
      {'icon': Icons.logout, 'title': 'Logout', 'color': Colors.red},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...settings.map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item['icon'] as IconData,
              color:
                  (item['color'] != null)
                      ? item['color'] as Color
                      : Colors.blue[700],
            ),
            title: Text(
              item['title'] as String,
              style: TextStyle(
                color:
                    (item['color'] != null)
                        ? item['color'] as Color
                        : Colors.black,
                fontWeight:
                    (item['color'] != null)
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _handleSettingsTap(item['title'] as String),
          ),
        ),
      ],
    );
  }

  void _handleSettingsTap(String title) {
    switch (title) {
      case 'Change password':
        _changePassword();
        break;
      case 'Help Center':
        _showHelpCenter(); // Now this opens the help center with clickable items
        break;
      case 'Logout':
        _logout();
        break;
    }
  }

  void _showHelpCenter() {
    final List<Map<String, dynamic>> helpItems = [
      {
        'title': 'How to place an order?',
        'icon': Icons.shopping_cart,
        'url': 'https://yourwebsite.com/help/place-order',
      },
      {
        'title': 'Payment methods',
        'icon': Icons.payment,
        'url': 'https://yourwebsite.com/help/payment-methods',
      },
      {
        'title': 'Delivery information',
        'icon': Icons.local_shipping,
        'url': 'https://yourwebsite.com/help/delivery-info',
      },
      {
        'title': 'Return policy',
        'icon': Icons.assignment_return,
        'url': 'https://yourwebsite.com/help/return-policy',
      },
      {
        'title': 'Contact support',
        'icon': Icons.support_agent,
        'url': 'https://yourwebsite.com/help/contact-support',
      },
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(title: const Text('Help Center')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children:
                    helpItems
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
      leading: Icon(icon, color: Colors.blue),
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

  void _logout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout Confirmation'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // Close the dialog first
                  Navigator.pop(context);

                  try {
                    // Perform the actual logout
                    await _auth.signOut();

                    // Navigate to home screen or login screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => Home()),
                    );

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  } catch (e) {
                    // Show error message if logout fails
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
