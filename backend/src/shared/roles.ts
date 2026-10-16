// Mirrors the `role` seed rows in db/seed/00_admin_seed.sql
export const ROLES = ["ADMIN", "FACULTY", "STUDENT", "ACCOUNTANT", "PLACEMENT_OFFICER"] as const;
export type Role = (typeof ROLES)[number];

export interface AuthUser {
  id: number;
  username: string;
  email: string;
  roles: Role[];
}
