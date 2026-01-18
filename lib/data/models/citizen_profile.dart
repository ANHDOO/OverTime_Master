class CitizenProfile {
  final int? id;
  final String label;
  final String? taxId;
  final String? licensePlate;
  final String? cccdId;
  final String? bhxhId;
  final bool isDefault;

  CitizenProfile({
    this.id,
    required this.label,
    this.taxId,
    this.licensePlate,
    this.cccdId,
    this.bhxhId,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'label': label,
      'tax_id': taxId,
      'license_plate': licensePlate,
      'cccd_id': cccdId,
      'bhxh_id': bhxhId,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory CitizenProfile.fromMap(Map<String, dynamic> map) {
    return CitizenProfile(
      id: map['id'],
      label: map['label'],
      taxId: map['tax_id'],
      licensePlate: map['license_plate'],
      cccdId: map['cccd_id'],
      bhxhId: map['bhxh_id'],
      isDefault: map['is_default'] == 1,
    );
  }

  CitizenProfile copyWith({
    int? id,
    String? label,
    String? taxId,
    String? licensePlate,
    String? cccdId,
    String? bhxhId,
    bool? isDefault,
  }) {
    return CitizenProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      taxId: taxId ?? this.taxId,
      licensePlate: licensePlate ?? this.licensePlate,
      cccdId: cccdId ?? this.cccdId,
      bhxhId: bhxhId ?? this.bhxhId,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
