import 'package:flutter/material.dart';

class SwiggyLocationPulseDialog extends StatefulWidget {
  final String title;

  const SwiggyLocationPulseDialog({
    super.key,
    this.title = 'Locating your delivery address...',
  });

  static Future<T?> show<T>(BuildContext context, {String title = 'Locating your delivery address...'}) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SwiggyLocationPulseDialog(title: title),
    );
  }

  @override
  State<SwiggyLocationPulseDialog> createState() => _SwiggyLocationPulseDialogState();
}

class _SwiggyLocationPulseDialogState extends State<SwiggyLocationPulseDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFfc8019);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Radar Pulse Animation
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Radar Pulse Ring 2
                    Transform.scale(
                      scale: _pulseAnimation.value * 1.3,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(
                            alpha: (1.0 - (_controller.value)).clamp(0.0, 0.25),
                          ),
                        ),
                      ),
                    ),
                    // Outer Radar Pulse Ring 1
                    Transform.scale(
                      scale: _pulseAnimation.value * 1.1,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(
                            alpha: (1.0 - (_controller.value)).clamp(0.0, 0.4),
                          ),
                        ),
                      ),
                    ),
                    // Center Core Pin Circle
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Fetching high-accuracy GPS...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
