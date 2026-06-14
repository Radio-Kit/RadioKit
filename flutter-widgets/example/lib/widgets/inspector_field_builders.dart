import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

class InspectorFieldBuilders {
  static Widget buildSection(RKTokens tokens, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            title,
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
        ),
        ...children,
        Divider(color: tokens.effectiveOutline, height: 1),
      ],
    );
  }

  static Widget buildTextField(RKTokens tokens, String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: TextField(
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        style: TextStyle(
          color: tokens.onSurface,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }

  static Widget buildNumField(RKTokens tokens, String label, int value, ValueChanged<int> onChanged, {double? min, double? max}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: TextField(
        controller: TextEditingController(text: value.toString())
          ..selection = TextSelection.collapsed(offset: value.toString().length),
        keyboardType: TextInputType.number,
        style: TextStyle(color: tokens.onSurface, fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onSubmitted: (_) {
          final parsed = int.tryParse((_.isEmpty ? _ : _));
          if (parsed != null) {
            onChanged(parsed.clamp((min ?? double.negativeInfinity).toInt(), (max ?? double.infinity).toInt()));
          }
        },
      ),
    );
  }

  static Widget buildDoubleField(RKTokens tokens, String label, double value, ValueChanged<double> onChanged, {double? min, double? max, int decimalPlaces = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: TextField(
        controller: TextEditingController(text: value.toStringAsFixed(decimalPlaces))
          ..selection = TextSelection.collapsed(offset: value.toStringAsFixed(decimalPlaces).length),
        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
        style: TextStyle(color: tokens.onSurface, fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onSubmitted: (_) {
          final parsed = double.tryParse(_);
          if (parsed != null) {
            onChanged(parsed.clamp(min ?? double.negativeInfinity, max ?? double.infinity));
          }
        },
      ),
    );
  }

  static Widget buildBoolToggle(RKTokens tokens, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: tokens.primary,
          ),
        ],
      ),
    );
  }

  static Widget buildRotationSlider(RKTokens tokens, double rotation, ValueChanged<double> onChanged, {VoidCallback? onReset}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROTATION',
                style: TextStyle(
                  color: tokens.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rotation != 0 && onReset != null)
                    GestureDetector(
                      onTap: onReset,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: tokens.primary,
                        size: 14,
                      ),
                    ),
                  if (rotation != 0 && onReset != null)
                    const SizedBox(width: 4),
                  Text(
                    '${rotation.toInt()}°',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Slider(
            value: rotation,
            min: -180,
            max: 180,
            divisions: 360,
            activeColor: tokens.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  static Widget buildCenterPinnedSelector(
    RKTokens tokens,
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: options.length <= 4
                ? Row(
                    children: options.map((opt) {
                      final isSelected = value == opt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: () => onChanged(opt),
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected ? tokens.primary : tokens.base200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  opt.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? tokens.onPrimary : tokens.onSurface.withValues(alpha: 0.54),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: value,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    style: TextStyle(
                      color: tokens.onSurface,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    dropdownColor: tokens.surface,
                    onChanged: (val) {
                      if (val != null) onChanged(val);
                    },
                    items: options.map<DropdownMenuItem<String>>((String opt) {
                      return DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt.toUpperCase()),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
