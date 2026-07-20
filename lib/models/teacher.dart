/// Reference lists for the Add/Signup Teacher forms — Ghana's basic and
/// secondary education system.

const List<String> subjectOptions = [
  'Mathematics',
  'English Language',
  'Integrated Science',
  'Social Studies',
  'ICT',
  'French',
  'Religious and Moral Education (RME)',
  'Ghanaian Language',
  'Creative Arts',
  'Physical Education',
  'Career Technology',
  'Agricultural Science',
  'Chemistry',
  'Physics',
  'Biology',
  'Economics',
  'Geography',
  'History',
  'Literature in English',
  'Government',
  'Accounting',
  'Business Management',
  'Music',
];

const List<String> classLevelOptions = [
  'Creche / Nursery',
  'Kindergarten (KG)',
  'Primary (Class 1-6)',
  'JHS (JHS 1-3)',
  'SHS (SHS 1-3)',
  'Tertiary / University',
];

const List<String> teacherQualificationOptions = [
  "Teacher's Cert 'A'",
  'Diploma in Basic Education (DBE)',
  'Diploma in Education',
  'Bachelor of Education (B.Ed)',
  "Bachelor's Degree (subject specialist)",
  'Post-Graduate Diploma in Education',
  "Master's Degree",
];

class Teacher {
  final String id;
  final String name;
  final String phoneNumber;
  final String schoolOrInstitution; // current/most recent school, or "Private Tutor"
  final String stationArea;
  final int yearsOfExperience;
  final String qualification; // single value from teacherQualificationOptions
  final List<String> subjectsTaught; // from subjectOptions
  final List<String> classLevelsTaught; // from classLevelOptions
  final bool offersHomeTutoring;
  final bool offersOnlineTutoring;
  final double rating;
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String ghanaCardNumber;
  final String? photoUrl;
  final String? ghanaCardPhotoUrl;

  const Teacher({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.schoolOrInstitution,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.qualification,
    required this.subjectsTaught,
    required this.classLevelsTaught,
    required this.offersHomeTutoring,
    required this.offersOnlineTutoring,
    required this.rating,
    required this.reviewCount,
    required this.isApproved,
    required this.isPending,
    required this.ghanaCardNumber,
    this.photoUrl,
    this.ghanaCardPhotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'schoolOrInstitution': schoolOrInstitution,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'qualification': qualification,
      'subjectsTaught': subjectsTaught,
      'classLevelsTaught': classLevelsTaught,
      'offersHomeTutoring': offersHomeTutoring,
      'offersOnlineTutoring': offersOnlineTutoring,
      'rating': rating,
      'reviewCount': reviewCount,
      'isApproved': isApproved,
      'isPending': isPending,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory Teacher.fromMap(String id, Map<String, dynamic> map) {
    return Teacher(
      id: id,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      schoolOrInstitution: map['schoolOrInstitution'] ?? '',
      stationArea: map['stationArea'] ?? '',
      yearsOfExperience: (map['yearsOfExperience'] ?? 0) as int,
      qualification: map['qualification'] ?? '',
      subjectsTaught: List<String>.from(map['subjectsTaught'] ?? const []),
      classLevelsTaught: List<String>.from(map['classLevelsTaught'] ?? const []),
      offersHomeTutoring: map['offersHomeTutoring'] == true,
      offersOnlineTutoring: map['offersOnlineTutoring'] == true,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: (map['reviewCount'] ?? 0) as int,
      isApproved: map['isApproved'] == true,
      isPending: map['isPending'] == true,
      ghanaCardNumber: map['ghanaCardNumber'] ?? '',
      photoUrl: map['photoUrl'],
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'],
    );
  }
}
