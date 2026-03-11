// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'TeleMedicina';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidó su contraseña?';

  @override
  String get home => 'Inicio';

  @override
  String get calendar => 'Calendario';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'Perfil';

  @override
  String get quickActions => 'Acciones rápidas';

  @override
  String get videoCall => 'Videollamada';

  @override
  String get bookAppt => 'Reservar cita';

  @override
  String get viewPrescriptions => 'Ver recetas';

  @override
  String get labResults => 'Resultados de laboratorio';

  @override
  String get history => 'Historial';

  @override
  String get medicalRecords => 'Expediente médico';

  @override
  String get upcomingAppointment => 'Próxima cita';

  @override
  String get noUpcomingAppointments => 'Sin citas próximas';

  @override
  String get recentHealthMetrics => 'Métricas de salud recientes';

  @override
  String get findSpecialist => 'Buscar especialista';

  @override
  String get consult => 'Consultar';

  @override
  String get reviews => 'Reseñas';

  @override
  String get writeReview => 'Escribir reseña';

  @override
  String get submitReview => 'Enviar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Reintentar';

  @override
  String get searchMessages => 'Buscar mensajes...';

  @override
  String get noResults => 'Sin resultados';

  @override
  String get consultationNotes => 'Notas de consulta';

  @override
  String get viewNotes => 'Ver notas';

  @override
  String get doctorNotes => 'Notas del doctor';

  @override
  String get prescription => 'Receta';

  @override
  String get status => 'Estado';

  @override
  String get completed => 'Completado';

  @override
  String get scheduled => 'Programado';

  @override
  String get pending => 'Pendiente';

  @override
  String get cancelled => 'Cancelado';

  @override
  String get uploadTestResult => 'Subir resultado de prueba';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días restantes',
      one: '1 día restante',
    );
    return '$_temp0';
  }

  @override
  String foundSpecialists(int count) {
    return 'Se encontraron $count especialistas';
  }

  @override
  String get notAvailable => 'No disponible';

  @override
  String get settings => 'Configuración';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get language => 'Idioma';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get dataExport => 'Exportar mis datos';

  @override
  String get anonymous => 'Anónimo';

  @override
  String get commentOptional => 'Comentario (opcional)';

  @override
  String get submitAnonymously => 'Enviar anónimamente';

  @override
  String get reviewSubmitted => '¡Reseña enviada!';

  @override
  String get noReviewsYet => 'Sin reseñas aún — ¡sé el primero!';
}
