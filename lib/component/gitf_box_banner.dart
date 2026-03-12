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

    /// Floating
    floatAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(controller);

    /// Lid slide
    lidSlide = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -55.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(-55.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -55.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
    ]).animate(controller);

    /// Lid rotate
    lidRotate = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.5), weight: 1),
      TweenSequenceItem(tween: ConstantTween(-0.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.5, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
    ]).animate(controller);

    /// 🎉 pop
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            return Container(
              height: 130,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/banar/freeproduct.jpeg"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Transform.translate(
                    offset: Offset(0, floatAnim.value),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: popScale.value,
                            child: const Text(
                              "🎉",
                              style: TextStyle(fontSize: 40),
                            ),
                          ),

                          /// box body
                          Container(
                            width: 65,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.giftBoxBody,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          /// lid
                          Transform.translate(
                            offset: Offset(0, lidSlide.value),
                            child: Transform.rotate(
                              angle: lidRotate.value,
                              child: Container(
                                width: 72,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.giftBoxLid,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
