import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

class TacticalFilterMenu extends StatefulWidget {
  const TacticalFilterMenu({
    super.key,
    required this.showCritical,
    required this.showMajor,
    required this.showMinor,
    required this.onCriticalChanged,
    required this.onMajorChanged,
    required this.onMinorChanged,
    this.initiallyExpanded = false,
  });

  final bool showCritical;
  final bool showMajor;
  final bool showMinor;
  final ValueChanged<bool> onCriticalChanged;
  final ValueChanged<bool> onMajorChanged;
  final ValueChanged<bool> onMinorChanged;
  final bool initiallyExpanded;

  @override
  State<TacticalFilterMenu> createState() => _TacticalFilterMenuState();
}

class _TacticalFilterMenuState extends State<TacticalFilterMenu> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: UdieTheme.durationMedium,
      curve: UdieTheme.curveDefault,
      width: _isExpanded ? 208 : 50,
      height: _isExpanded ? 184 : 50,
      decoration: BoxDecoration(
        color: UdieTheme.surface0.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(_isExpanded ? 16 : 25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isExpanded ? 16 : 25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: _isExpanded ? _buildExpandedMenu() : _buildCollapsedIcon(),
        ),
      ),
    );
  }

  Widget _buildCollapsedIcon() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      child: const Center(
        child: Icon(Icons.filter_list, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FILTERS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: () => setState(() => _isExpanded = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        _buildFilterRow(
          'Critical',
          UdieTheme.danger,
          widget.showCritical,
          widget.onCriticalChanged,
        ),
        _buildFilterRow(
          'Major',
          UdieTheme.caution,
          widget.showMajor,
          widget.onMajorChanged,
        ),
        _buildFilterRow(
          'Minor',
          const Color(0xFFF8D24A),
          widget.showMinor,
          widget.onMinorChanged,
        ),
      ],
    );
  }

  Widget _buildFilterRow(
    String label,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SizedBox(
      height: 36,
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        value: value,
        activeColor: color,
        checkColor: Colors.black,
        dense: true,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    );
  }
}
