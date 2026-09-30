import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
import 'models.dart';

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
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
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
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String empty;
  final Widget? header;

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  late Future<List<T>> _future = widget.load();

  void reload() => setState(() => _future = widget.load());

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
          if (snap.connectionState != ConnectionState.done) {
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
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(widget.empty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                ),
              for (final item in items)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: widget.itemBuilder(context, item, reload)),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(error is ApiException ? (error as ApiException).details : '$error', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Try again'))),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  factory StatusChip.forStatus(String status, String label) {
    final c = switch (status) {
      'approved' || 'published' || 'confirmed' || 'verified' => const Color(0xFF2E7D55),
      'pending' || 'pending_review' || 'pending_payment' || 'in_review' => const Color(0xFFC9A227),
      'rejected' || 'cancelled' || 'refunded' || 'duplicate' => const Color(0xFFB3261E),
      _ => const Color(0xFF6B7FA8),
    };
    return StatusChip(label, color: c);
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
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

/// A tappable row that opens a time picker.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = false});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
          suffixIcon: clearable && value != null
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null))
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? '—' : formatDate(value!)),
      ),
    );
  }
}

/// Paise from the API as rupees, the Indian way: ₹1,23,456.00.
String rupees(dynamic paise) {
  final p = (paise as num?)?.toInt() ?? 0;
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(p / 100);
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
        const SizedBox(height: 2),
        Text(
          value,
          style: (emphasis ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
        if (caption != null) Text(caption!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
