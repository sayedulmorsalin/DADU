import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';

class GiftBoxBanner extends StatefulWidget {
  final VoidCallback onOpen;

  const GiftBoxBanner({super.key, required this.onOpen});

  @override
  State<GiftBoxBanner> createState() => _GiftBoxBannerState();
}

class _GiftBoxBannerState extends State<GiftBoxBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  late final Animation<double> floatAnim;
  late final Animation<double> lidSlide;
  late final Animation<double> lidRotate;
  late final Animation<double> popScale;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    floatAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(controller);

    lidSlide = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -55.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(-55.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -55.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
    ]).animate(controller);

    lidRotate = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.5), weight: 1),
      TweenSequenceItem(tween: ConstantTween(-0.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.5, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
    ]).animate(controller);

    popScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.6), weight: 1),
      TweenSequenceItem(tween: ConstantTween(1.6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
    ]).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpen,
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade100, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 15,
              bottom: 10,
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, __) {
                  return Transform.translate(
                    offset: Offset(0, floatAnim.value),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: popScale.value,
                            child: const Text(
                              "🎉",
                              style: TextStyle(fontSize: 35),
                            ),
                          ),
                          Container(
                            width: 55,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, lidSlide.value),
                            child: Transform.rotate(
                              angle: lidRotate.value,
                              child: Container(
                                width: 62,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade600,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUCKY DRAW',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'Try your luck and win prizes!',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
