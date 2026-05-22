package com.surensureshkumar.movemark.data.export

import com.surensureshkumar.movemark.data.remote.ExportJobStatus
import com.surensureshkumar.movemark.data.remote.ExportListItem
import java.util.UUID

enum class ExportVerificationStatus {
    Queued,
    Processing,
    /** Completed in API but file path not set yet — still building. */
    Verifying,
    Ready,
    ServerFailed,
    MissingPath,
    ;

    val displayLabel: String
        get() = when (this) {
            Queued -> "Queued"
            Processing -> "Still processing"
            Verifying -> "Checking file"
            Ready -> "Ready to share"
            ServerFailed -> "Export failed"
            MissingPath -> "Missing file path"
        }
}

data class ExportRow(
    val id: UUID,
    val type: String,
    val status: ExportJobStatus,
    val verification: ExportVerificationStatus,
    val requestedAt: String?,
    val filePath: String?,
)

fun ExportListItem.toExportRow(): ExportRow {
    val verification = when (status) {
        ExportJobStatus.Queued -> ExportVerificationStatus.Queued
        ExportJobStatus.Processing -> ExportVerificationStatus.Processing
        ExportJobStatus.Failed -> ExportVerificationStatus.ServerFailed
        ExportJobStatus.Completed -> {
            val path = filePath?.trim().orEmpty()
            if (path.isEmpty()) ExportVerificationStatus.Verifying
            else ExportVerificationStatus.Ready
        }
    }
    return ExportRow(
        id = UUID.fromString(id),
        type = type,
        status = status,
        verification = verification,
        requestedAt = requestedAt ?: createdAt,
        filePath = filePath,
    )
}

enum class ReportReadiness {
    NoVault,
    NotReady,
    ReadyToMake,
    ReadyToShare,
    Processing,
    Failed,
}

object ReportReadinessMapper {
    fun resolve(
        hasVault: Boolean,
        documentedRooms: Int,
        exports: List<ExportRow>,
    ): ReportReadiness {
        if (!hasVault) return ReportReadiness.NoVault
        val moveIn = exports.filter { it.type == MOVE_IN_REPORT_TYPE }
        if (moveIn.any { it.verification == ExportVerificationStatus.ServerFailed }) {
            return ReportReadiness.Failed
        }
        if (moveIn.any { it.verification.isActiveJob }) {
            return ReportReadiness.Processing
        }
        if (moveIn.any { it.verification == ExportVerificationStatus.Ready }) {
            return ReportReadiness.ReadyToShare
        }
        if (documentedRooms > 0) return ReportReadiness.ReadyToMake
        return ReportReadiness.NotReady
    }

    fun hasActiveMoveInJob(exports: List<ExportRow>): Boolean =
        exports.any {
            it.type == MOVE_IN_REPORT_TYPE && it.verification.isActiveJob
        }

    fun firstReadyExport(exports: List<ExportRow>): ExportRow? =
        exports.firstOrNull {
            it.type == MOVE_IN_REPORT_TYPE && it.verification == ExportVerificationStatus.Ready
        }

    const val MOVE_IN_REPORT_TYPE = "move_in_report"
    const val MOVE_OUT_REPORT_TYPE = "move_out_report"
}

enum class MoveOutReportReadiness {
    NoProof,
    ReadyToMake,
    Processing,
    ReadyToShare,
    Failed,
}

object MoveOutReportReadinessMapper {
    fun resolve(moveOutPhotos: Int, exports: List<ExportRow>): MoveOutReportReadiness {
        if (moveOutPhotos <= 0) return MoveOutReportReadiness.NoProof
        val moveOut = exports.filter { it.type == ReportReadinessMapper.MOVE_OUT_REPORT_TYPE }
        if (moveOut.any { it.verification == ExportVerificationStatus.ServerFailed }) {
            return MoveOutReportReadiness.Failed
        }
        if (moveOut.any { it.verification.isActiveJob }) {
            return MoveOutReportReadiness.Processing
        }
        if (moveOut.any { it.verification == ExportVerificationStatus.Ready }) {
            return MoveOutReportReadiness.ReadyToShare
        }
        return MoveOutReportReadiness.ReadyToMake
    }

    fun hasActiveMoveOutJob(exports: List<ExportRow>): Boolean =
        exports.any {
            it.type == ReportReadinessMapper.MOVE_OUT_REPORT_TYPE && it.verification.isActiveJob
        }

    fun firstReadyMoveOutExport(exports: List<ExportRow>): ExportRow? =
        exports.firstOrNull {
            it.type == ReportReadinessMapper.MOVE_OUT_REPORT_TYPE &&
                it.verification == ExportVerificationStatus.Ready
        }
}

val ExportVerificationStatus.isActiveJob: Boolean
    get() = when (this) {
        ExportVerificationStatus.Queued,
        ExportVerificationStatus.Processing,
        ExportVerificationStatus.Verifying,
        -> true
        else -> false
    }
