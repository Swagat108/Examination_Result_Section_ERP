import type { Role } from "./auth/types";

// Single registry for sidebar + routes. To add a screen: add an entry here, a page under
// src/pages/<module>/, and register it in the PAGES map in App.tsx.
export interface ModuleDef {
  key: string;
  label: string;
  group: string;
  path: string;
  roles: readonly Role[];
}

const ALL: readonly Role[] = ["ADMIN", "FACULTY", "STUDENT", "ACCOUNTANT", "PLACEMENT_OFFICER"];

export const MODULES: ModuleDef[] = [
  { key: "admin", label: "Communication & Admin", group: "G1", path: "/admin", roles: ALL },
  { key: "exams", label: "Examinations", group: "G2", path: "/exams", roles: ["ADMIN", "FACULTY", "STUDENT"] },
  { key: "academics", label: "Academics", group: "G3", path: "/academics", roles: ["ADMIN", "FACULTY", "STUDENT"] },
  { key: "attendance", label: "Attendance", group: "G4", path: "/attendance", roles: ["ADMIN", "FACULTY", "STUDENT"] },
  { key: "finance", label: "Fees & Finance", group: "G5", path: "/finance", roles: ["ADMIN", "ACCOUNTANT", "STUDENT"] },
  { key: "students", label: "Students", group: "G6", path: "/students", roles: ["ADMIN", "FACULTY"] },
  { key: "placement", label: "Placement", group: "G7", path: "/placement", roles: ["ADMIN", "PLACEMENT_OFFICER", "STUDENT"] },
];
