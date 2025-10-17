import 'dart:io';
import 'package:dadu/data/district_upozila.dart';
import 'package:dadu/screen/user/profile.dart';
import 'package:dadu/services/auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api.dart';

class SignUpScreen2 extends StatefulWidget {
  @override
  _SignUpScreen2State createState() => _SignUpScreen2State();
}

class _SignUpScreen2State extends State<SignUpScreen2> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedDistrict;
  String? _selectedThana;
  File? _profileImage;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final DistrictUpozila _districtUpozila = DistrictUpozila();
  final ImageService _imageService = ImageService();
  final Auth auth = Auth();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        String? profilePicUrl;
        if (_profileImage != null) {
          try {
            profilePicUrl = await _imageService.uploadProfileImage(_profileImage!);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Profile image upload failed: ${e.toString()}"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        await auth.createUserProfile(
          name: _nameController.text,
          phone: _phoneController.text,
          profilePicUrl: profilePicUrl,
          district: _selectedDistrict,
          thana: _selectedThana,
          address: _addressController.text,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Profile()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFf2f2ce),
      appBar: AppBar(
        backgroundColor: Color(0xFFf2f2ce),
        elevation: 0,
        title: Text("Create Account", style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile image picker
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[300],
                            child: _profileImage == null
                                ? Icon(Icons.add_a_photo, size: 40)
                                : ClipOval(
                              child: Image.file(
                                _profileImage!,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Name field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? "Please enter your name" : null,
                        ),
                        SizedBox(height: 16),

                        // Phone field
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Phone Number",
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value!.isEmpty || value.length != 11) {
                              return "Please enter a valid 11-digit phone number";
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // District and Thana dropdowns
                        SizedBox(
                          height: 150,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return constraints.maxWidth > 600
                                  ? Row(
                                children: [
                                  _buildDistrictDropdown(),
                                  SizedBox(width: 12),
                                  _buildThanaDropdown(),
                                ],
                              )
                                  : Column(
                                children: [
                                  _buildDistrictDropdown(),
                                  SizedBox(height: 16),
                                  _buildThanaDropdown(),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16),

                        // Address field
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: "Address",
                            prefixIcon: Icon(Icons.home),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? "Please enter your address" : null,
                        ),
                        SizedBox(height: 24),

                        // Submit button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    return Flexible(
      fit: FlexFit.loose,
      child: DropdownButtonFormField<String>(
        value: _selectedDistrict,
        decoration: InputDecoration(
          labelText: "District",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: _districtUpozila.districtToThanas.keys
            .map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (String? newValue) => setState(() {
          _selectedDistrict = newValue;
          _selectedThana = null;
        }),
        validator: (value) => value == null ? "Please select a district" : null,
      ),
    );
  }

  Widget _buildThanaDropdown() {
    return Flexible(
      fit: FlexFit.loose,
      child: DropdownButtonFormField<String>(
        value: _selectedThana,
        decoration: InputDecoration(
          labelText: "Thana",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: _selectedDistrict != null
            ? _districtUpozila.districtToThanas[_selectedDistrict!]!
            .map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        })
            .toList()
            : [],
        onChanged: (String? newValue) => setState(() => _selectedThana = newValue),
        validator: (value) {
          if (_selectedDistrict != null && value == null) {
            return "Please select a thana";
          }
          return null;
        },
      ),
    );
  }
}