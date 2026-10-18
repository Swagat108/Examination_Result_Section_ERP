export const ROLES = ["ADMIN", "FACULTY", "STUDENT", "ACCOUNTANT", "PLACEMENT_OFFICER"] as const;
export type Role = (typeof ROLES)[number];

export interface AuthUser {
  id: number;
  username: string;
  email: string;
  roles: Role[];
  studentId?: string | null;
  employeeId?: string | null;
}

