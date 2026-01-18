class Student {
  final String? id;
  final String email;
  final String name;
  final String rollNumber;
  final String uid; // Added UID field
  final String dept;
  final String year;

  Student({
    this.id,
    required this.email,
    required this.name,
    required this.rollNumber,
    required this.uid,
    required this.dept,
    required this.year,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String?,
      email: json['email'] as String,
      name: json['name'] as String,
      rollNumber: json['roll_number'] as String,
      uid: json['uid'] as String? ?? '', // Handle potential missing field safely
      dept: json['dept'] as String,
      year: json['year'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'email': email,
      'name': name,
      'roll_number': rollNumber,
      'uid': uid,
      'dept': dept,
      'year': year,
    };
  }
}

