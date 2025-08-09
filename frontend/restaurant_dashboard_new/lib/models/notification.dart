class Notification {
  final int id;
  final String title;
  final String message;
  final String timestamp;
  final bool isRead;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      timestamp: json['timestamp'],
      isRead: json['is_read'],
    );
  }
}
