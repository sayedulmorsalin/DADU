import 'dart:async';
import 'package:flutter/material.dart';

class InfoBanner extends StatefulWidget {
  const InfoBanner({super.key});

  @override
  State<InfoBanner> createState() => _InfoBannerState();
}

class _InfoBannerState extends State<InfoBanner> {
  Timer? _timer;
  int _currentIndex = 0;

  final List<Map<String, String>> _infoItems = [
    {'image': 'assets/info_banner/delivery.gif', 'label': 'Whole Bangladesh delivery'},
    {'image': 'assets/info_banner/hasel.gif', 'label': 'Hassle-free Returns'},
    {'image': 'assets/info_banner/support.gif', 'label': '24/7 Support'},
    {'image': 'assets/info_banner/authentic.gif', 'label': 'Authentic Product'},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _infoItems.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final imageHeight = (screenWidth * 0.18).clamp(56.0, 100.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildInfoRow(
          key: ValueKey<int>(_currentIndex),
          imagePath: _infoItems[_currentIndex]['image']!,
          imageHeight: imageHeight,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    Key? key,
    required String imagePath,
    required double imageHeight,
  }) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Image.asset(
            imagePath,
            height: imageHeight,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
