export type Tone = "success" | "warn" | "danger" | "neutral";

const STATUS_TONES: Record<string, Tone> = {
  PAID: "success",
  RESULTS_PUBLISHED: "success",
  PLACED: "success",
  PARTIAL: "warn",
  SCHEDULED: "warn",
  PENDING: "warn",
  DUE: "danger",
  OVERDUE: "danger",
  REJECTED: "danger",
};

export const toneForStatus = (status: string): Tone => STATUS_TONES[status] ?? "neutral";

export function Badge({ tone, children }: { tone: Tone; children: React.ReactNode }) {
  return <span className={`badge ${tone}`}>{children}</span>;
}

export function StatusBadge({ status }: { status: string }) {
  return <Badge tone={toneForStatus(status)}>{status.replace(/_/g, " ")}</Badge>;
}
