import 'package:flutter/material.dart';
import '../config/constants.dart';

class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1425),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, "DASHBOARD"),
              _buildNavItem(1, Icons.receipt_long_rounded, "E-PASSBOOK"),
              _buildNavItem(2, Icons.trending_up_rounded, "STOCKS"),
              _buildNavItem(3, Icons.chat_bubble_outline_rounded, "AI"),
              _buildNavItem(4, Icons.menu_rounded, "MENU"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Glowing Top Indicator Line
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 36 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
            
            // Icon
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade500,
              size: 22,
            ),
            
            // Label Text
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade500,
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
