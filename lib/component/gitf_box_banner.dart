import 'package:flutter/material.dart';

class GiftBoxBanner extends StatefulWidget {
  final VoidCallback? onOpen;

  const GiftBoxBanner({super.key, this.onOpen});

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

    floatAnim = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: -10),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -10, end: 0),
        weight: 1,
      ),
    ]).animate(controller);

    lidSlide = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: -60),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(-60),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -60, end: 0),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: 1,
      ),
    ]).animate(controller);

    lidRotate = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: -0.5),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(-0.5),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.5, end: 0),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: 1,
      ),
    ]).animate(controller);

    popScale = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1.6),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1.6),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.6, end: 0),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: 1,
      ),
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
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: popScale.value,
                          child: const Text("🎉",
                              style: TextStyle(fontSize: 42)),
                        ),
                        Container(
                          width: 65,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, lidSlide.value),
                          child: Transform.rotate(
                            angle: lidRotate.value,
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
                    child: Text(
                      "Special Gift Box 🎁",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
