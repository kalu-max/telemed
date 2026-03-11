import 'package:flutter/material.dart';
import '../models/presence_model.dart';

/// Doctor card showing availability status with quick action buttons
class DoctorAvailabilityCard extends StatelessWidget {
  final DoctorPresence doctor;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onVideoCall;

  const DoctorAvailabilityCard({
    super.key,
    required this.doctor,
    required this.onCall,
    required this.onChat,
    required this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Avatar with Status Indicator
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      doctor.profileImageUrl ?? 'https://i.pravatar.cc/150?u=${doctor.doctorId}',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            doctor.doctorName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Status Indicator
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getStatusColor(doctor.status),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Doctor Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Verified Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doctor.doctorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (doctor.isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Specialty
                    Text(
                      doctor.specialty,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status & Rating
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusBackgroundColor(doctor.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            doctor.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(doctor.status),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (doctor.ratingScore != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                doctor.ratingScore!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 12),
          // Action Buttons
          Row(
            children: [
              if (doctor.consultationType == ConsultationType.videoCall ||
                  doctor.consultationType == ConsultationType.all)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.videocam,
                    label: 'Video',
                    onPressed: doctor.isAvailable ? onVideoCall : null,
                  ),
                ),
              if ((doctor.consultationType == ConsultationType.audioCall ||
                      doctor.consultationType == ConsultationType.all) &&
                  doctor.consultationType != ConsultationType.videoCall)
                const SizedBox(width: 8),
              if (doctor.consultationType == ConsultationType.audioCall ||
                  doctor.consultationType == ConsultationType.all)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.call,
                    label: 'Call',
                    onPressed: doctor.isAvailable ? onCall : null,
                  ),
                ),
              if ((doctor.consultationType == ConsultationType.chat ||
                      doctor.consultationType == ConsultationType.all) &&
                  (doctor.consultationType == ConsultationType.videoCall ||
                      doctor.consultationType == ConsultationType.audioCall))
                const SizedBox(width: 8),
              if (doctor.consultationType == ConsultationType.chat ||
                  doctor.consultationType == ConsultationType.all)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_bubble,
                    label: 'Chat',
                    onPressed: doctor.isAvailable ? onChat : null,
                  ),
                ),
            ],
          ),
          // Fee and Response Time
          if (doctor.consultationFee != null || doctor.responseTimeSeconds != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (doctor.consultationFee != null)
                    Text(
                      '₹${doctor.consultationFee}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                  if (doctor.responseTimeSeconds != null)
                    Text(
                      'Avg. response: ${_formatResponseTime(doctor.responseTimeSeconds!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.busy:
        return Colors.orange;
      case PresenceStatus.away:
        return Colors.amber;
      case PresenceStatus.doNotDisturb:
        return Colors.red;
      case PresenceStatus.offline:
        return Colors.grey;
    }
  }

  Color _getStatusBackgroundColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green.withAlpha(26);
      case PresenceStatus.busy:
        return Colors.orange.withAlpha(26);
      case PresenceStatus.away:
        return Colors.amber.withAlpha(26);
      case PresenceStatus.doNotDisturb:
        return Colors.red.withAlpha(26);
      case PresenceStatus.offline:
        return Colors.grey.withAlpha(26);
    }
  }

  String _formatResponseTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).ceil()}m';
    return '${(seconds / 3600).ceil()}h';
  }
}

/// Action button for doctor card
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? Colors.teal[600] : Colors.grey[300],
        foregroundColor: isEnabled ? Colors.white : Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// List of available doctors with sorting and filtering
class AvailableDoctorsList extends StatefulWidget {
  final List<DoctorPresence> doctors;
  final String? selectedSpecialty;
  final Function(DoctorPresence) onDoctorSelected;
  final Function(String consultationType)? onConsultationTypeChange;

  const AvailableDoctorsList({
    super.key,
    required this.doctors,
    this.selectedSpecialty,
    required this.onDoctorSelected,
    this.onConsultationTypeChange,
  });

  @override
  State<AvailableDoctorsList> createState() => _AvailableDoctorsListState();
}

class _AvailableDoctorsListState extends State<AvailableDoctorsList> {
  late List<DoctorPresence> _filteredDoctors;
  String _sortBy = 'availability'; // 'availability', 'rating', 'fee', 'response_time'

  @override
  void initState() {
    super.initState();
    _filteredDoctors = widget.doctors;
    _applySort();
  }

