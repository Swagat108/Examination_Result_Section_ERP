import { app } from "./app.js";
import http from "node:http";

async function runBacklogTests() {
  console.log("=== STARTING BACKLOG EXAM FORM E2E TESTS ===");

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(4998, resolve));
  const baseUrl = "http://localhost:4998/api";

  const post = async (path: string, body: any, token?: string) => {
    const res = await fetch(`${baseUrl}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(body),
    });
    const json = await res.json().catch(() => ({}));
    return { status: res.status, data: json };
  };

  const get = async (path: string, token?: string) => {
    const res = await fetch(`${baseUrl}${path}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    const json = await res.json().catch(() => ({}));
    return { status: res.status, data: json };
  };

  try {
    // 1. Auth logins
    console.log("\n[TEST 1] Login Admin, Faculty, Regular Student, Failed Student");
    const adminLogin = await post("/auth/login", { username: "admin", password: "password123" });
    if (adminLogin.status !== 200) throw new Error("Admin login failed");
    const adminToken = adminLogin.data.token;

    const studentFailedLogin = await post("/auth/login", { username: "student.failed", password: "password123" });
    if (studentFailedLogin.status !== 200) throw new Error("Failed student login failed");
    const failedStudentToken = studentFailedLogin.data.token;
    console.log("✓ Logged in as failed student (studentId: 2024ETC0018)");

    // 2. Backlog stats
    console.log("\n[TEST 2] Backlog stats");
    const statsRes = await get("/exams/backlog/stats", adminToken);
    if (statsRes.status !== 200) throw new Error(`Stats failed: ${JSON.stringify(statsRes.data)}`);
    console.log("✓ Backlog Stats:", statsRes.data);

    // 3. Failed students list
    console.log("\n[TEST 3] Failed students list (Admin)");
    const failedStudentsRes = await get("/exams/backlog/failed-students", adminToken);
    if (failedStudentsRes.status !== 200) throw new Error(`Failed students failed: ${JSON.stringify(failedStudentsRes.data)}`);
    console.log(`✓ Fetched ${failedStudentsRes.data.totalStudents} failed students across campus`);
    const foundSample = failedStudentsRes.data.students.find((s: any) => s.studentId === "2024ETC0018");
    if (!foundSample) throw new Error("Student 2024ETC0018 not found in failed students list");
    console.log(`✓ Verified student 2024ETC0018 has ${foundSample.failedCoursesCount} backlog course(s):`, foundSample.failedCourses.map((c: any) => c.courseCode));

    // 4. Eligible courses for failed student
    console.log("\n[TEST 4] Eligible backlog courses for candidate");
    const eligibleRes = await get("/exams/backlog/eligible-courses/2024ETC0018", failedStudentToken);
    if (eligibleRes.status !== 200) throw new Error(`Eligible courses failed: ${JSON.stringify(eligibleRes.data)}`);
    console.log(`✓ Candidate has ${eligibleRes.data.failedCourses.length} eligible backlog course(s) and ${eligibleRes.data.availableExams.length} target exam(s) available.`);
    const targetExam = eligibleRes.data.availableExams[0];
    const targetOffering = eligibleRes.data.failedCourses[0];

    // 5. Submit Backlog Exam Form
    console.log("\n[TEST 5] Submit Backlog Exam Form");
    const formSubmission = await post(
      "/exams/backlog/forms",
      {
        studentId: "2024ETC0018",
        examId: targetExam.exam_id,
        offeringIds: [targetOffering.offeringId],
        paymentMode: "UPI",
        declarationAccepted: true,
        remarks: "Appearing for Semester IV Analog Communication backlog re-examination.",
      },
      failedStudentToken
    );
    if (formSubmission.status !== 201) throw new Error(`Form submission failed: ${JSON.stringify(formSubmission.data)}`);
    console.log("✓ Form submitted successfully:", {
      formNo: formSubmission.data.form.form_no,
      totalFee: formSubmission.data.form.total_fee,
      paymentStatus: formSubmission.data.form.payment_status,
      status: formSubmission.data.form.status,
    });
    const formId = formSubmission.data.form.form_id;

    // 6. View Single Form details
    console.log("\n[TEST 6] View Single Form details for printing / verification");
    const formDetails = await get(`/exams/backlog/forms/${formId}`, failedStudentToken);
    if (formDetails.status !== 200) throw new Error(`Fetch form details failed: ${JSON.stringify(formDetails.data)}`);
    console.log(`✓ Retrieved form ${formDetails.data.form.form_no} with ${formDetails.data.items.length} subject item(s)`);

    // 7. Admin Review & Approval
    console.log("\n[TEST 7] Admin Review & Approval of Backlog Form");
    const reviewRes = await post(
      `/exams/backlog/forms/${formId}/review`,
      {
        status: "APPROVED",
        paymentStatus: "PAID",
        remarks: "Verified academic eligibility and fee clearance. Approved for hall ticket issue.",
      },
      adminToken
    );
    if (reviewRes.status !== 200) throw new Error(`Form review failed: ${JSON.stringify(reviewRes.data)}`);
    console.log("✓ Form approved by Admin. Response:", reviewRes.data.message);

    // Clean up test form
    console.log("\n[CLEANUP] Cleaning up test backlog form...");
    const delRes = await fetch(`${baseUrl}/exams/backlog/forms/${formId}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const delJson = await delRes.json();
    console.log("✓ Form cleaned up:", delJson.message);

    console.log("\n=== ALL BACKLOG EXAM FORM E2E TESTS PASSED SUCCESSFULLY! ===");
  } finally {
    server.close();
  }
}

runBacklogTests().catch((e) => {
  console.error("Test error:", e);
  process.exit(1);
});
