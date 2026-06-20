import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';

/// Single patient entry inside a shift handoff.
class HandoffPatientModel extends Equatable {
  const HandoffPatientModel({
    this.id,
    required this.bedNumber,
    this.ward = '',
    required this.clinicalAlias,
    this.diagnosis = '',
    this.status = PatientStatus.stable,
    this.notes = '',
    this.pendingTasks = const [],
    this.isFlagged = false,
  });

  factory HandoffPatientModel.fromJson(Map<String, dynamic> json) {
    return HandoffPatientModel(
      id: json['_id']?.toString(),
      bedNumber: json['bedNumber'] as String? ?? '',
      ward: json['ward'] as String? ?? '',
      clinicalAlias: json['clinicalAlias'] as String? ?? '',
      diagnosis: json['diagnosis'] as String? ?? '',
      status: PatientStatus.fromString(json['status'] as String?),
      notes: json['notes'] as String? ?? '',
      pendingTasks: json['pendingTasks'] is List
          ? (json['pendingTasks'] as List).map((e) => e.toString()).toList()
          : const [],
      isFlagged: json['isFlagged'] as bool? ?? false,
    );
  }

  final String? id;
  final String bedNumber;
  final String ward;
  final String clinicalAlias;
  final String diagnosis;
  final PatientStatus status;
  final String notes;
  final List<String> pendingTasks;
  final bool isFlagged;

  /// De-identified patient identifier — bed + alias, no PHI.
  String get patientIdentifier {
    final wardPart = ward.isNotEmpty ? '$ward · ' : '';
    return '$wardPart Bed $bedNumber — $clinicalAlias';
  }

  Map<String, dynamic> toJson() => {
        if (id != null) '_id': id,
        'bedNumber': bedNumber,
        if (ward.isNotEmpty) 'ward': ward,
        'clinicalAlias': clinicalAlias,
        if (diagnosis.isNotEmpty) 'diagnosis': diagnosis,
        'status': status.value,
        if (notes.isNotEmpty) 'notes': notes,
        'pendingTasks': pendingTasks,
        'isFlagged': isFlagged,
      };

  HandoffPatientModel copyWith({
    String? id,
    String? bedNumber,
    String? ward,
    String? clinicalAlias,
    String? diagnosis,
    PatientStatus? status,
    String? notes,
    List<String>? pendingTasks,
    bool? isFlagged,
  }) {
    return HandoffPatientModel(
      id: id ?? this.id,
      bedNumber: bedNumber ?? this.bedNumber,
      ward: ward ?? this.ward,
      clinicalAlias: clinicalAlias ?? this.clinicalAlias,
      diagnosis: diagnosis ?? this.diagnosis,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      pendingTasks: pendingTasks ?? this.pendingTasks,
      isFlagged: isFlagged ?? this.isFlagged,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bedNumber,
        ward,
        clinicalAlias,
        diagnosis,
        status,
        notes,
        pendingTasks,
        isFlagged,
      ];
}
