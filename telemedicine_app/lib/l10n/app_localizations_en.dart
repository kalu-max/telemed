// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TeleMedicine';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get home => 'Home';

  @override
  String get calendar => 'Calendar';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'Profile';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get videoCall => 'Video Call';

  @override
  String get bookAppt => 'Book Appointment';

  @override
  String get viewPrescriptions => 'View Prescriptions';

  @override
  String get labResults => 'Lab Results';

  @override
  String get history => 'History';

  @override
  String get medicalRecords => 'Medical Records';

  @override
  String get upcomingAppointment => 'Upcoming Appointment';

  @override
  String get noUpcomingAppointments => 'No upcoming appointments';

  @override
  String get recentHealthMetrics => 'Recent Health Metrics';

  @override
  String get findSpecialist => 'Find a Specialist';

  @override
  String get consult => 'Consult';

  @override
  String get reviews => 'Reviews';

  @override
  String get writeReview => 'Write Review';

  @override
  String get submitReview => 'Submit';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get searchMessages => 'Search messages...';

  @override
  String get noResults => 'No results found';

  @override
  String get consultationNotes => 'Consultation Notes';

  @override
  String get viewNotes => 'View Notes';

  @override
  String get doctorNotes => 'Doctor Notes';

  @override
  String get prescription => 'Prescription';

  @override
  String get status => 'Status';

  @override
  String get completed => 'Completed';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get pending => 'Pending';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get uploadTestResult => 'Upload Test Result';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String foundSpecialists(int count) {
    return 'Found $count specialists';
  }

  @override
  String get notAvailable => 'Not available';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get dataExport => 'Export My Data';

  @override
  String get anonymous => 'Anonymous';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get submitAnonymously => 'Submit anonymously';

  @override
  String get reviewSubmitted => 'Review submitted!';

  @override
  String get noReviewsYet => 'No reviews yet — be the first!';
}
