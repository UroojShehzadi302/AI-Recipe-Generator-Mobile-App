import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

/// Horizontal "OR" separator used between primary and social auth actions.
///
/// A grey divider on each side of a centered "OR" label.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(AppStrings.or),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}
