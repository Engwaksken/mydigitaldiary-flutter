import 'package:flutter/material.dart';
import '../models/field_config.dart';
import '../theme/app_theme.dart';

/// Every module here is transcribed directly from its web equivalent's
/// $fields array (app/Http/Controllers/{Module}Controller.php) and
/// validated against the matching Api\{Module}Controller's $rules — same
/// field names, same enum values, so the JSON round-trips cleanly.
///
/// Two fields across this whole set (SavingsContribution's
/// savings_goal_id, ProjectTask's project_id) are foreign keys that the
/// web app renders as a <select> populated from the user's own
/// goals/projects. This generic engine has no way to fetch and populate
/// that options list without a per-module screen (defeating the point of
/// this file), so those two are plain number fields with a hint telling
/// the user which ID to enter — genuinely the one real limitation of this
/// approach, called out here rather than silently.
final List<ModuleConfig> moduleConfigs = [
  const ModuleConfig(
    title: 'Plans',
    endpoint: 'plans',
    icon: Icons.checklist_outlined,
    color: Colors.indigo,
    titleField: 'title',
    subtitleField: 'status',
    dateField: 'target_date',
    fields: [
      FieldConfig(
        name: 'title',
        label: 'Title',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Finish quarterly report',
      ),
      FieldConfig(
        name: 'period',
        label: 'Period',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('daily', 'Daily'),
          FieldOption('weekly', 'Weekly'),
          FieldOption('monthly', 'Monthly'),
          FieldOption('annually', 'Annually'),
        ],
      ),
      FieldConfig(
        name: 'status',
        label: 'Status',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('pending', 'Pending'),
          FieldOption('in_progress', 'In Progress'),
          FieldOption('completed', 'Completed'),
        ],
      ),
      FieldConfig(
        name: 'target_date',
        label: 'Target Date',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'description',
        label: 'Description',
        type: FieldType.textarea,
      ),
    ],
  ),
  const ModuleConfig(
    title: 'Income',
    endpoint: 'incomes',
    icon: Icons.trending_up,
    color: Colors.green,
    titleField: 'source',
    subtitleField: 'category',
    amountField: 'amount',
    dateField: 'received_at',
    fields: [
      FieldConfig(
        name: 'source',
        label: 'Source',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Acme Corp Salary',
      ),
      FieldConfig(
        name: 'category',
        label: 'Category',
        type: FieldType.text,
        hint: 'e.g. Employment, Business, Gift',
      ),
      FieldConfig(
        name: 'amount',
        label: 'Amount',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'frequency',
        label: 'Frequency',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('one_time', 'One-time'),
          FieldOption('daily', 'Daily'),
          FieldOption('weekly', 'Weekly'),
          FieldOption('monthly', 'Monthly'),
          FieldOption('annually', 'Annually'),
        ],
      ),
      FieldConfig(
        name: 'received_at',
        label: 'Date Received',
        type: FieldType.date,
        required: true,
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Budgets',
    endpoint: 'budgets',
    icon: Icons.account_balance_wallet_outlined,
    color: Colors.teal,
    titleField: 'category',
    subtitleField: 'period',
    amountField: 'amount',
    fields: [
      FieldConfig(
        name: 'category',
        label: 'Category',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Groceries, Rent',
      ),
      FieldConfig(
        name: 'amount',
        label: 'Budgeted Amount',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'period',
        label: 'Period',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('weekly', 'Weekly'),
          FieldOption('monthly', 'Monthly'),
          FieldOption('annually', 'Annually'),
        ],
      ),
      FieldConfig(
        name: 'month_year',
        label: 'Month/Year',
        type: FieldType.text,
        hint: 'e.g. 2026-08 — leave blank for an ongoing budget',
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Debts',
    endpoint: 'debts',
    icon: Icons.handshake_outlined,
    color: Colors.amber,
    titleField: 'person_name',
    subtitleField: 'type',
    amountField: 'amount',
    dateField: 'date',
    fields: [
      FieldConfig(
        name: 'type',
        label: 'Type',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('borrowed', 'Borrowed (I owe them)'),
          FieldOption('lent', 'Lent (they owe me)'),
        ],
      ),
      FieldConfig(
        name: 'person_name',
        label: 'Person',
        type: FieldType.text,
        required: true,
      ),
      FieldConfig(
        name: 'amount',
        label: 'Amount',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'date',
        label: 'Date',
        type: FieldType.date,
        required: true,
      ),
      FieldConfig(name: 'due_date', label: 'Due Date', type: FieldType.date),
      FieldConfig(
        name: 'status',
        label: 'Status',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('outstanding', 'Outstanding'),
          FieldOption('paid', 'Paid'),
        ],
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Savings Goals',
    endpoint: 'savings-goals',
    icon: Icons.savings_outlined,
    color: Colors.lightGreen,
    titleField: 'name',
    subtitleField: 'status',
    amountField: 'target_amount',
    dateField: 'target_date',
    fields: [
      FieldConfig(
        name: 'name',
        label: 'Goal Name',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Emergency Fund, New Laptop',
      ),
      FieldConfig(
        name: 'target_amount',
        label: 'Target Amount',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'target_date',
        label: 'Target Date',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'status',
        label: 'Status',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('in_progress', 'In Progress'),
          FieldOption('completed', 'Completed'),
          FieldOption('paused', 'Paused'),
        ],
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Contributions',
    endpoint: 'savings-contributions',
    icon: Icons.savings,
    color: Colors.lime,
    titleField: 'contributed_at',
    amountField: 'amount',
    fields: [
      FieldConfig(
        name: 'savings_goal_id',
        label: 'Savings Goal',
        type: FieldType.select,
        required: true,
        optionsEndpoint: 'savings-goals',
        optionsLabelField: 'name',
      ),
      FieldConfig(
        name: 'amount',
        label: 'Amount',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'contributed_at',
        label: 'Date',
        type: FieldType.date,
        required: true,
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Diet',
    endpoint: 'diet-logs',
    icon: Icons.restaurant_outlined,
    color: Colors.orange,
    titleField: 'food_items',
    subtitleField: 'meal_type',
    dateField: 'logged_at',
    fields: [
      FieldConfig(
        name: 'meal_type',
        label: 'Meal',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('breakfast', 'Breakfast'),
          FieldOption('lunch', 'Lunch'),
          FieldOption('dinner', 'Dinner'),
          FieldOption('snack', 'Snack'),
        ],
      ),
      FieldConfig(
        name: 'food_items',
        label: 'Food Items',
        type: FieldType.textarea,
        required: true,
        hint: 'e.g. 2 eggs, toast, orange juice',
      ),
      FieldConfig(name: 'calories', label: 'Calories', type: FieldType.number),
      FieldConfig(
        name: 'logged_at',
        label: 'Date',
        type: FieldType.date,
        required: true,
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Exercise',
    endpoint: 'exercise-logs',
    icon: Icons.directions_run,
    color: Colors.lightGreen,
    titleField: 'activity',
    subtitleField: 'intensity',
    dateField: 'performed_at',
    fields: [
      FieldConfig(
        name: 'activity',
        label: 'Activity',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Running, Weights, Yoga',
      ),
      FieldConfig(
        name: 'duration_minutes',
        label: 'Duration (minutes)',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'intensity',
        label: 'Intensity',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('light', 'Light'),
          FieldOption('moderate', 'Moderate'),
          FieldOption('intense', 'Intense'),
        ],
      ),
      FieldConfig(
        name: 'calories_burned',
        label: 'Calories Burned',
        type: FieldType.number,
      ),
      FieldConfig(
        name: 'performed_at',
        label: 'Date & Time',
        type: FieldType.datetime,
        required: true,
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Sleep',
    endpoint: 'sleep-logs',
    icon: Icons.bedtime_outlined,
    color: Colors.deepPurple,
    titleField: 'sleep_date',
    subtitleField: 'quality',
    fields: [
      FieldConfig(
        name: 'sleep_date',
        label: 'Date',
        type: FieldType.date,
        required: true,
      ),
      FieldConfig(
        name: 'bed_time',
        label: 'Bed Time',
        type: FieldType.text,
        hint: 'e.g. 22:30 (24-hour HH:MM)',
      ),
      FieldConfig(
        name: 'wake_time',
        label: 'Wake Time',
        type: FieldType.text,
        hint: 'e.g. 06:30 (24-hour HH:MM)',
      ),
      FieldConfig(
        name: 'quality',
        label: 'Quality',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('poor', 'Poor'),
          FieldOption('fair', 'Fair'),
          FieldOption('good', 'Good'),
          FieldOption('excellent', 'Excellent'),
        ],
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Health',
    endpoint: 'health-checkups',
    icon: Icons.medical_services_outlined,
    color: Colors.pink,
    titleField: 'checkup_type',
    subtitleField: 'doctor_name',
    dateField: 'checkup_date',
    fields: [
      FieldConfig(
        name: 'checkup_type',
        label: 'Type',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Dental, General, Eye',
      ),
      FieldConfig(
        name: 'checkup_date',
        label: 'Checkup Date & Time',
        type: FieldType.datetime,
        required: true,
      ),
      FieldConfig(
        name: 'doctor_name',
        label: 'Doctor / Clinic',
        type: FieldType.text,
        hint: 'e.g. Dr. Smith, City Dental Clinic',
      ),
      FieldConfig(
        name: 'next_due_date',
        label: 'Next Checkup Due',
        type: FieldType.datetime,
        hint: 'Leave blank if none scheduled yet',
      ),
      FieldConfig(
        name: 'findings',
        label: 'Findings / Notes',
        type: FieldType.textarea,
      ),
    ],
  ),
  const ModuleConfig(
    title: 'Projects',
    endpoint: 'projects',
    icon: Icons.account_tree_outlined,
    color: Colors.blue,
    titleField: 'name',
    subtitleField: 'status',
    dateField: 'deadline',
    fields: [
      FieldConfig(
        name: 'name',
        label: 'Project Name',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Kitchen Renovation',
      ),
      FieldConfig(
        name: 'status',
        label: 'Status',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('planned', 'Planned'),
          FieldOption('in_progress', 'In Progress'),
          FieldOption('on_hold', 'On Hold'),
          FieldOption('completed', 'Completed'),
        ],
      ),
      FieldConfig(
        name: 'start_date',
        label: 'Start Date',
        type: FieldType.date,
      ),
      FieldConfig(name: 'deadline', label: 'Deadline', type: FieldType.date),
      FieldConfig(
        name: 'description',
        label: 'Description',
        type: FieldType.textarea,
      ),
    ],
  ),
  const ModuleConfig(
    title: 'Tasks',
    endpoint: 'project-tasks',
    icon: Icons.checklist_rtl,
    color: Colors.cyan,
    titleField: 'title',
    subtitleField: 'status',
    dateField: 'due_date',
    fields: [
      FieldConfig(
        name: 'project_id',
        label: 'Project',
        type: FieldType.select,
        required: true,
        optionsEndpoint: 'projects',
        optionsLabelField: 'name',
        hint: 'Select one of your projects',
      ),
      FieldConfig(
        name: 'title',
        label: 'Task',
        type: FieldType.text,
        required: true,
        hint: 'e.g. Buy paint',
      ),
      FieldConfig(
        name: 'status',
        label: 'Status',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('todo', 'To Do'),
          FieldOption('in_progress', 'In Progress'),
          FieldOption('done', 'Done'),
        ],
      ),
      FieldConfig(name: 'due_date', label: 'Due Date', type: FieldType.date),
    ],
  ),
  const ModuleConfig(
    title: 'Education',
    endpoint: 'education-plans',
    icon: Icons.school_outlined,
    color: Color(0xFF5B5BD6),
    titleField: 'title',
    subtitleField: 'institution',
    amountField: 'cost',
    dateField: 'target_completion_date',
    fields: [
      FieldConfig(
        name: 'title',
        label: 'Title',
        type: FieldType.text,
        required: true,
        hint: 'e.g. AWS Certification, MBA',
      ),
      FieldConfig(
        name: 'level',
        label: 'Level',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('course', 'Course'),
          FieldOption('certificate', 'Certificate'),
          FieldOption('associate', 'Associate Degree'),
          FieldOption('bachelor', "Bachelor's"),
          FieldOption('master', "Master's"),
          FieldOption('phd', 'PhD'),
          FieldOption('bootcamp', 'Bootcamp'),
          FieldOption('other', 'Other'),
        ],
      ),
      FieldConfig(
        name: 'status',
        label: 'Status',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('planned', 'Planned'),
          FieldOption('in_progress', 'In Progress'),
          FieldOption('completed', 'Completed'),
          FieldOption('on_hold', 'On Hold'),
        ],
      ),
      FieldConfig(
        name: 'institution',
        label: 'Institution',
        type: FieldType.text,
      ),
      FieldConfig(
        name: 'start_date',
        label: 'Start Date',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'target_completion_date',
        label: 'Target Completion',
        type: FieldType.date,
      ),
      FieldConfig(name: 'cost', label: 'Cost', type: FieldType.number),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Network',
    endpoint: 'network-contacts',
    icon: Icons.groups_outlined,
    color: Colors.lightBlue,
    titleField: 'name',
    subtitleField: 'company',
    dateField: 'next_follow_up_date',
    fields: [
      FieldConfig(
        name: 'name',
        label: 'Name',
        type: FieldType.text,
        required: true,
      ),
      FieldConfig(
        name: 'relationship_type',
        label: 'Type',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('mentor', 'Mentor'),
          FieldOption('mentee', 'Mentee'),
          FieldOption('peer', 'Peer'),
          FieldOption('industry_contact', 'Industry Contact'),
          FieldOption('recruiter', 'Recruiter'),
          FieldOption('client', 'Client'),
          FieldOption('other', 'Other'),
        ],
      ),
      FieldConfig(
        name: 'company',
        label: 'Company / Organization',
        type: FieldType.text,
        hint: 'e.g. Acme Corp',
      ),
      FieldConfig(
        name: 'met_through',
        label: 'How You Met',
        type: FieldType.text,
        hint: 'e.g. Conference, LinkedIn',
      ),
      FieldConfig(
        name: 'last_contact_date',
        label: 'Last Contact',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'next_follow_up_date',
        label: 'Next Follow-up',
        type: FieldType.date,
      ),
      FieldConfig(name: 'goal', label: 'Goal', type: FieldType.textarea),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Relationships',
    endpoint: 'relationships',
    icon: Icons.favorite_outline,
    color: Colors.redAccent,
    titleField: 'name',
    subtitleField: 'category',
    dateField: 'next_planned_interaction',
    fields: [
      FieldConfig(
        name: 'name',
        label: 'Name',
        type: FieldType.text,
        required: true,
      ),
      FieldConfig(
        name: 'category',
        label: 'Category',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('family', 'Family'),
          FieldOption('work', 'Work'),
          FieldOption('friend', 'Friend'),
          FieldOption('romantic', 'Romantic'),
          FieldOption('other', 'Other'),
        ],
      ),
      FieldConfig(
        name: 'relation_label',
        label: 'Relation Label',
        type: FieldType.text,
        hint: 'e.g. Sister, Best friend',
      ),
      FieldConfig(
        name: 'priority',
        label: 'Priority',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('high', 'High'),
          FieldOption('medium', 'Medium'),
          FieldOption('low', 'Low'),
        ],
      ),
      FieldConfig(
        name: 'last_meaningful_interaction',
        label: 'Last Meaningful Interaction',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'next_planned_interaction',
        label: 'Next Planned Interaction',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'strengthening_goal',
        label: 'Strengthening Goal',
        type: FieldType.textarea,
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Spiritual Growth',
    endpoint: 'spiritual-practices',
    icon: Icons.self_improvement,
    color: Colors.deepOrange,
    titleField: 'practice_type',
    subtitleField: 'title',
    dateField: 'practiced_at',
    fields: [
      FieldConfig(
        name: 'practice_type',
        label: 'Practice',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('prayer', 'Prayer'),
          FieldOption('meditation', 'Meditation'),
          FieldOption('scripture_reading', 'Scripture Reading'),
          FieldOption('worship', 'Worship'),
          FieldOption('fasting', 'Fasting'),
          FieldOption('service', 'Service / Volunteering'),
          FieldOption('journaling', 'Journaling'),
          FieldOption('other', 'Other'),
        ],
      ),
      FieldConfig(
        name: 'title',
        label: 'Title',
        type: FieldType.text,
        hint: 'e.g. Morning Devotion',
      ),
      FieldConfig(name: 'preacher', label: 'Preacher', type: FieldType.text),
      FieldConfig(
        name: 'theme_topic',
        label: 'Theme / Topic',
        type: FieldType.text,
      ),
      FieldConfig(
        name: 'practiced_at',
        label: 'Date',
        type: FieldType.date,
        required: true,
      ),
      FieldConfig(
        name: 'practice_time',
        label: 'Time (HH:MM)',
        type: FieldType.text,
      ),
      FieldConfig(
        name: 'duration_minutes',
        label: 'Duration (minutes)',
        type: FieldType.number,
      ),
      FieldConfig(
        name: 'scriptures',
        label: 'Bible Readings / Scriptures',
        type: FieldType.textarea,
      ),
      FieldConfig(
        name: 'lessons_learnt',
        label: 'Lessons Learnt',
        type: FieldType.textarea,
      ),
      FieldConfig(
        name: 'next_planned_date',
        label: 'Next Planned',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'reflection',
        label: 'Reflection',
        type: FieldType.textarea,
      ),
    ],
  ),
  const ModuleConfig(
    title: 'Notes',
    endpoint: 'notes',
    icon: Icons.note_alt_outlined,
    color: Colors.amber,
    titleField: 'title',
    subtitleField: 'category',
    fields: [
      FieldConfig(
        name: 'title',
        label: 'Title',
        type: FieldType.text,
        required: true,
      ),
      FieldConfig(name: 'category', label: 'Category', type: FieldType.text),
      FieldConfig(
        name: 'tags',
        label: 'Tags',
        type: FieldType.text,
        hint: 'e.g. work, ideas, personal',
      ),
      FieldConfig(name: 'content', label: 'Note', type: FieldType.textarea),
      FieldConfig(
        name: 'is_pinned',
        label: 'Pinned (1 = yes)',
        type: FieldType.number,
      ),
      FieldConfig(
        name: 'is_favorite',
        label: 'Favourite (1 = yes)',
        type: FieldType.number,
      ),
    ],
  ),
  const ModuleConfig(
    title: 'Goals',
    endpoint: 'personal-goals',
    icon: Icons.track_changes_outlined,
    color: Colors.deepPurple,
    titleField: 'title',
    subtitleField: 'module',
    dateField: 'target_date',
    fields: [
      FieldConfig(
        name: 'module',
        label: 'Life Area',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('finance', 'Finance'),
          FieldOption('savings', 'Savings'),
          FieldOption('education', 'Education'),
          FieldOption('spiritual', 'Spiritual Growth'),
          FieldOption('health', 'Health & Self-care'),
          FieldOption('exercise', 'Exercise & Fitness'),
          FieldOption('diet', 'Diet & Nutrition'),
          FieldOption('productivity', 'Productivity'),
          FieldOption('projects', 'Projects'),
          FieldOption('personal', 'Personal Development'),
        ],
      ),
      FieldConfig(
        name: 'title',
        label: 'Goal',
        type: FieldType.text,
        required: true,
      ),
      FieldConfig(
        name: 'description',
        label: 'Why this matters',
        type: FieldType.textarea,
      ),
      FieldConfig(
        name: 'start_date',
        label: 'Start Date',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'target_date',
        label: 'Target Date',
        type: FieldType.date,
      ),
      FieldConfig(
        name: 'target_value',
        label: 'Target Value (optional)',
        type: FieldType.number,
      ),
      FieldConfig(
        name: 'current_value',
        label: 'Current Value (optional)',
        type: FieldType.number,
      ),
      FieldConfig(
        name: 'progress_percent',
        label: 'Progress %',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'status',
        label: 'Status',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('not_started', 'Not Started'),
          FieldOption('in_progress', 'In Progress'),
          FieldOption('completed', 'Completed'),
          FieldOption('paused', 'Paused'),
        ],
      ),
      FieldConfig(
        name: 'priority',
        label: 'Priority',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('low', 'Low'),
          FieldOption('medium', 'Medium'),
          FieldOption('high', 'High'),
        ],
      ),
      FieldConfig(
        name: 'reminder_at',
        label: 'Reminder',
        type: FieldType.datetime,
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Daily Wellbeing',
    endpoint: 'wellbeing',
    icon: Icons.self_improvement_outlined,
    color: Colors.teal,
    titleField: 'log_date',
    subtitleField: 'mood',
    dateField: 'log_date',
    fields: [
      FieldConfig(
        name: 'log_date',
        label: 'Date',
        type: FieldType.date,
        required: true,
      ),
      FieldConfig(
        name: 'water_ml',
        label: 'Water Drunk (ml)',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'water_target_ml',
        label: 'Daily Water Target (ml)',
        type: FieldType.number,
        required: true,
      ),
      FieldConfig(
        name: 'exercise_minutes',
        label: 'Exercise (minutes)',
        type: FieldType.number,
      ),
      FieldConfig(
        name: 'steps',
        label: 'Steps (optional)',
        type: FieldType.number,
      ),
      FieldConfig(
        name: 'mood',
        label: 'Mood',
        type: FieldType.select,
        options: [
          FieldOption('low', 'Low'),
          FieldOption('okay', 'Okay'),
          FieldOption('good', 'Good'),
          FieldOption('great', 'Great'),
        ],
      ),
      FieldConfig(
        name: 'self_care_done',
        label: 'Self-care completed?',
        type: FieldType.select,
        options: [FieldOption('1', 'Yes'), FieldOption('0', 'No')],
      ),
      FieldConfig(
        name: 'screen_break_done',
        label: 'Took a screen break?',
        type: FieldType.select,
        options: [FieldOption('1', 'Yes'), FieldOption('0', 'No')],
      ),
      FieldConfig(
        name: 'reflection_done',
        label: 'Reflection / prayer / meditation?',
        type: FieldType.select,
        options: [FieldOption('1', 'Yes'), FieldOption('0', 'No')],
      ),
      FieldConfig(
        name: 'self_care_activity',
        label: 'Self-care activity',
        type: FieldType.text,
      ),
      FieldConfig(name: 'notes', label: 'Notes', type: FieldType.textarea),
    ],
  ),
  const ModuleConfig(
    title: 'Feedback',
    endpoint: 'feedback',
    icon: Icons.feedback_outlined,
    color: AppColors.tan,
    titleField: 'subject',
    subtitleField: 'category',
    fields: [
      FieldConfig(
        name: 'category',
        label: 'Category',
        type: FieldType.select,
        required: true,
        options: [
          FieldOption('bug', 'Bug Report'),
          FieldOption('feature_request', 'Feature Request'),
          FieldOption('general', 'General'),
          FieldOption('complaint', 'Complaint'),
          FieldOption('compliment', 'Compliment'),
        ],
      ),
      FieldConfig(
        name: 'subject',
        label: 'Subject',
        type: FieldType.text,
        required: true,
        hint: 'A short summary',
      ),
      FieldConfig(
        name: 'message',
        label: 'Message',
        type: FieldType.textarea,
        required: true,
      ),
      FieldConfig(
        name: 'rating',
        label: 'Rating (1-5, optional)',
        type: FieldType.number,
      ),
    ],
  ),
];

/// Looked up by endpoint (e.g. 'plans', 'diet-logs') rather than indexed
/// by position — DashboardScreen's grouped navigation uses this so
/// reordering the list above can never silently point a nav entry at the
/// wrong module.
ModuleConfig moduleConfigByEndpoint(String endpoint) {
  // Never let navigation crash because one module config was accidentally
  // removed/renamed by a later mobile patch. firstWhere() without orElse
  // throws `Bad state: No element`, which previously took down the whole
  // Home screen while AppDrawer was being built.
  for (final config in moduleConfigs) {
    if (config.endpoint == endpoint) {
      return config;
    }
  }

  // Safe fallback keeps the drawer/search usable. The endpoint is preserved
  // so list requests still target the requested API resource. This fallback
  // is only used when a config entry is genuinely missing.
  final readableTitle = endpoint
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  debugPrint(
    'moduleConfigByEndpoint: no config found for "$endpoint". '
    'Using safe fallback instead of crashing.',
  );

  return ModuleConfig(
    title: readableTitle.isEmpty ? 'Module' : readableTitle,
    endpoint: endpoint,
    icon: Icons.apps_outlined,
    color: AppColors.forest,
    titleField: 'title',
    fields: const [],
  );
}
