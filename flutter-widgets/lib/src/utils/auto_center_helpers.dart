import 'package:flutter/material.dart';

bool acEnabled(List<dynamic>? ac) => (ac?[0] as String?) != null;

double acPosition(List<dynamic>? ac) {
  final pos = ac?[0] as String?;
  switch (pos) {
    case 'min':
      return 0.0;
    case 'max':
      return 1.0;
    case 'center':
    default:
      return 0.5;
  }
}

Curve acCurve(List<dynamic>? ac) {
  final type = ac?[1] as String? ?? 'smooth';
  switch (type) {
    case 'linear':
      return Curves.linear;
    case 'elastic':
      return Curves.elasticOut;
    default:
      return Curves.easeOutCubic;
  }
}

int acDuration(List<dynamic>? ac, int fallback) =>
    (ac?[2] as num?)?.toInt() ?? fallback;
