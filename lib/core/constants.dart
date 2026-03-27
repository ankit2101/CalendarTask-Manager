const syncIntervalMinutes = 10;
const calendarWindowHoursBefore = 1;
const calendarWindowHoursAfter = 24;

final leaveAcronyms = RegExp(r'\b(PTO|OOO|DTO|WTO|OOF|LOA)\b', caseSensitive: false);
const leavePhrases = [
  'out of office', 'on leave', 'annual leave', 'sick leave', 'parental leave',
  'maternity leave', 'paternity leave', 'family leave', 'bereavement',
  'vacation', 'holiday', 'time off', 'day off', 'days off',
  'paid leave', 'unpaid leave', 'sabbatical', 'away',
];

bool isLeaveEvent(String title) {
  final lower = title.toLowerCase();
  if (leaveAcronyms.hasMatch(title)) return true;
  return leavePhrases.any((phrase) => lower.contains(phrase));
}
