import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'l10n.dart';
import 'widgets.dart';

/// The fix must be at least this good: the server refuses anything vaguer
/// (TrustTempleRegistrationController::LOCATION_ACCURACY_M).
const double kLocationAccuracyM = 150;

/// A GPS fix taken on the spot. Coordinates are never typed in: the team has
/// to stand at the temple, so the pin devotees follow is where it really is.
class LiveFix {
  const LiveFix(this.latitude, this.longitude, this.accuracy);

  final double latitude;
  final double longitude;
  final double accuracy;

  Map<String, dynamic> toFields() => {
        'latitude': latitude.toStringAsFixed(7),
        'longitude': longitude.toStringAsFixed(7),
        'location_accuracy': accuracy.toStringAsFixed(1),
      };
}

/// Reads the phone's current position, asking for permission when needed.
/// Throws a message the person can act on, in [s]'s language.
Future<LiveFix> currentFix([S s = const S('en')]) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw s('ob_gps_off');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied)
    permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) {
    throw s('ob_allow_location');
  }
  if (permission == LocationPermission.deniedForever) {
    throw s('ob_location_blocked');
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 30)),
  );
  if (p.isMocked) throw s('ob_mock_location');
  if (p.accuracy > kLocationAccuracyM) {
    throw s('ob_low_accuracy', {'m': p.accuracy.round()});
  }
  return LiveFix(p.latitude, p.longitude, p.accuracy);
}

/// "Use my current location": shows the captured fix, or what is on file.
class LiveLocationField extends StatefulWidget {
  const LiveLocationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.saved,
    this.error,
    this.required = false,
  });

  final LiveFix? value;
  final ValueChanged<LiveFix> onChanged;

  /// Coordinates already on the listing, shown until a new fix is taken.
  final String? saved;
  final String? error;
  final bool required;

  @override
  State<LiveLocationField> createState() => _LiveLocationFieldState();
}

class _LiveLocationFieldState extends State<LiveLocationField> {
  bool _busy = false;

  Future<void> _capture() async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final fix = await currentFix(s);
      widget.onChanged(fix);
    } catch (e) {
      if (mounted)
        showMessage(context, e is String ? e : s('ob_location_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final v = widget.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(v == null ? Icons.location_searching : Icons.my_location,
                color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v != null
                    ? '${v.latitude.toStringAsFixed(6)}, ${v.longitude.toStringAsFixed(6)} (±${v.accuracy.round()} m)'
                    : widget.saved ??
                        (widget.required
                            ? s('ob_location_not_recorded')
                            : s('ob_no_location')),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            s('ob_location_help', {'m': kLocationAccuracyM.round()}),
            style: theme.textTheme.bodySmall,
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 6),
            Text(widget.error!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _capture,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.gps_fixed),
            label: Text(_busy
                ? s('ob_reading_gps')
                : (v == null ? s('ob_use_location') : s('ob_take_again'))),
          ),
        ]),
      ),
    );
  }
}
