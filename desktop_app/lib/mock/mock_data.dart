class MockData {
  static const loginResponse = {
    'token': 'mock_token_123',
    'institute_id': 1,
    'name': 'Demo Coaching Centre',
  };

  static const dashboard = {
    'total_students': 156,
    'active_batches': 4,
    'fee_due_count': 23,
    'tests_today': 3,
    'recent_activity': [
      {
        'type': 'enrollment',
        'student_name': 'Rahul Kumar',
        'detail': 'New enrollment',
        'ts': '2026-05-27T10:30:00'
      },
      {
        'type': 'test',
        'student_name': 'Priya Sharma',
        'detail': 'SSC GD Mock Test',
        'ts': '2026-05-27T09:15:00'
      },
    ],
  };

  static const students = [
    {
      'id': 1,
      'institute_id': 1,
      'name': 'Rahul Kumar',
      'phone': '9876543210',
      'email': 'rahul@example.com',
      'batch_id': 1,
      'batch_name': 'SSC Batch A',
      'parent_phone': '9876543211',
      'fee_status': 'paid',
      'enrolled_at': '2026-01-15T00:00:00'
    },
    {
      'id': 2,
      'institute_id': 1,
      'name': 'Priya Sharma',
      'phone': '9876543212',
      'email': 'priya@example.com',
      'batch_id': 2,
      'batch_name': 'Railway Batch B',
      'parent_phone': '9876543213',
      'fee_status': 'pending',
      'enrolled_at': '2026-02-10T00:00:00'
    },
    {
      'id': 3,
      'institute_id': 1,
      'name': 'Amit Singh',
      'phone': '9876543214',
      'email': 'amit@example.com',
      'batch_id': 1,
      'batch_name': 'SSC Batch A',
      'parent_phone': '9876543215',
      'fee_status': 'pending',
      'enrolled_at': '2026-03-05T00:00:00'
    },
  ];

  static const batches = [
    {
      'id': 1,
      'institute_id': 1,
      'name': 'SSC Batch A',
      'subject': 'SSC GD',
      'schedule': 'Mon-Fri 8AM-10AM',
      'teacher_name': 'Suresh Sir',
      'is_active': true,
      'student_count': 45
    },
    {
      'id': 2,
      'institute_id': 1,
      'name': 'Railway Batch B',
      'subject': 'Railway NTPC',
      'schedule': 'Mon-Sat 11AM-1PM',
      'teacher_name': 'Meena Ma\'am',
      'is_active': true,
      'student_count': 38
    },
    {
      'id': 3,
      'institute_id': 1,
      'name': 'Army Batch C',
      'subject': 'Agniveer',
      'schedule': 'Tue-Thu 5PM-7PM',
      'teacher_name': 'Arjun Sir',
      'is_active': true,
      'student_count': 52
    },
  ];

  static const sampleQuestions = [
    {
      'question': 'What is 15% of 200?',
      'options': {'A': '25', 'B': '30', 'C': '35', 'D': '40'},
      'correct': 'B',
      'explanation': '15% of 200 = (15/100) × 200 = 30',
      'difficulty': 'Easy',
      'topic': 'Percentage'
    },
    {
      'question': 'Who was the first Prime Minister of India?',
      'options': {
        'A': 'Sardar Patel',
        'B': 'Dr. Rajendra Prasad',
        'C': 'Jawaharlal Nehru',
        'D': 'Lal Bahadur Shastri'
      },
      'correct': 'C',
      'explanation': 'Jawaharlal Nehru was the first Prime Minister of India (1947–1964).',
      'difficulty': 'Easy',
      'topic': 'Indian History'
    },
  ];
}
