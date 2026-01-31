import 'dart:async';
import 'package:flutter/material.dart';

class GiftBoxBanner extends StatefulWidget {
  final VoidCallback? onOpen;

  const GiftBoxBanner({super.key, this.onOpen});

  @override
  State<GiftBoxBanner> createState() => _GiftBoxBannerState();
}

class _GiftBoxBannerState extends State<GiftBoxBanner>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  late Animation<double> floatAnim;
  late Animation<double> lidSlide;
  late Animation<double> lidRotate;
  late Animation<double> popScale;

  bool opened = false;

  @override
  void initState() {
    super.initState();

    /// ONE controller only (safer + faster)
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    /// floating (loop)
    floatAnim = Tween(begin: 0.0, end: -14.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    /// open animation
    lidSlide = Tween(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    lidRotate = Tween(begin: 0.0, end: -0.5).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );

    popScale = Tween(begin: 0.0, end: 1.6).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );

    /// floating loop
    controller.repeat(reverse: true);

    /// auto open once after 2s
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      opened = true;
      controller.forward(); // play big open
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpen, // navigate only on tap
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return Transform.translate(
            offset: Offset(0, floatAnim.value),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF512F), Color(0xFFFFC371)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(.35),
                    blurRadius: 25,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Row(
                children: [

                  /// 🎁 gift
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [

                        /// pop emoji
                        Transform.scale(
                          scale: opened ? popScale.value : 0,
                          child: const Text("🎉", style: TextStyle(fontSize: 42)),
                        ),

                        /// bottom
                        Container(
                          width: 65,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),

                        /// lid
                        Transform.translate(
                          offset: Offset(0, opened ? lidSlide.value : 0),
                          child: Transform.rotate(
                            angle: opened ? lidRotate.value : 0,
                            child: Container(
                              width: 72,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 18),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Daily Gift Box 🎁",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Tap to claim your surprise",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.arrow_forward_ios, color: Colors.white),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
