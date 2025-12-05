class Patient {
  final String? id;
  final String userId;
  final String name;
  final String? phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;
  final Map<String, dynamic>? additionalInfo;

  Patient({
    this.id,
    required this.userId,
    required this.name,
    this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.additionalInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'additionalInfo': additionalInfo,
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      userId: json['userId'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      gender: json['gender'],
      additionalInfo: json['additionalInfo'],
    );
  }
}

