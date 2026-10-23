/// Development fixtures for UI preview and offline testing.
///
/// CRITICAL ARCHITECTURAL RULE:
/// These fixtures must NEVER be silently seeded into the user's production SQLite database.
/// Production database initialization starts with a clean, unpopulated schema.
class DemoDataFixtures {
  DemoDataFixtures._();

  static const String demoClassId = 'fixture-class-cs2026-a';
  static const String demoOwnerId = 'fixture-owner-cr01';

  static final List<Map<String, dynamic>> previewStudents = [
    {'rollNo': '01', 'name': 'Aarav Sharma', 'isActive': true},
    {'rollNo': '02', 'name': 'Aditi Patel', 'isActive': true},
    {'rollNo': '03', 'name': 'Ananya Verma', 'isActive': true},
    {'rollNo': '04', 'name': 'Devansh Gupta', 'isActive': true},
    {'rollNo': '05', 'name': 'Ishaan Malhotra', 'isActive': false},
    {'rollNo': '06', 'name': 'Kavya Singh', 'isActive': true},
    {'rollNo': '07', 'name': 'Manav Joshi', 'isActive': true},
    {'rollNo': '08', 'name': 'Pooja Iyer', 'isActive': true},
    {'rollNo': '09', 'name': 'Rohan Nair', 'isActive': true},
    {'rollNo': '10', 'name': 'Sanya Kapoor', 'isActive': true},
  ];

  static const List<String> previewSubjects = [
    'Data Structures & Algorithms',
    'Operating Systems',
    'Database Management Systems',
    'Computer Networks',
    'Software Engineering',
  ];
}
