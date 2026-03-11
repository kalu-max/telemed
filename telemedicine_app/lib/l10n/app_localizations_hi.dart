// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'टेलीमेडिसिन';

  @override
  String get login => 'लॉगिन';

  @override
  String get register => 'रजिस्टर';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get home => 'होम';

  @override
  String get calendar => 'कैलेंडर';

  @override
  String get chat => 'चैट';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get quickActions => 'त्वरित कार्य';

  @override
  String get videoCall => 'वीडियो कॉल';

  @override
  String get bookAppt => 'अपॉइंटमेंट बुक करें';

  @override
  String get viewPrescriptions => 'नुस्खे देखें';

  @override
  String get labResults => 'लैब रिपोर्ट';

  @override
  String get history => 'इतिहास';

  @override
  String get medicalRecords => 'चिकित्सा रिकॉर्ड';

  @override
  String get upcomingAppointment => 'आगामी अपॉइंटमेंट';

  @override
  String get noUpcomingAppointments => 'कोई आगामी अपॉइंटमेंट नहीं';

  @override
  String get recentHealthMetrics => 'हाल की स्वास्थ्य मेट्रिक्स';

  @override
  String get findSpecialist => 'विशेषज्ञ खोजें';

  @override
  String get consult => 'परामर्श';

  @override
  String get reviews => 'समीक्षाएं';

  @override
  String get writeReview => 'समीक्षा लिखें';

  @override
  String get submitReview => 'जमा करें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get retry => 'पुनः प्रयास';

  @override
  String get searchMessages => 'संदेश खोजें...';

  @override
  String get noResults => 'कोई परिणाम नहीं';

  @override
  String get consultationNotes => 'परामर्श नोट्स';

  @override
  String get viewNotes => 'नोट्स देखें';

  @override
  String get doctorNotes => 'डॉक्टर के नोट्स';

  @override
  String get prescription => 'नुस्खा';

  @override
  String get status => 'स्थिति';

  @override
  String get completed => 'पूर्ण';

  @override
  String get scheduled => 'निर्धारित';

  @override
  String get pending => 'लंबित';

  @override
  String get cancelled => 'रद्द';

  @override
  String get uploadTestResult => 'रिपोर्ट अपलोड करें';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन शेष',
      one: '1 दिन शेष',
    );
    return '$_temp0';
  }

  @override
  String foundSpecialists(int count) {
    return '$count विशेषज्ञ मिले';
  }

  @override
  String get notAvailable => 'उपलब्ध नहीं';

  @override
  String get settings => 'सेटिंग';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get language => 'भाषा';

  @override
  String get notifications => 'सूचनाएं';

  @override
  String get dataExport => 'मेरा डेटा निर्यात करें';

  @override
  String get anonymous => 'गुमनाम';

  @override
  String get commentOptional => 'टिप्पणी (वैकल्पिक)';

  @override
  String get submitAnonymously => 'गुमनाम रूप से जमा करें';

  @override
  String get reviewSubmitted => 'समीक्षा जमा!';

  @override
  String get noReviewsYet => 'अभी तक कोई समीक्षा नहीं — पहले बनें!';
}
