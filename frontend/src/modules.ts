import type { Role } from "./auth/types";

// Single registry for sidebar, dashboard and routes. To add a screen: add an entry here, a page under
// src/pages/<module>/, and register it in the PAGES map in App.tsx.
export interface ModuleDef {
  key: string;
  label: string;
  group: string;
  path: string;
  blurb: string;
  roles: readonly Role[];
}

const ALL: readonly Role[] = ["ADMIN", "FACULTY", "STUDENT", "ACCOUNTANT", "PLACEMENT_OFFICER"];

export const MODULES: ModuleDef[] = [
  { key: "admin", label: "Communication & Admin", group: "G1", path: "/admin", blurb: "Notices, grievances and campus-wide announcements.", roles: ALL },
  { key: "exams", label: "Examinations", group: "G2", path: "/exams", blurb: "Exam schedules, hall tickets, marks and results.", roles: ["ADMIN", "FACULTY", "STUDENT"] },
  { key: "academics", label: "Academics", group: "G3", path: "/academics", blurb: "Courses, faculty allocation and the weekly timetable.", roles: ["ADMIN", "FACULTY", "STUDENT"] },
  { key: "attendance", label: "Attendance", group: "G4", path: "/attendance", blurb: "Class attendance, defaulters and faculty leave.", roles: ["ADMIN", "FACULTY", "STUDENT"] },
  { key: "finance", label: "Fees & Finance", group: "G5", path: "/finance", blurb: "Invoices, payments, receipts and payroll.", roles: ["ADMIN", "ACCOUNTANT", "STUDENT"] },
  { key: "students", label: "Students", group: "G6", path: "/students", blurb: "Admissions, enrollment and hostel allocation.", roles: ["ADMIN", "FACULTY"] },
  { key: "placement", label: "Placement", group: "G7", path: "/placement", blurb: "Company drives, applications and offers.", roles: ["ADMIN", "PLACEMENT_OFFICER", "STUDENT"] },
];
