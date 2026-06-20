import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';

/// Priority accent colours for handoff list and patient cards.
abstract final class HandoffPriorityColors {
  static Color forPatient(HandoffPatientModel patient) {
    if (patient.isFlagged || patient.status == PatientStatus.critical) {
      return AppColors.emergency;
    }
    return forStatus(patient.status);
  }

  static Color forStatus(PatientStatus status) {
    return switch (status) {
      PatientStatus.critical => AppColors.emergency,
      PatientStatus.deteriorating => AppColors.urgent,
      PatientStatus.monitoring => AppColors.warning,
      PatientStatus.improving => AppColors.primary,
      PatientStatus.stable => AppColors.success,
    };
  }

  static Color forHandoff(HandoffModel handoff) {
    if (handoff.hasFlaggedPatient) return AppColors.emergency;
    final critical = handoff.patients
        .where((p) => p.status == PatientStatus.critical)
        .isNotEmpty;
    if (critical) return AppColors.emergency;
    final deteriorating = handoff.patients
        .where((p) => p.status == PatientStatus.deteriorating)
        .isNotEmpty;
    if (deteriorating) return AppColors.urgent;
    final monitoring = handoff.patients
        .where((p) => p.status == PatientStatus.monitoring)
        .isNotEmpty;
    if (monitoring) return AppColors.warning;
    return AppColors.secondaryMuted;
  }

  static String statusLabel(PatientStatus status) => switch (status) {
        PatientStatus.stable => 'Stable',
        PatientStatus.monitoring => 'Monitoring',
        PatientStatus.critical => 'Critical',
        PatientStatus.improving => 'Improving',
        PatientStatus.deteriorating => 'Deteriorating',
      };

  static String handoffStatusLabel(HandoffStatus status) => switch (status) {
        HandoffStatus.draft => 'Draft',
        HandoffStatus.submitted => 'Pending',
        HandoffStatus.acknowledged => 'Archived',
      };

  static Color handoffStatusColor(HandoffStatus status) => switch (status) {
        HandoffStatus.draft => AppColors.textTertiary,
        HandoffStatus.submitted => AppColors.accent,
        HandoffStatus.acknowledged => AppColors.success,
      };
}
