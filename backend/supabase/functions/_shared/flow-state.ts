import { DOMAIN_IDS, type DomainId } from "./types.ts";

export type InterviewStatus =
  | "in_progress"
  | "analyzing"
  | "finalized"
  | "skipped"
  | "private_kept";

export const FINISHED_INTERVIEW_STATUSES = new Set<InterviewStatus>([
  "finalized",
  "skipped",
  "private_kept",
]);

export interface InterviewStatusRow {
  domain: DomainId;
  status: InterviewStatus;
}

export function isFinishedInterviewStatus(
  status: InterviewStatus,
): boolean {
  return FINISHED_INTERVIEW_STATUSES.has(status);
}

export function finishedDomains(
  rows: readonly InterviewStatusRow[],
): Set<DomainId> {
  return new Set(
    rows.filter((row) => isFinishedInterviewStatus(row.status)).map((row) =>
      row.domain
    ),
  );
}

export function missingFinishedDomains(
  rows: readonly InterviewStatusRow[],
): DomainId[] {
  const finished = finishedDomains(rows);
  return DOMAIN_IDS.filter((domain) => !finished.has(domain));
}

export function hasAllFinishedDomains(
  rows: readonly InterviewStatusRow[],
): boolean {
  return missingFinishedDomains(rows).length === 0;
}
