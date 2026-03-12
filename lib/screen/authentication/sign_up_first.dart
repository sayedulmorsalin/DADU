import 'package:dadu/screen/authentication/sign_in.dart';
import 'package:dadu/screen/authentication/sign_up_2nd.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _acceptTerms = false;
  bool _acceptPrivacyPolicy = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final Auth _auth = Auth();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ================= SUBMIT =================

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please accept terms and conditions")),
        );
        return;
      }

      if (!_acceptPrivacyPolicy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please accept privacy policy")),
        );
        return;
      }

      setState(() => _isLoading = true);

      final String email = _emailController.text.trim();
      final String password = _passwordController.text;

      try {
        final error = await _auth.registerWithEmailAndPassword(
          email,
          password,
          "User",
        );

        if (error == null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SignUpScreen2()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.scaffoldBackground,

        appBar: AppBar(
          backgroundColor: AppColors.scaffoldBackground,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Create Account",
            style: TextStyle(color: Colors.black),
          ),
        ),

        // ================= SCROLL FIX =================
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),

                    // ================= FORM =================
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          /// Logo / Title
                          Center(
                            child: Text(
                              "DADU",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          /// EMAIL
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Email",
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  !value.contains("@")) {
                                return "Please enter a valid email";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          /// PASSWORD
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.remove_red_eye_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return "Password must be at least 8 characters";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          /// CONFIRM PASSWORD
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: "Confirm Password",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                child: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.remove_red_eye_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return "Passwords don't match";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          /// TERMS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _acceptTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptTerms = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    const url =
                                        'https://sites.google.com/view/dadu-app/terms-conditions';

                                    await launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  child: const Text(
                                    "I agree to the terms and conditions",
                                    style: TextStyle(
                                      fontSize: 16,
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          /// PRIVACY POLICY
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _acceptPrivacyPolicy,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptPrivacyPolicy = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    const url =
                                        'https://sites.google.com/view/dadu-app/privacy-policy-page';

                                    await launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  child: const Text(
                                    "I agree to the privacy policy",
                                    style: TextStyle(
                                      fontSize: 16,
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          /// SIGN IN
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                "Already have an account",
                                style: TextStyle(fontSize: 16),
                              ),
                              Text.rich(
                                TextSpan(
                                  text: " Sign In",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => SignInScreen(),
                                            ),
                                          );
                                        },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          /// BUTTON
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                      : const Text(
                                        "Next",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
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
      ),
    );
  }
}