  @override
  void didUpdateWidget(AvailableDoctorsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctors != widget.doctors) {
      _filteredDoctors = widget.doctors;
      _applySort();
    }
  }

  void _applySort() {
    switch (_sortBy) {
      case 'rating':
        _filteredDoctors.sort((a, b) =>
            (b.ratingScore ?? 0).compareTo(a.ratingScore ?? 0));
        break;
      case 'fee':
        _filteredDoctors.sort((a, b) =>
            (a.consultationFee ?? 9999).compareTo(b.consultationFee ?? 9999));
        break;
      case 'response_time':
        _filteredDoctors.sort((a, b) =>
            (a.responseTimeSeconds ?? 9999)
                .compareTo(b.responseTimeSeconds ?? 9999));
        break;
      default: // 'availability'
        _filteredDoctors.sort((a, b) =>
            b.availabilityScore.compareTo(a.availabilityScore));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sort Options
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _SortChip(
                label: 'Availability',
                isSelected: _sortBy == 'availability',
                onSelected: () {
                  setState(() => _sortBy = 'availability');
                  _applySort();
                },
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Rating',
                isSelected: _sortBy == 'rating',
                onSelected: () {
                  setState(() => _sortBy = 'rating');
                  _applySort();
                },
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Fee',
                isSelected: _sortBy == 'fee',
                onSelected: () {
                  setState(() => _sortBy = 'fee');
                  _applySort();
                },
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Response Time',
                isSelected: _sortBy == 'response_time',
                onSelected: () {
                  setState(() => _sortBy = 'response_time');
                  _applySort();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Doctor List
        if (_filteredDoctors.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No doctors available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDoctors.length,
            itemBuilder: (context, index) {
              final doctor = _filteredDoctors[index];
              return DoctorAvailabilityCard(
                doctor: doctor,
                onVideoCall: () => widget.onDoctorSelected(doctor),
                onCall: () => widget.onDoctorSelected(doctor),
                onChat: () => widget.onDoctorSelected(doctor),
              );
            },
          ),
      ],
    );
  }
}

/// Chip widget for sorting options
class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: isSelected ? Colors.teal : Colors.grey[300]!,
      ),
      selectedColor: Colors.teal[50],
      labelStyle: TextStyle(
        color: isSelected ? Colors.teal[700] : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

/// Header widget showing selected doctor info and consultation type selection
class DoctorSelectionHeader extends StatelessWidget {
  final DoctorPresence doctor;
  final ConsultationType selectedType;
  final Function(ConsultationType) onTypeChanged;

  const DoctorSelectionHeader({
    super.key,
    required this.doctor,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(
                  doctor.profileImageUrl ?? 'https://i.pravatar.cc/150?u=${doctor.doctorId}',
                ),
                onBackgroundImageError: (exception, stackTrace) {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.doctorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      doctor.specialty,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Consultation Type Selector
          Row(
            children: [
              if (doctor.consultationType == ConsultationType.videoCall ||
                  doctor.consultationType == ConsultationType.all)
                Expanded(
                  child: _ConsultationTypeButton(
                    icon: Icons.videocam,
                    label: 'Video',
                    isSelected: selectedType == ConsultationType.videoCall,
                    onPressed: () => onTypeChanged(ConsultationType.videoCall),
                  ),
                ),
              const SizedBox(width: 8),
              if (doctor.consultationType == ConsultationType.audioCall ||
                  doctor.consultationType == ConsultationType.all)
                Expanded(
                  child: _ConsultationTypeButton(
                    icon: Icons.call,
                    label: 'Audio',
                    isSelected: selectedType == ConsultationType.audioCall,
                    onPressed: () => onTypeChanged(ConsultationType.audioCall),
                  ),
                ),
              const SizedBox(width: 8),
              if (doctor.consultationType == ConsultationType.chat ||
                  doctor.consultationType == ConsultationType.all)
                Expanded(
                  child: _ConsultationTypeButton(
                    icon: Icons.chat,
                    label: 'Chat',
                    isSelected: selectedType == ConsultationType.chat,
                    onPressed: () => onTypeChanged(ConsultationType.chat),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Button for selecting consultation type
class _ConsultationTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ConsultationTypeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.teal[600] : Colors.grey[100],
        foregroundColor: isSelected ? Colors.white : Colors.grey[700],
        elevation: isSelected ? 4 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
