import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
import 'l10n.dart';
import 'models.dart';
import 'theme.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showError(BuildContext context, Object error) {
  showMessage(context, error is ApiException ? error.details : 'Something went wrong. Please try again.');
}

Future<bool> confirm(BuildContext context, String title, {String? body, String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(S.of(c)('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

/// Loads a list from the API and renders loading, error and empty states the
/// same way on every management screen.
class AsyncList<T> extends StatefulWidget {
  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.emptyIcon,
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String empty;
  final Widget? header;
  final IconData? emptyIcon;

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  late Future<List<T>> _future = widget.load();

  void reload() => setState(() {
        _future = widget.load();
      });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        reload();
        await _future.catchError((_) => <T>[]);
      },
      child: FutureBuilder<List<T>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: reload);
          }
          final items = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (widget.header != null) widget.header!,
              if (items.isEmpty) EmptyState(icon: widget.emptyIcon ?? Icons.inbox_outlined, text: widget.empty),
              for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: widget.itemBuilder(context, item, reload)),
            ],
          );
        },
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.cloud_off_outlined, size: 34, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 18),
        Text(error is ApiException ? (error as ApiException).details : '$error', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 18),
        Center(child: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(S.of(context)('try_again')))),
      ],
    );
  }
}

/// A quiet "nothing here yet" with an icon, for lists and sections.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  factory StatusChip.forStatus(String status, String label) {
    final c = switch (status) {
      'approved' || 'published' || 'confirmed' || 'verified' => Palette.tulsi,
      'pending' || 'pending_review' || 'pending_payment' || 'in_review' => const Color(0xFFB08A10),
      'rejected' || 'cancelled' || 'refunded' || 'duplicate' => const Color(0xFFB3261E),
      'expired' => const Color(0xFF8D6E63),
      _ => Palette.sky,
    };
    return StatusChip(label, color: c);
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12, height: 1.3)),
      ]),
    );
  }
}

/// A section heading: the title with a short kumkum rule, and room on the
/// right for a "See all" or a picker.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
              if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
            ]),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small caps above a figure or a block: "TODAY", "REFERENCE".
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(color: color ?? theme.colorScheme.onSurfaceVariant, letterSpacing: 1.4, fontSize: 10.5),
    );
  }
}

/// A rounded panel on a gradient, for the figures that matter most. White
/// text; a faint ring in the corner lifts it off the page.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.gradient = Palette.kumkumGradient, this.onTap, this.padding = const EdgeInsets.all(20), this.ornament = true});

  final Widget child;
  final Gradient gradient;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool ornament;

  @override
  Widget build(BuildContext context) {
    final style = TrustStyle.of(context);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(TrustTheme.radius + 2), boxShadow: style.cardShadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TrustTheme.radius + 2),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(gradient: gradient),
            child: InkWell(
              onTap: onTap,
              child: Stack(children: [
                if (ornament) ...[
                  Positioned(right: -30, top: -40, child: _ring(140)),
                  Positioned(right: 30, bottom: -60, child: _ring(110)),
                ],
                Padding(
                  padding: padding,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 14)),
      );
}

/// A card with the soft shadow instead of the outline; the content cards.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color, this.border});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = TrustStyle.of(context);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(TrustTheme.radius), boxShadow: style.cardShadow),
      child: Material(
        color: color ?? theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TrustTheme.radius), side: BorderSide(color: border ?? theme.colorScheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// A number with its label and an icon in a tinted square; the stat grids.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, required this.icon, this.onTap, this.color, this.caption});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            IconBadge(icon, color: c, size: 32),
            const Spacer(),
            if (onTap != null) Icon(Icons.arrow_outward, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ]),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22))),
          Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (caption != null) Text(caption!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// An icon on a tinted rounded square.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 40, this.filled = false});

  final IconData icon;
  final Color? color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: filled ? c : c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.52, color: filled ? Colors.white : c),
    );
  }
}

