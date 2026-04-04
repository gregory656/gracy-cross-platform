class ContactMapping {
  const ContactMapping({
    required this.ownerId,
    required this.contactPhone,
    required this.contactName,
    required this.isOnGracy,
    this.id,
    this.createdAt,
  });

  final String? id;
  final String ownerId;
  final String contactPhone;
  final String contactName;
  final bool isOnGracy;
  final DateTime? createdAt;

  factory ContactMapping.fromMap(Map<String, dynamic> map) {
    return ContactMapping(
      id: map['id'] as String?,
      ownerId: map['owner_id'] as String,
      contactPhone: map['contact_phone'] as String,
      contactName: map['contact_name'] as String,
      isOnGracy: map['is_on_gracy'] as bool,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'contact_phone': contactPhone,
      'contact_name': contactName,
      'is_on_gracy': isOnGracy,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  ContactMapping copyWith({
    String? id,
    String? ownerId,
    String? contactPhone,
    String? contactName,
    bool? isOnGracy,
    DateTime? createdAt,
  }) {
    return ContactMapping(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      contactPhone: contactPhone ?? this.contactPhone,
      contactName: contactName ?? this.contactName,
      isOnGracy: isOnGracy ?? this.isOnGracy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
