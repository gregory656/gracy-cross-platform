class ConnectionModel {
  const ConnectionModel({
    required this.userId,
    required this.contactId,
    required this.status,
  });

  final String userId;
  final String contactId;
  final String status;

  factory ConnectionModel.fromMap(Map<String, dynamic> map) {
    return ConnectionModel(
      userId: map['user_id'] as String,
      contactId: map['contact_id'] as String,
      status: map['status'] as String,
    );
  }
}
