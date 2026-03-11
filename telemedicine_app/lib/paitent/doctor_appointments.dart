import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'doctor_service.dart';
import 'doctor_model.dart';

class DoctorAppointments extends StatelessWidget {
  const DoctorAppointments({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DoctorService>(
      builder: (context, ds, _) {
        final appts = ds.appointments;
        if (appts.isEmpty) {
          return const Center(child: Text('No appointments'));
        }
        return ListView.separated(
          itemCount: appts.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            final a = appts[i];
            return ListTile(
              title: Text(a.patientName),
              subtitle: Text('${a.startTime}'),
              trailing: _buildActions(context, a.id, a.status),
            );
          },
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, String id, AppointmentStatus status) {
    final ds = context.read<DoctorService>();
    if (status == AppointmentStatus.pending) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(onPressed: () => ds.acceptAppointment(id), child: const Text('Accept')),
        TextButton(onPressed: () => ds.rejectAppointment(id), child: const Text('Reject')),
      ]);
    }
    if (status == AppointmentStatus.confirmed) {
      return ElevatedButton(onPressed: () => ds.startAppointment(id), child: const Text('Start'));
    }
    if (status == AppointmentStatus.started) {
      return ElevatedButton(onPressed: () => ds.completeAppointment(id), child: const Text('Complete'));
    }
    return const SizedBox();
  }
}
