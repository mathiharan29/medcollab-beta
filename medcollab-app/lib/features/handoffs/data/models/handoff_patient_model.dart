import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';

/// A file attached to a handoff patient (lab report, ECG, X-ray photo...).
/// Mirrors `patientSchema.attachments` on the backend.
class HandoffAttachment extends Equatable {
  const HandoffAttachment({
    required this.url,
    this.thumbnailUrl,
    this.fileName = '',
    this.mimeType = '',
  });

  factory HandoffAttachment.fromJson(Map<String, dynamic> json) {
    return HandoffAttachment(
      url: json['url']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      fileName: json['fileName']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
    );
  }

  final String url;
  final String? thumbnailUrl;
  final String fileName;
  final String mimeType;

  bool get isImage => mimeType.startsWith('image/');

  /// Name to show; falls back to the last URL segment.
  String get displayName {
    if (fileName.trim().isNotEmpty) return fileName.trim();
    final segments = Uri.tryParse(url)?.pathSegments ?? const [];
    return segments.isNotEmpty ? segments.last : 'Attachment';
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (fileName.isNotEmpty) 'fileName': fileName,
        if (mimeType.isNotEmpty) 'mimeType': mimeType,
      };

  @override
  List<Object?> get props => [url, thumbnailUrl, fileName, mimeType];
}

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
    this.attachments = const [],
  });

  factory HandoffPatientModel.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
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
      attachments: rawAttachments is List
          ? rawAttachments
              .whereType<Map>()
              .map((m) => HandoffAttachment.fromJson(
                    Map<String, dynamic>.from(m),
                  ))
              .where((a) => a.url.isNotEmpty)
              .toList()
          : const [],
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
  final List<HandoffAttachment> attachments;

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
        'attachments': attachments.map((a) => a.toJson()).toList(),
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
    List<HandoffAttachment>? attachments,
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
      attachments: attachments ?? this.attachments,
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
        attachments,
      ];
}
