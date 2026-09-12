import 'package:flutter/material.dart';

/// Mirrors the web app's $fields config on each CrudController
/// (resources/views/crud/_fields.blade.php renders from the exact same
/// shape) — kept deliberately parallel so adding a module here is a
/// matter of transcribing that PHP array into this Dart one, not
/// redesigning a form from scratch.
enum FieldType { text, textarea, number, date, datetime, select }

class FieldOption {
  final String value;
  final String label;
  const FieldOption(this.value, this.label);
}

class FieldConfig {
  final String name;
  final String label;
  final FieldType type;
  final bool required;
  final List<FieldOption>? options; // only for FieldType.select
  final String? hint;
  // When set, FieldType.select fetches its options by listing this
  // endpoint's actual records instead of using a static options list
  // — e.g. Savings Contributions' "Savings Goal" field points at
  // 'savings-goals', matching the web app's withGoalOptions() (which
  // populates that select from the user's own goals rather than a
  // fixed list).
  final String? optionsEndpoint;
  final String optionsLabelField;

  const FieldConfig({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.options,
    this.hint,
    this.optionsEndpoint,
    this.optionsLabelField = 'name',
  });
}

/// One of these per module — everything DynamicCrudScreen needs to render
/// a full list + create/edit form without any module-specific screen code.
/// [titleField]/[subtitleField]/[dateField] control what the list row
/// shows; [dateField], if set, is also what a date-range filter (future
/// enhancement) would filter on, matching the web app's $dateField.
class ModuleConfig {
  final String title;
  final String endpoint;
  final IconData icon;
  final Color color;
  final List<FieldConfig> fields;
  final String titleField;
  final String? subtitleField;
  final String?
      amountField; // shown bold on the trailing edge, e.g. money fields
  final String? dateField;

  const ModuleConfig({
    required this.title,
    required this.endpoint,
    required this.icon,
    required this.color,
    required this.fields,
    required this.titleField,
    this.subtitleField,
    this.amountField,
    this.dateField,
  });
}
