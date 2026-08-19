class ActivityItem {
  const ActivityItem({
    required this.occurredAt,
    required this.title,
    required this.detail,
    required this.success,
  });

  final DateTime occurredAt;
  final String title;
  final String detail;
  final bool success;
}
