// The standard Altrobyte enrolment form: education, shipping address, interests, duration and a few things the team
// needs before the first call. Name and Google email come from the sign-in; the mobile number is always asked.
//
// Ids are fixed words, not q1/q2, so a response exported today still reads the same after the form is edited.

const enrolmentTemplate = <Map<String, dynamic>>[
  {
    'id': 'qualification', 'section': 'Education', 'label': 'Current / highest qualification', 'type': 'choice', 'required': true,
    'options': ['12th', 'Diploma', 'B.E. / B.Tech', 'B.Sc / BCA', 'M.E. / M.Tech', 'M.Sc / MCA', 'Working professional', 'Other'],
  },
  {'id': 'college', 'section': 'Education', 'label': 'College / university (or company)', 'type': 'text', 'required': true, 'options': []},
  {'id': 'branch', 'section': 'Education', 'label': 'Branch / stream', 'type': 'text', 'required': true, 'options': []},
  {'id': 'year', 'section': 'Education', 'label': 'Year of study / passing year', 'type': 'text', 'required': true, 'options': []},
  {'id': 'address', 'section': 'Address (for shipping your kit)', 'label': 'Full address (house, street, area)', 'type': 'long', 'required': true, 'options': []},
  {'id': 'city', 'section': 'Address (for shipping your kit)', 'label': 'City', 'type': 'text', 'required': true, 'options': []},
  {'id': 'state', 'section': 'Address (for shipping your kit)', 'label': 'State', 'type': 'text', 'required': true, 'options': []},
  {'id': 'pin', 'section': 'Address (for shipping your kit)', 'label': 'PIN code', 'type': 'text', 'required': true, 'options': []},
  {
    'id': 'interest', 'section': 'What you want to learn', 'label': 'I am interested in (pick one or more)', 'type': 'multi', 'required': true,
    'options': ['IoT', 'Embedded Systems', 'Edge AI', 'Circuit Designing'],
  },
  {
    'id': 'duration', 'section': 'What you want to learn', 'label': 'Program duration', 'type': 'choice', 'required': true,
    'options': ['1 month', '2 months', '3 months', '4 months', '6 months'],
  },
  {
    'id': 'level', 'section': 'What you want to learn', 'label': 'Your current level', 'type': 'choice', 'required': true,
    'options': ['Beginner (no experience)', 'I know the basics', 'Intermediate', 'Advanced'],
  },
  {'id': 'laptop', 'section': 'What you want to learn', 'label': 'Do you have a laptop?', 'type': 'choice', 'required': true, 'options': ['Yes', 'No']},
  {
    'id': 'heard', 'section': 'A little more', 'label': 'How did you hear about us?', 'type': 'choice', 'required': false,
    'options': ['Instagram', 'LinkedIn', 'YouTube', 'WhatsApp', 'Friend / college', 'Other'],
  },
  {'id': 'notes', 'section': 'A little more', 'label': 'Anything else you want to tell us?', 'type': 'long', 'required': false, 'options': []},
];
