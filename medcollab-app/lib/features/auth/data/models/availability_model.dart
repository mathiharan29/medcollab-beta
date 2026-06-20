import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';

/// Embedded `User.availability` from the backend.
class AvailabilityModel extends Equatable {
  const AvailabilityModel({
    this.status = AvailabilityStatus.available,
    this.until,
    this.note = '',
    this.updatedAt,
  });

  factory AvailabilityModel.fromJson(Map<String, dynamic> json) {
    return AvailabilityModel(
      status: AvailabilityStatus.fromString(json['status'] as String?),
      until: json['until'] != null
          ? DateTime.tryParse(json['until'].toString())
          : null,
      note: json['note'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  final AvailabilityStatus status;
  final DateTime? until;
  final String note;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'status': status.value,
        if (until != null) 'until': until!.toIso8601String(),
        'note': note,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  AvailabilityModel copyWith({
    AvailabilityStatus? status,
    DateTime? until,
    String? note,
    DateTime? updatedAt,
  }) {
    return AvailabilityModel(
      status: status ?? this.status,
      until: until ?? this.until,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [status, until, note, updatedAt];
}
