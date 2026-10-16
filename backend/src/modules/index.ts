import { Router } from "express";
import { academicsRouter } from "./academics/routes.js";
import { adminRouter } from "./admin/routes.js";
import { attendanceRouter } from "./attendance/routes.js";
import { authRouter } from "./auth.routes.js";
import { examsRouter } from "./exams/routes.js";
import { financeRouter } from "./finance/routes.js";
import { placementRouter } from "./placement/routes.js";
import { studentsRouter } from "./students/routes.js";

export const apiRouter = Router();

// One line per module. Each group owns its own folder under src/modules/<name>/.
apiRouter.use("/auth", authRouter);
apiRouter.use("/admin", adminRouter);
apiRouter.use("/academics", academicsRouter);
apiRouter.use("/students", studentsRouter);
apiRouter.use("/attendance", attendanceRouter);
apiRouter.use("/finance", financeRouter);
apiRouter.use("/exams", examsRouter);
apiRouter.use("/placement", placementRouter);
