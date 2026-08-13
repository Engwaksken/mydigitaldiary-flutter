/// A generic record for any module driven by ModuleConfig — wraps the raw
/// JSON map instead of a typed class, since DynamicCrudScreen doesn't
/// know a module's exact shape at compile time (that's the whole point:
/// one screen, many modules). Reminders/Meetings/Expenses keep their own
/// typed Expense/Meeting/Reminder models and bespoke screens unchanged;
/// this is specifically for the modules added via ModuleConfig instead.
class DynamicItem {
  final Map<String, dynamic> data;

  DynamicItem(this.data);

  int get id => data['id'] as int;

  dynamic operator [](String key) => data[key];

  factory DynamicItem.fromJson(Map<String, dynamic> json) => DynamicItem(json);

  Map<String, dynamic> toJson() => data;
}