/// A row that opens a screen: icon badge, title, subtitle, chevron. The
/// management lists on the dashboard and the admin home.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.title, this.subtitle, required this.onTap, this.color, this.badge, this.trailing});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          IconBadge(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(width: 8),
          if (badge != null) ...[StatusChip(badge!, color: color), const SizedBox(width: 4)],
          trailing ?? Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// A notice with an icon: what needs doing, or what changed.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.title, this.body, this.onTap, this.color, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TrustTheme.radius), side: BorderSide(color: c.withValues(alpha: 0.3))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: c, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(color: c)),
                  if (body != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(body!, style: theme.textTheme.bodySmall)),
                  if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action!),
                ]),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: c),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A label on the left and its value on the right; detail screens.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.emphasis = false, this.valueColor});

  final String label;
  final String value;
  final bool emphasis;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: theme.textTheme.bodySmall)),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: (emphasis ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(color: valueColor, fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// One line of a money breakdown: what, how many, how much.
class ReportLine extends StatelessWidget {
  const ReportLine({super.key, required this.label, this.counts, required this.amount, this.color, this.bold = false});

  final String label;
  final String? counts;
  final String amount;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        if (color != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8)],
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)),
        if (counts != null) ...[Text(counts!, style: theme.textTheme.bodySmall), const SizedBox(width: 12)],
        Text(amount, style: (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

/// A temple's photo, whole: fitted inside its frame over a blurred copy
/// of itself, so a portrait or a panorama is never cropped and never sits
/// on bare bars. The web cannot blur a network image; there the frame
/// behind is the kumkum gradient.
class FittedPhoto extends StatelessWidget {
  const FittedPhoto(this.url, {super.key, this.placeholder});

  final String url;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final behind = placeholder ?? const DecoratedBox(decoration: BoxDecoration(gradient: Palette.kumkumGradient));
    return Stack(fit: StackFit.expand, children: [
      if (kIsWeb)
        behind
      else
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.decal),
          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => behind),
        ),
      if (!kIsWeb) const ColoredBox(color: Color(0x33000000)),
      Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    ]);
  }
}

/// The first letters of a name on a coloured disc.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 44, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.38, fontFamily: TrustTheme.serif)),
    );
  }
}

/// A dropdown over `/trust/options` values.
class OptionField extends StatelessWidget {
  const OptionField({super.key, required this.label, required this.options, required this.value, required this.onChanged, this.allowNone = false, this.noneLabel = '—'});

  final String label;
  final List<Option> options;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.value == value);
    return DropdownButtonFormField<dynamic>(
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowNone) DropdownMenuItem<dynamic>(value: null, child: Text(noneLabel)),
        for (final o in options) DropdownMenuItem<dynamic>(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

/// A text field that shows the API's validation message for its field.
class ApiTextField extends StatelessWidget {
  const ApiTextField({
    super.key,
    required this.controller,
    required this.label,
    this.field,
    this.error,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.obscure = false,
    this.required = false,
    this.autofillHints,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? field;
  final ApiException? error;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool required;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: obscure ? 1 : maxLines,
        minLines: 1,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          errorText: field == null ? null : error?.field(field!),
          errorMaxLines: 3,
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    );
  }
}

/// Time as "HH:mm", the format the API reads and writes.
String? formatTime(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? parseTime(dynamic v) {
  if (v is! String || !v.contains(':')) return null;
  final p = v.split(':');
  return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
}

String formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Fri, 3 Oct 2026", for people rather than the API.
String prettyDate(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);

/// A tappable row that opens a time picker.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value ?? const TimeOfDay(hour: 6, minute: 0));
        if (t != null) onChanged(t);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null ? const Icon(Icons.schedule) : IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null)),
        ),
        child: Text(value == null ? '—' : formatTime(value)!),
      ),
    );
  }
}

/// A tappable row that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = false, this.emptyLabel});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 3),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: clearable && value != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null)) : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? (emptyLabel ?? '—') : formatDate(value!)),
      ),
    );
  }
}

/// Paise from the API as rupees, the Indian way: ₹1,23,456.00.
String rupees(dynamic paise) {
  final p = (paise as num?)?.toInt() ?? 0;
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(p / 100);
}

/// Rupees without paise, for the large figures: ₹1,23,456.
String rupeesShort(dynamic paise) {
  final p = (paise as num?)?.toInt() ?? 0;
  if (p % 100 != 0) return rupees(p);
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(p ~/ 100);
}

/// A figure with its label, for money and counts on the finance screens.
class Figure extends StatelessWidget {
  const Figure(this.label, this.value, {super.key, this.caption, this.emphasis = false, this.color});

  final String label;
  final String value;
  final String? caption;
  final bool emphasis;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: (emphasis ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(color: color, fontWeight: emphasis ? FontWeight.w600 : FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        if (caption != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(caption!, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
