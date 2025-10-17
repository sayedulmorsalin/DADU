import 'package:flutter/material.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.lightGreen[200],
      child: Column(
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.verified_user),
              Text("Authentic Product"),
              Icon(Icons.local_shipping),
              Text("Whole Bangladesh delivery"),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.refresh),
              Text("Hassle-free Returns"),
              Icon(Icons.support_agent),
              Text("24/7 Support"),
            ],
          ),
        ],
      ),
    );
  }
}