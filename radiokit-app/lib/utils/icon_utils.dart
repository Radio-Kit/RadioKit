import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Maps a string identifier (e.g. "play", "settings") to a Lucide icon.
/// Used by widgets like TextWidget and MultipleWidget to display icons.
IconData? parseIconFromName(String name) {
  final clean = name.toLowerCase().trim();
  if (clean.isEmpty) return null;
  switch (clean) {
    case 'settings': return PhosphorIconsFill.gearSix;
    case 'play':     return PhosphorIconsFill.play;
    case 'pause':    return PhosphorIconsFill.pause;
    case 'stop':     return PhosphorIconsFill.square;
    case 'power':    return PhosphorIconsFill.power;
    case 'zap':      return PhosphorIconsFill.lightning;
    case 'sliders':  return PhosphorIconsFill.slidersHorizontal;
    case 'cpu':      return PhosphorIconsFill.cpu;
    case 'mouse':    return PhosphorIconsFill.mouse;
    case 'moon':     return PhosphorIconsFill.moon;
    case 'sun':      return PhosphorIconsFill.sun;
    case 'leaf':     return PhosphorIconsFill.leaf;
    case 'rotate-cw':return PhosphorIconsFill.arrowClockwise;
    case 'rotate-ccw':return PhosphorIconsFill.arrowCounterClockwise;
    case 'skull':    return PhosphorIconsFill.skull;
    case 'thermometer':return PhosphorIconsFill.thermometer;
    case 'map-pin':  return PhosphorIconsFill.mapPin;
    case 'volume':   return PhosphorIconsFill.speakerHigh;
    case 'mute':     return PhosphorIconsFill.speakerX;
    case 'mic':      return PhosphorIconsFill.microphone;
    case 'wifi':     return PhosphorIconsFill.wifiHigh;
    case 'bluetooth':return PhosphorIconsFill.bluetooth;
    case 'home':     return PhosphorIconsFill.house;
    case 'user':     return PhosphorIconsFill.user;
    case 'lock':     return PhosphorIconsFill.lock;
    case 'unlock':   return PhosphorIconsFill.lockOpen;
    case 'light':    return PhosphorIconsFill.sun;
    case 'dark':     return PhosphorIconsFill.moon;
    case 'up':       return PhosphorIconsFill.caretUp;
    case 'down':     return PhosphorIconsFill.caretDown;
    case 'left':     return PhosphorIconsFill.caretLeft;
    case 'right':    return PhosphorIconsFill.caretRight;
    case 'plus':     return PhosphorIconsFill.plus;
    case 'minus':    return PhosphorIconsFill.minus;
    case 'check':    return PhosphorIconsFill.check;
    case 'x':        return PhosphorIconsFill.x;
    default:         return PhosphorIconsFill.question;
  }
}
